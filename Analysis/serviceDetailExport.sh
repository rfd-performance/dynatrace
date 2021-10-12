#!/bin/bash
#
# Description: This script can be used to export the services from a Dynatrace environment.
# The export is a tab separated file that can be opened in applications like Excel.  The columns
# exported include:
#		- Display Name
#		- Detected Name
#		- Service Type
#		- Software Technoglies
#		- Service Technologies
#		- Host Count
#		- Host Names
#
# Requires: Bash, curl, jq, and mktemp
# Tested on Amazon Linux 2 only but should work on Red Hat variants
#
# You will need to set values for the following two variables
#
#		entities_feed_url
#		api_token
#
# Example Execution:
#
#			./serviceDetailExport.sh
#
#
###
# Start Function Area

cleanupFiles() {
	find /tmp -name "service_details_*" -delete > /dev/null 2>&1
}

retrieveEntity() {
	# Call Dynatrace to fetch data
	hostName=''
	service_entity_json=$(mktemp /tmp/service_details_entity_fetch_XXXXXXXX.json)

	response_code=$(curl -k -s -w "%{http_code}" -X GET "${entities_feed_url}/${1}?from=now-7d&to=now" \
		-H "accept: application/json; charset=utf-8" \
		-H "Authorization: Api-Token $api_token" \
		-o ${service_entity_json})
	echo -e "\nEntity Retrieved below"
	cat ${service_entity_json} | jq '.'

	if [[ $response_code -eq 200 ]]; then
		i=0
		hostCnt=0
		getServiceType
		detectedName=$(cat ${service_entity_json} | jq ".properties .detectedName" | tr -d '"')
		echo -e "entityId: $entityId\nDisplay Name: $displayName\nDetected Name: ${detectedName}\nService Type: ${serviceType}"
		while true
		do

			getRunsOnType $i

			if [[ "$serviceType" = "DATABASE_SERVICE" ]]; then
				getDBIPList
				break
			elif [[ "$runsOnType" = "HOST" ]]; then
				host_entity_json=$(mktemp /tmp/service_details_host_fetch_XXXXXXXX.json)
				response_code=$(curl -k -s -w "%{http_code}" -X GET "${entities_feed_url}/${hostId}?from=now-7d&to=now" \
					-H "accept: application/json; charset=utf-8" \
					-H "Authorization: Api-Token ${api_token}" \
					-o ${host_entity_json})

				if [[ $response_code -eq 200 ]]; then
					tempName=$(cat ${host_entity_json} | jq ".displayName" | tr -d '"')
					if [[ -z $hostName ]]; then
						hostName=$tempName
					else
						hostName="${hostName}, $tempName"
					fi
				fi
				((hostCnt++))
			elif [[ "$runsOnType" = "null" ]]; then
				break
			else
				echo -e "ServiceType: $serviceType\nSomething other than host type: $runsOnType"
			fi
			((i++))
		done
		# if [[ $hostCnt -eq 1 ]]; then
		# getServiceType

		getSoftwareTechnologies
		getServiceTechnologyTypes
		serviceUrl="${tenant_base_url}/#newservices/serviceOverview;id=${1};gtf=-2h"

		echo -e "=HYPERLINK(\"${serviceUrl}\", \"${displayName}\")\t${detectedName}\t${serviceType}\t${software}\t${serviceTechnology}\t${hostCnt}\t${hostName}" >> $output_tsv
		# fi
	fi
}

getRunsOnType () {
	runsOnType=$(cat ${service_entity_json} | jq ".fromRelationships .runsOnHost [$1] .type" | tr -d '"')
	hostId=$(cat ${service_entity_json} | jq ".fromRelationships .runsOnHost [$1] .id" | tr -d '"')
	echo -e "runsOnType: $runsOnType\nhostId: $hostId"
}

getDBIPList () {
	ip_idx=0
	while true
	do
		tempName=$(cat ${service_entity_json} | jq ".properties .ipAddress[$ip_idx]" | tr -d '"')
		echo -e "tempName: $tempName\nip_idx: $ip_idx"
		if [[ -z $hostName ]]; then
			hostName=$tempName
		else
			if [[ "${tempName}" = "null" ]]; then
				echo -e "break from getDBIPList loop"
				break
			else
				hostName="${hostName}, $tempName"
			fi
		fi
		echo -e "looping in getDBIPLIst\nhostName: $hostName"
		((ip_idx++))
	done
	hostCnt=$ip_idx
}

getServiceType () {
	serviceType=$(cat ${service_entity_json} | jq ".properties .serviceType" | tr -d '"')
}

