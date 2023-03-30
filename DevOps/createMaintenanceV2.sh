#!/bin/bash
#
# Description: Use this to set a downtime in Dynatrace for a certain number of minutes
# Company: RFD & Associates, Inc.
# Date: 03/30/2023
# Author: T. Noonan & W. Myers (RFD)
# Tested on Amazon Linux 2 but should be compatible with Red Hat Variants
#
# Usage: ./createMaintenanceV2.sh 'subject/name' 'description' duration_integer
#
#       To setup a 30 minute downtime for release xyz do something like this.
#
#       ./createMaintenanceV2.sh 'Release xyz' 'This is the code release for xyz' 30
#
# Requires the following:
#
#   - bash
#   - curl
#   - sed
# . - timedatectl
#   - Dynatrace API Token with Write privileges to the Configuration API v1 endpoint
#   - Set the tenant and token value below (tenant & api_token)
#
# Tested on Amazon Linux 2 instance
#
if [ $# -lt 3 ]; then
        echo ""
        echo "You must provide a maintenance subject/name, description, and length of time in minutes"
        echo "  for example: ./createDowntime.sh 'Release xyz' 'This is my release description....' 10"
        echo ""
        exit 1
fi

##### SET THESE VALUES FOR YOUR ENVIRONMENT.  Feel free to externalize how you see fit.
tenant="YOUR_TENANT_URL"
# Be sure that your tenant API token has the settings.write scope
api_token="YOUR_TENANT_API_TOKEN"

if [[ -z "$tenant" ]]; then
        echo "Dynatrace tenant is empty...exiting"
        exit 1
fi

if [[ -z "$api_token" ]]; then
        echo "Dynatrace token is empty...exiting"
        exit 1
fi

if [[ "$(uname)" = "Linux" ]]; then
  timezone=$(timedatectl status | grep "zone" | sed -e 's/^[ ]*Time zone: \(.*\) (.*)$/\1/g')
else
  timezone="America/Chicago"
fi

# Check input parameters provided.  There should be a minimum of three.
maintenance_subject=$1
if [[ -z "$maintenance_subject" ]]; then
  echo "No value supplied for maintenance subject, setting to default"
  maintenance_subject="DEFAULT MAINTENANCE WINDOW NAME"
fi

maintenance_description=$2
if [[ -z "$maintenance_description" ]]; then
  echo "No value supplied for maintenance description, setting to default"
  maintenance_description="DEFAULT MAINTENANCE WINDOW DESCRIPTION"
fi

maintenance_window=$3
if [[ "$maintenance_window" -gt 0 ]]; then
  echo "Maintenance Window Minutes supplied: " $maintenance_window
else
  echo "Maintenance Window Minutes NOT supplied...using default value of 30 minutes "
  maintenance_window=30
fi

maint_body=/tmp/maint-request-body-${RANDOM}.json
start_date=$(date +"%Y-%m-%dT%H:%M:%S")
end_date="$(date -d +"${maintenance_window} minutes" +"%Y-%m-%dT%H:%M:%S")"
(
cat <<ADDTEXT
[
    {
        "schemaId": "builtin:alerting.maintenance-window",
        "scope": "environment",
        "value": {
            "enabled": true,
            "generalProperties": {
                "name": "$maintenance_subject",
                "description": "$maintenance_description",
                "maintenanceType": "PLANNED",
                "suppression": "DETECT_PROBLEMS_DONT_ALERT",
                "disableSyntheticMonitorExecution": true
            },
            "schedule": {
                "scheduleType": "ONCE",
                "onceRecurrence": {
                    "startTime": "${start_date}",
                    "endTime": "${end_date}",
                    "timeZone": "${timezone}"
                }
            },
            "filters": []
        }
    }
]
ADDTEXT
) > $maint_body

echo -e "Body of Maintenance Request\n"
cat $maint_body
echo -e "\n End Body of Maintenance Request"
response_body=/tmp/maint_response_body_${RANDOM}.json
echo -e "*************\nCalling Dynatrace\n"

response_code=$(curl -k -s -w "%{http_code}" \
        "https://${tenant}/api/v2/settings/objects?validateOnly=false" \
        -H "accept: application/json; charset=utf-8" \
        -H "Content-Type: application/json; charset=utf-8" \
        -H "Authorization: Api-Token ${api_token}" \
        -d "$(cat ${maint_body})" \
        -o ${response_body} \
        -k)
rtn_code=$?

if [[ "$rtn_code" -ne 0 || "$response_code" -ne 201 ]]; then
  echo -e "Error returned from call to Dynatrace"
  echo -e "Response Code: $response_code"
  echo -e "Return Code: $rtn_code"
fi
echo -e "Response Output\n"
cat $response_body
rm -rf $maint_body $response_body > /dev/null 2>&1
