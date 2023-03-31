#!/bin/bash -ex

# This script demonstrates how to search for pending maintenance actions not
# currently available to AWS EventBridge. This script checks the following in
# the us-east-2 region:
# - AWS RDS Instance Pending Maintenance
# - AWS DMS Replication Instance Pending Maintenance
#
# This script checks all instances for pending maintenance actions and then
# creates Dynatrace Events, to ensure that SRE and Operations teams are
# aware of the upcoming changes and can review patch notes if available.  
#
# This script should NOT be used as is, but is an example of how Dynatrace
# custom events can be generated from pending maintenance activities of AWS
# managed services, and more generically from events identified via CLI and
# parsed with jq.
#
# A secrets manager should be used to capture each of the variables in <> below.
# DO NOT store variables in plain text!
# 
# Company:  RFD & Associates, Inc.
# Date:     03/30/2023
# Author:   W. Myers (RFD)

# Check that jq is installed, otherwise exit
if ! jq --version; then
    echo 'jq is not installed!'
    exit 1
elif ! aws --version; then
    echo 'AWS CLI is not installed!'
    exit 2
fi

echo "$(date) - $0 Started"
DT_EVENT_TIMEOUT="$((60 * 35))" # Set to 35 minutes in the future, measured in seconds. This script runs every 30 minutes.

assume_role_arn='<ARN OF ROLE ASSUMED BY DYNATRACE TO ACCESS AWS>'
assume_role_session_name='<ASSUME ROLE SESSION NAME>'


# If using Dynatrace SaaS
dt_domain="https://${DT_TENANT_ID}.live.dynatrace.com"
# If using Dynatrace FedRAMP
# dt_domain="https://${DT_TENANT_ID}.dynatrace-fedramp.com"
# If using Dynatrace Managed
# dt_domain="https://<YOUR DYNATRACE MANAGED ENVIRONMENT URL>"
external_id='<EXTERNAL ID PROVIDED BY DYNATRACE WHEN INTEGRATING WITH AWS>'
dt_token='<DYNATRACE API TOKEN WITH Ingest Events SCOPE>'
dt_event_type='CUSTOM_ALERT'

function post_dt_custom_alert(){
    echo -e "\t\tSending Dynatrace Custom Event."
    resource_id="${1}"
    pending_maint_actions="$(jq -R -s '.' <<<"${2}")"
    resource_name="${3}"
    # Setting default value for msg_subj if $4 is blank
    msg_subj="${4}"
    [ -z "${4}" ] && msg_subj='Maintenance Pending'
    curl -s -X POST "${dt_domain}/api/v2/events/ingest" \
            -H "accept: application/json; charset=utf-8" \
            -H "Authorization: Api-Token ${dt_token}" \
            -H "Content-Type: application/json; charset=utf-8" \
            -d "{\"eventType\":\"${dt_event_type}\",\"title\":\"${msg_subj} - ${resource_name}\",\"timeout\":${DT_EVENT_TIMEOUT},\"properties\":{\"message\":${pending_maint_actions}, \"resource_id\":\"${resource_id}\"}}"
    echo ''
}

# This function tries to send unexpected errors as Dynatrace Problems.  However,
# you should always check your logs for unexpected outputs.
function error_trap(){
    current_command="${BASH_COMMAND}" rtn_code="${?}" line_num="$LINENO"
    echo "current_command: $current_command"
    echo "rtn_code: $rtn_code"
    echo "line_num: $line_num"
    if [[ "$(caller)" =~ error_trap ]]; then
        exit 0
    fi
    resource_id="PID: $$"
    pending_maint_actions="$(caller | sed 's/\ /:/'):${line_num} - [ERROR ${rtn_code}] - ${current_command}"
    resource_name="$0"
    msg_subj="Error - $current_command - PID: $$"
    post_dt_custom_alert "$resource_id" "$pending_maint_actions" "$resource_name" "$msg_subj"
}
# Create trap for when errors are encountered
trap error_trap ERR

# Assumes that a Dynatrace monitoring and Dynatrace ActiveGate role-based access have been created per Dynatrace documentation:
# https://www.dynatrace.com/support/help/setup-and-configuration/setup-on-cloud-platforms/amazon-web-services/amazon-web-services-integrations/cloudwatch-metrics#aws-policy-and-authentication

# Otherwise, can skip this step.
AWS_STS_RESP="$(aws sts assume-role \
        --role-arn "${assume_role_arn}" \
        --role-session-name "${assume_role_session_name}" \
        --external-id "${external_id}")"

 AWS_ACCESS_KEY_ID="$(jq -r '.Credentials.AccessKeyId' <<<"${AWS_STS_RESP}")"
 export AWS_ACCESS_KEY_ID
 AWS_SECRET_ACCESS_KEY="$(jq -r '.Credentials.SecretAccessKey' <<<"${AWS_STS_RESP}")"
 export AWS_SECRET_ACCESS_KEY
 AWS_SESSION_TOKEN="$(jq -r '.Credentials.SessionToken' <<<"${AWS_STS_RESP}")"
 export AWS_SESSION_TOKEN

echo -e "\nChecking RDS instances for pending maintenance:"
for rds_arn in $(aws rds describe-db-instances --region us-east-2 --output json | jq -r '.DBInstances[] | .DBInstanceArn'); do
    rds_pending_maintenance_actions_resp="$(aws rds describe-pending-maintenance-actions --resource-identifier "${rds_arn}" --region us-east-2 --output json)"
    rds_pending_maintenance_actions="$(jq -c '.PendingMaintenanceActions[]' <<<"$rds_pending_maintenance_actions_resp")"
    echo -e "\t${rds_arn} - ${rds_pending_maintenance_actions}"
    if [ -n "${rds_pending_maintenance_actions}" ]; then
        rds_name="$(aws rds describe-db-instances --region us-east-2 --output json \
                | jq -r --arg rds_arn "${rds_arn}" \
                '.DBInstances[] | select(.DBInstanceArn == $rds_arn).DBInstanceIdentifier')"
        post_dt_custom_alert "${rds_arn}" "${rds_pending_maintenance_actions}" "${rds_name}"
    fi
done

echo -e "\nChecking DMS instances for pending maintenance:"
for dms_rep_arn in $(aws dms describe-replication-instances --region us-east-2 | jq -r '.ReplicationInstances[] | .ReplicationInstanceArn'); do
    dms_pending_maintenance_actions_resp="$(aws dms describe-pending-maintenance-actions --replication-instance-arn "${dms_rep_arn}" --region us-east-2)"
    dms_pending_maintenance_actions="$(jq -c '.PendingMaintenanceActions[]' <<<"$dms_pending_maintenance_actions_resp")"
    echo -e "\t${dms_rep_arn} - ${dms_pending_maintenance_actions}"
    if [ -n "${dms_pending_maintenance_actions}" ]; then
        dms_rep_name="$(aws dms describe-replication-instances --region us-east-2 | jq -r --arg dms_rep_arn "${dms_rep_arn}" '.ReplicationInstances[] | select(.ReplicationInstanceArn == $dms_rep_arn).ReplicationInstanceIdentifier')"
        post_dt_custom_alert "${dms_rep_arn}" "${dms_pending_maintenance_actions}" "${dms_rep_name}"
    fi
done

 export AWS_ACCESS_KEY_ID=
 export AWS_SECRET_ACCESS_KEY=
 export AWS_SESSION_TOKEN=
