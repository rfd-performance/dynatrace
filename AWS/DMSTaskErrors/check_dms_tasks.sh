#!/bin/bash -ex

# This script demonstrates how to search all AWS DMS Tasks within the us-east-2
# region for specific kinds of errors and then push these DMS errors to Dynatrace.
#
# This script should NOT be used as is, but is an example of how Dynatrace
# custom events can be generated from AWS DMS errors, and more generically
# from events produced via AWS CLI and parsed with jq.
#
# A secrets manager should be used to capture each of the variables in <> below.
# DO NOT store variables in plain text!
# 
# Company:  RFD & Associates, Inc.
# Date:     03/30/2023
# Author:   W. Myers (RFD)

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
}

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


echo -e "\nChecking DMS tasks for errors:"
# Loops through all DMS Tasks for the us-east-2 region, by replication task ARN
for dms_task_arn in $(aws dms describe-replication-tasks --region us-east-2 | jq -r '.ReplicationTasks[] | .ReplicationTaskArn'); do
    # Queries for Tables Stats and looks for the following types of errors:
    # - Mismatched records
    # - Suspended records
    # - Table error
    # - Error
    replication_error_resp="$(aws dms describe-table-statistics --replication-task-arn "${dms_task_arn}")"
    replication_error_tables="$(jq -r '[.TableStatistics[] | select(.ValidationState | test("(Mismatched records|Suspended records|Table error|Error)")).TableName] | @csv' <<<"${replication_error_resp}" \
                | tr -d '"' \
                | sed 's/,/, /g')"
    # Dedups errors and makes them more readable
    replication_errors="$(jq -r '[.TableStatistics[] | select(.ValidationState | test("(Mismatched records|Table error|Error)")).ValidationState] | unique | @csv' <<<"${replication_error_resp}" \
            | tr -d '"' \
            | sed 's/,/, /g')"
    echo -e "\t${dms_task_arn} - ${replication_error_tables} - ${replication_errors}"
    # If errors are found, then determine the DMS Task Name and post an event to Dynatrace.
    if [ -n "${replication_errors}" ]; then
        echo -e "\t\tFound replication error."
        # Captures the DMS Task Name to simplify Event Reporting to Dynatrace
        dms_task_name="$(aws dms describe-replication-tasks --region us-east-2 \
                | jq -r --arg dms_task_arn "${dms_task_arn}" \
                '.ReplicationTasks[] | select(.ReplicationTaskArn == $dms_task_arn).ReplicationTaskIdentifier')"
        post_dt_custom_alert "${dms_task_arn}" "${replication_error_tables}" "${dms_task_name}" "${replication_errors}"
    fi
done

# Clears out AWS CLI ENV VARs used by STS above.
 export AWS_ACCESS_KEY_ID=
 export AWS_SECRET_ACCESS_KEY=
 export AWS_SESSION_TOKEN=
