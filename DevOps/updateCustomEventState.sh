#!/bin/bash
#
# Description: Script is intended to update whether a custom metric alert is enabled
# Author: Tommy Noonan
# RFD & Associates, Inc.
# Date: 11/19/2021
#
# Start Function Area
cleanupFiles() {
	find /tmp -name "custom_event_state*.json" -delete > /dev/null 2>&1
}

retrieveCustomEvents() {
	retrieve_event_list_output_json=$(mktemp /tmp/custom_event_state_current_list_XXXXXXXX.json)

	response_code=$(curl -k -s -w "%{http_code}\n" \
		-H "accept: application/json; charset=utf-8" \
		-H "Authorization: Api-Token ${api_token}" \
		"${metric_anomaly_url}" \
		-o ${retrieve_event_list_output_json})

	if [[ $response_code -eq 200 ]]; then
		echo -e "Successful Custom Event Retrieval"
		echo -e "\nResponse Code: ${response_code}\n"
		cat ${retrieve_event_list_output_json} | jq '.'
	else
		echo -e "Unsuccessful Custom Event Retrieval"
		echo -e "\nResponse Code: ${response_code}\n"
		cat ${retrieve_event_list_output_json} | jq '.'
		exit 1
	fi

}

retrieveCustomEventState() {
	retrieve_output_json=$(mktemp /tmp/custom_event_state_current_XXXXXXXX.json)

	response_code=$(curl -k -s -w "%{http_code}\n" \
		-H "accept: application/json; charset=utf-8" \
		-H "Authorization: Api-Token ${api_token}" \
		"${metric_anomaly_url}/${id}" \
		-o ${retrieve_output_json})

	if [[ $response_code -eq 200 ]]; then
		echo -e "Successful Custom Event State Retrieval"
		echo -e "\nResponse Code: ${response_code}\n"
		cat ${retrieve_output_json} | jq '.'
	else
		echo -e "Unsuccessful Custom Event State Retrieval"
		echo -e "\nResponse Code: ${response_code}\n"
		cat ${retrieve_output_json} | jq '.'
		exit 1
	fi

}

updateCustomEventState() {
	update_output_json=$(mktemp /tmp/custom_event_state_update_XXXXXXXX.json)
	response_code=$(curl -X PUT -k -s -w "%{http_code}\n" \
		-H "accept: */*" \
		-H "Authorization: Api-Token ${api_token}" \
		-H "Content-Type: application/json; charset=utf-8" \
		"${metric_anomaly_url}/${id}" \
		-o ${update_output_json} \
		-d @${retrieve_output_json})
	
	if [[ $response_code -eq 204 ]]; then
		echo -e "Successful Custom Event Update"
		echo -e "\nResponse Code: ${response_code}\n"
	else
		echo -e "Update not successful, Response code: ${response_code}"
		echo -e "\nResponse Code: ${response_code}\n"
		cat ${update_output_json} | jq '.'
		exit 1
	fi
}

# End function area
################################

################################
# Main Logic area
################################
eventName=$(echo $1 | awk '{print toupper($0)}') # Substring of Custom Event in Dynatrace
action=$(echo $2 | awk '{print toupper($0)}') # ENABLE | DISABLE

# Set script variables - YOU WILL SET THESE FOR YOUR ENVIRONMENT
ext_root=~/dynatrace # this is the root of where this script is running in your environment
metric_anomaly_url=https://hpy136.dynatrace-managed.com/e/b1bde7d9-488d-4b97-tfb4-b6a9007c508d/api/config/v1/anomalyDetection/metricEvents
api_token=dt0c01.PU6VP4A6XGCKQOYNHOF3Y7I4.G2IW7this_is_fake_9999BWU2RERJKRZQYRR5DYNF5YB7QOFXWTSCFL

# Retrieve list of custom events
retrieveCustomEvents

# Iterate through custom events returned and match for value provided as input
i=0
while : true
do
	#
	id=$(cat ${retrieve_event_list_output_json} | jq ".values[${i}] .id" | tr -d '"')
	echo -e "id: ${id}"
	if [[ "${id}" = "null" ]]; then
		break
	fi
	name=$(cat ${retrieve_event_list_output_json} | jq ".values[${i}] .name" | tr -d '"' | awk '{print toupper($0)}')
	echo -e "name: ${name}"
	if [[ "$name" == *"$eventName"* ]]; then
		echo -e "Found our metric: $name"
		break
	fi
	echo -e "index val: ${i}"
	((i++))
done

# Retrieve current Metric Anomaly settings for matched metric
retrieveCustomEventState

# Cleanup the output payload from above to make suitable for update
python3 ${ext_root}/lib/CleanCustomEventStatePayload.py \
		--action ${action} \
		--json ${retrieve_output_json}

if [[ $? -ne 0 ]]; then
	echo -e "Error trying to cleanup json file"
	cat ${retrieve_output_json} | jq '.'
	exit 1
else
	echo -e "After payload cleanup \n"
	cat ${retrieve_output_json} | jq '.'
fi

# Now update the current state of the custom alert
updateCustomEventState

# Remove any temporary files that this process created
cleanupFiles 