getServiceTechnologyTypes () {

	# Check that there is software to process
	serviceTechnology=$(cat ${service_entity_json} | jq ".properties .serviceTechnologyTypes[]")
	if [[ "${serviceTechnology}" = "null" ]] || [[ "${serviceTechnology}" = "" ]]; then
		serviceTechnology=''
		return
	fi

	s_idx=0
	serviceTechnology=

	while true
	do
		technology_type=$(cat ${service_entity_json} | jq ".properties .serviceTechnologyTypes[${s_idx}]" | tr -d '"')
		echo -e "service technology type[${s_idx}]: ${technology_type}"
		# set -x
		if [[ ${technology_type} = 'null' ]]; then
			break
		elif [[ -z ${serviceTechnology} ]]; then
			serviceTechnology="${technology_type}"
		else
			serviceTechnology="${serviceTechnology}, ${technology_type}"
		fi
		# set +x
		((s_idx++))
	done
	serviceTechnology=$(echo $serviceTechnology | tr -d '\r' | tr -d '\n' | tr -d '"')
	echo -e "Service Technology Types: ${serviceTechnology}"

}

getSoftwareTechnologies () {

	# Check that there is software to process
	softwareList=$(cat ${service_entity_json} | jq ".properties .softwareTechnologies[]")
	if [[ "${softwareList}" = "null" ]] || [[ "${softwareList}" = "" ]]; then
		software=''
		return
	fi

	s_idx=0
	software=
	while true
	do
		software_type=$(cat ${service_entity_json} | jq ".properties .softwareTechnologies[${s_idx}] .type" | tr -d '"')
		software_version=$(cat ${service_entity_json} | jq ".properties .softwareTechnologies[${s_idx}] .version" | tr -d '"')
		software_edition=$(cat ${service_entity_json} | jq ".properties .softwareTechnologies[${s_idx}] .edition" | tr -d '"')
		if [[ "$software_type" = "null" ]] && [[ "$software_version" = "null" ]] && [[ "$software_edition" = "null" ]]; then
			break
		elif [[ -z $software ]]; then
			if [[ "$software_version" = "null" ]]; then
				software_version='n/a'
			fi
			if [[ ! "${software_type}" = "null" ]]; then
				software="${software_type}($software_version)"
			fi
		else
			if [[ "$software_version" = "null" ]]; then
				software_version='n/a'
			fi
			if [[ ! "${software_type}" = "null" ]]; then
				software="${software}, ${software_type}($software_version)"
			fi
		fi
		((s_idx++))
	done
	echo -e "Software Technology Types: ${software}"
}
# End function area

# Start Main Logic area
echo -e "\nService export process started...  $(date)\n"

entities_feed_url=https://<your_tenant>.dynatrace-managed.com/e/<your_id>/api/v2/entities
api_token=<your_token>
output_tsv=./service_details.tsv

service_entities_json=$(mktemp /tmp/service_details_service_entites_XXXXXXXX.json)

# Call Dynatrace to fetch up to 500 entities of type "SERVICE"
response_code=$(curl -k -s -w "%{http_code}" -X GET "$entities_feed_url?pageSize=5000&entitySelector=type%28%22SERVICE%22%29&from=now-7d&to=now" \
	-H "accept: application/json; charset=utf-8" \
	-H "Authorization: Api-Token $api_token" \
	-o ${service_entities_json})

rtn_code=$?

echo -e "\nService Entities "
cat ${service_entities_json} | jq '.'

totalCount=$(cat ${service_entities_json} | jq ".totalCount")

if [[ $totalCount -gt 0 ]]; then

	rm ${ext_root}/output/${tenant}_service_details.tsv > /dev/null 2>&1
	echo -e 'Display_Name\tDetected_Name\tService_Type\tSoftware_Technologies\tService_Technologies\tHost_Cnt\tHost_Names' > $output_tsv

	line=0
	while [ $line -lt $totalCount ]
	do
		entityId=$(cat ${service_entities_json} | jq ".entities[$line] .entityId" | tr -d '"')
		if [[ "${entityId}" = "null" ]]; then
			break
		fi
		displayName=$(cat ${service_entities_json} | jq ".entities[$line] .displayName" | tr -d '"')
		echo -e "\nentityId: ${entityId}\ndisplayName: ${displayName}\n"
		retrieveEntity $entityId
		((line++))
	done
fi

cleanupFiles # remove any temporary files

echo -e "\nProcess complete.  $(date)\nEntities Processed: $line\nOutput file located here: $output_tsv"
