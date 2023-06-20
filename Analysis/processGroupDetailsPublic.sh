#!/bin/bash
# Description: Script used to export process group information that can be used
# for a number of different use cases.
#
# Author: Tommy Noonan
# Date: 06/20/2023
#
##
#### Requirements
#
# OS/Software 
# - RedHat/Fedora variant OS (tested with Amazon Linux 2)
# - curl (tested with 7.88.1)
# - mktemp (tested with version 8.22)
# - jq (test with version 1.5)
#
# An API token with the "entities.read" & "settings.read" permissions
#
# The output file is in tab-separated format (.tsv).  Open with something like Excel. The following
# columns are present and in order below.
# - Process Group Display Name - name as you will see in the Dynatrace Screen and it is also a hyperlinked cell that will take you directly to the process group to make any needed changes.
# - Monitoring State - Is the process group currently configured for deep monitoring (transaction level monitoring)
# - Process Availability - Is process group availability monitoring ON or OFF. If it's off then you will never see an alert if the identified process crashes for any reason.
# - Process group instances count - Each process group can have one or more instances, typically running on different hosts.
# - Technologies used by the process group
# - Host count - The number of hosts that this process group is seen running on
# - Host Names - The host names where the process group is running as well as the mode of the agent (FULL or INFRA).
# - Service count - The number of identified services discovered automatically
# - Service Names - The list of service names discovered automatically
# - Log files monitored - A list of log files that are configured to be monitored
#
#	Set the variables in the main function area for your environment
#
#		dynatrace_tenant_url="https://guu84124.apps.dynatrace.com"
#		ext_root="$HOME/dynatrace"
#		api_token="dt0c01.FDF6UM......."

###
# Start Function Area

cleanupFiles() {
	find /tmp -name "pg_*" -delete > /dev/null 2>&1
}

retrieveEntity() {
	pg_entity_json=$(mktemp "/tmp/pg_details_entity_fetch_XXXXXXXX")
	logFiles=""

	# Call Dynatrace to fetch data
	response_code=$(curl --connect-timeout 10 -k -s -w "%{http_code}" -X GET "${entities_feed_url}/${1}?from=now-30d&to=now" \
		-H "accept: application/json; charset=utf-8" \
		-H "Authorization: Api-Token $api_token" \
		-o "${pg_entity_json}")

	#echo -e "Response Code from entity retrieval: $response_code\n"
	jq "." -r "${pg_entity_json}" >> "${pg_entity_detail_debug}"

	if [[ $response_code -eq 200 ]]; then
		getSoftwareTechnologies
		if [[ $? -ne 0 ]]; then
			return
		fi

		# Retrieve Hosts that the process group is running
		i=0
		hostCnt=0
		hostName=''

		while true
		do
			type=$(jq ".fromRelationships .runsOn[$i] .type" -r "${pg_entity_json}" | tr -d '"')
			if [[ $type == "null" ]]; then
				break
			elif [[ $type == "HOST" ]]; then
				hostId=$(jq ".fromRelationships .runsOn[$i] .id" -r "${pg_entity_json}" | tr -d '"')
				host_entity_json=$(mktemp "/tmp/pg_host_details_entity_fetch_XXXXXXXX")
				response_code=$(curl --connect-timeout 10 -k -s -w "%{http_code}" -X GET "$entities_feed_url/${hostId}?from=now-7d&to=now" \
					-H "accept: application/json; charset=utf-8" \
					-H "Authorization: Api-Token $api_token" \
					-o "${host_entity_json}")

				if [[ $response_code -eq 200 ]]; then
					monitoringMode=$(jq ".properties .monitoringMode" -r "${host_entity_json}" | tr -d '"')
					if [[ "${monitoringMode}" =~ "INFRA" ]]; then
						monitoringMode="INFRA"
					else
						monitoringMode="FULL"
					fi
					if [[ -z $hostName ]]; then
						hostName="$(jq ".displayName" -r "${host_entity_json}" | tr -d '"') (${monitoringMode})"
					else
						hostName="${hostName}, $(jq ".displayName" -r "${host_entity_json}" | tr -d '"') (${monitoringMode})"
					fi
				fi
				rm "${host_entity_json}" > /dev/null 2>&1
				((hostCnt++))
			else
				echo -e "Something other than host type: $type"
			fi
			((i++))
		done
		if [[ -z ${hostCnt} ]]; then
			hostCnt=0
		fi

		# Retrieve Service count and name running on process group
		i=0
		serviceCnt=0
		serviceName=

		while true
		do
			type=$(jq ".toRelationships .runsOn[$i] .type" -r "${pg_entity_json}" | tr -d '"')
			if [[ $type == "null" ]]; then
				break
			elif [[ $type == "SERVICE" ]]; then
				serviceId=$(jq ".toRelationships .runsOn[$i] .id" -r "${pg_entity_json}" | tr -d '"')
				service_entity_json=$(mktemp "/tmp/pg_service_details_entity_fetch_XXXXXXXX")
				response_code=$(curl --connect-timeout 10 -k -s -w "%{http_code}" \
					-X GET "$entities_feed_url/${serviceId}?from=now-7d&to=now" \
					-H "accept: application/json; charset=utf-8" \
					-H "Authorization: Api-Token $api_token" \
					-o "${service_entity_json}")

				if [[ $response_code -eq 200 ]]; then
					#cat ${service_entity_json} | jq '.'
					#echo -e "Service Name: $(cat ${service_entity_json} | jq ".displayName" | tr -d '"')"
					if [[ -z $serviceName ]]; then
						serviceName=$(jq ".displayName" -r "${service_entity_json}" | tr -d '"')
					else
						serviceName="${serviceName}, $(jq ".displayName" -r "${service_entity_json}" | tr -d '"')"
					fi
				fi

				rm "${service_entity_json}" > /dev/null 2>&1
				((serviceCnt++))
			else
				echo -e "Something other than service type: $type"
			fi
			((i++))
		done

		if [[ -z ${serviceCnt} ]]; then
			serviceCnt=0
		fi

		# Retrieve Process Group Instance count and log files discovered
		getPGInfo

		# Retrieve Process Group Deep Monitoring State
		getMonitoringState

		# Retrieve the Process Group Availability State
		getProcessAvailabilityState

		# Set Process Group URL
		pgUrl="${console_base_url}/#processgroupdetails;id=${entityId};gtf=-2h"

		if [[ -z "${logFiles}" ]]; then
			logFiles="No log files monitored"
		fi

		# Make caveat mark if we see that monitoring appears to be on BUT there's a host in infra only mode
		if [[ "${monitoringState}" == "MONITORING_ON" ]] && [[ "${hostName}" =~ "INFRA" && "${hostName}" =~ "FULL" ]]; then
			monitoringState="MONITORING_ON (*)" # Hosts identified in this PG are running in both modes
		fi
		if [[ ! "${hostName}" =~ "FULL" && "${monitoringState}" == "MONITORING_ON" ]]; then
			monitoringState="MONITORING_OFF" # if we don't see reference to FULL in hostName make sure mon off
		fi
		# Write out tab delimited line to file
		echo -e "=HYPERLINK(\"${pgUrl}\", \"${displayName}\")\t${monitoringState}\t${pgAvailabilityState}\t${pgiCnt}\t${software}\t${hostCnt}\t${hostName}\t${serviceCnt}\t${serviceName}\t${logFiles}" >> "${output_file}"
	else
		if [[ $response_code -eq 403 ]]; then
			echo "Token missing required entities.read pemission"
		else
			echo -e "Abnormal return code retrieving entity ${1}.  Response code: $response_code"
		fi
	fi
}

getPGInfo() {
	i=0
	pgiCnt=0
	local logFileExt=""

	while true
	do
		type=$(jq ".toRelationships .isInstanceOf[$i] .type" -r "${pg_entity_json}" | tr -d '"')
		if [[ $type == "null" ]]; then
			break
		elif [[ $type == "PROCESS_GROUP_INSTANCE" ]]; then
			pgiId=$(jq ".toRelationships .isInstanceOf[$i] .id" -r "${pg_entity_json}" | tr -d '"')
			pgi_entity_json=$(mktemp "/tmp/pg_service_details_entity_fetch_XXXXXXXX")
			response_code=$(curl --connect-timeout 10 -k -s -w "%{http_code}" -X GET "$entities_feed_url/${pgiId}?from=now-7d&to=now" \
				-H "accept: application/json; charset=utf-8" \
				-H "Authorization: Api-Token $api_token" \
				-o "${pgi_entity_json}")
			
			if [[ $response_code -eq 200 ]]; then
				echo -e "Process Group Instance Entity: $pgiId"
				jq "." -r "${pgi_entity_json}" >> "${pg_entity_detail_debug}"
				logCnt=0
				while true
				do
					logFileExt=$(jq ".properties .logPathLastUpdate[${logCnt}] .key" -r "${pgi_entity_json}" | tr -d '"')

					logFileExt="${logFileExt//\\//}" # Replace back slash with forward slash
					if [[ "${logFileExt}" == "null" ]]; then
						break
					else
						echo -e "logFileExt: $logFileExt"
						if [[ -z $logFiles ]]; then
							logFiles="${logFileExt}"
						else
							if [[ ${logFiles} == *"${logFileExt}"* ]]; then
								sleep 0 # Skip because it's already in the list.
								#echo -e "Skipping because value already in the list"
							else
								logFiles="${logFiles}, ${logFileExt}"
							fi
						fi
					fi
					((logCnt++))
				done
			fi
			
			rm "${pgi_entity_json}" > /dev/null 2>&1
			((pgiCnt++))
		else
			echo -e "Something other than service type: $type"
		fi
		((i++))
	done
	if [[ -z ${pgiCnt} ]]; then
		pgiCnt=0
	fi

}

getMonitoringState() {
	state_items_json=$(mktemp "/tmp/pg_mon_state_XXXXXXXX")
	local response_code=$(curl --get --connect-timeout 10 -k -s -w "%{http_code}" "${dynatrace_tenant_url}/api/v2/settings/objects" \
		-H "accept: application/json; charset=utf-8" \
		-H "Authorization: Api-Token ${api_token}" \
		--data-urlencode "pageSize=1" \
		--data-urlencode "schemaIds=builtin:process-group.monitoring.state" \
		--data-urlencode "scopes=${entityId}" \
		--data-urlencode "fields=value" \
		-o "${state_items_json}")

	monitoringState=
	if [[ $response_code -eq 200 ]]; then

		if [[ $(jq ".totalCount" -r "${state_items_json}") -eq 1 ]]; then
			monitoringState=$(jq ".items[0] .value .MonitoringState" -r "${state_items_json}")
		else
			#echo -e "Successful response but there are no results returned."
			monitoringState="DEFAULT"
			#jq "." -r "${state_items_json}"
		fi

		if [[ "${monitoringState}" == "DEFAULT" ]] && [[ "${software}" =~ "DOTNET" || "${software}" =~ "GO" ]]; then
			if [[ "${displayName}" =~ "IIS app pool" ]]; then
				monitoringState=MONITORING_ON
			else
				monitoringState=MONITORING_OFF
			fi
		fi
		if [[ "${monitoringState}" == "DEFAULT" ]] && [[ ! "${software}" =~ "DOTNET" || "${software}" =~ "GO" ]]; then
			monitoringState=MONITORING_ON
		fi
		echo -e "Monitoring State: ${monitoringState}"
	else
		echo -e "Failed response from retrieving the monitoring state value.  Response Code: $response_code"
		if [[ $response_code -eq 403 ]]; then
			monitoringState="UNKNOWN (token needs settings.read permission)"
		else
			monitoringState="UNKNOWN ($response_code)"
		fi
		jq '.' -r "${state_items_json}"
	fi	
}

getProcessAvailabilityState() {
	local state_items_json=$(mktemp "/tmp/pg_state_XXXXXXXX")
	local response_code=$(curl --get --connect-timeout 10 -k -s -w "%{http_code}" "${dynatrace_tenant_url}/api/v2/settings/objects" \
		-H "accept: application/json; charset=utf-8" \
		-H "Authorization: Api-Token ${api_token}" \
		--data-urlencode "pageSize=1" \
		--data-urlencode "schemaIds=builtin:availability.process-group-alerting" \
		--data-urlencode "scopes=${entityId}" \
		--data-urlencode "fields=value" \
		-o "${state_items_json}")

	pgAvailabilityState=
	if [[ $response_code -eq 200 ]]; then

		if [[ $(jq ".totalCount" -r "${state_items_json}") -eq 1 ]]; then
			pgAvailabilityState=$(jq ".items[0] .value .enabled" -r "${state_items_json}")
		else
			sleep 0 # successful response but there are no results
		fi
	else
		echo -e "Failed response from retrieving the monitoring state value.  Response Code: $response_code"
	fi

	if [[ "${pgAvailabilityState}" == "true" ]]; then
		pgAvailabilityState="ON"
	else
		if [[ $response_code -eq 200 ]]; then
			pgAvailabilityState="OFF"
		else
			if [[ $response_code -eq 403 ]]; then
				pgAvailabilityState="UNKNOWN (token needs settings.read permission)"
			else
				pgAvailabilityState="UNKNOWN ($response_code)"
			fi
		fi
	fi
	echo -e "PG Availability State: ${pgAvailabilityState}"
	
}

getSoftwareTechnologies () {

	# Check that there is software to process
	softwareList=$(jq ".properties .softwareTechnologies[]" -r "${pg_entity_json}" 2>/dev/null)
	if [[ "${softwareList}" = "null" ]] || [[ "${softwareList}" = "" ]]; then
		software=''
		return 1 # return all the way back out to retrieve next entity
	fi

	s_idx=0
	software=
	while true
	do
		software_type=$(jq ".properties .softwareTechnologies[${s_idx}] .type" -r "${pg_entity_json}" | tr -d '"')
		software_version=$(jq ".properties .softwareTechnologies[${s_idx}] .version" -r "${pg_entity_json}" | tr -d '"')
		software_edition=$(jq ".properties .softwareTechnologies[${s_idx}] .edition" -r "${pg_entity_json}" | tr -d '"')
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
}

# End function area

# Start Main Logic area

###########################################
# Set these variables for your environment
dynatrace_tenant_url="https://xty5136.dynatrace-managed.com/e/b1bgy7d9-498d-4b97-afb4-f6a0307c508d"
ext_root="$HOME/dynatrace"
api_token="dt0c01.I376BI......"
###########################################

entities_feed_url="${dynatrace_tenant_url}/api/v2/entities"
maxPageSize=2000
# pg_entity_list_debug="${ext_root}/pg_entities_debug.json"
pg_entity_detail_debug="${ext_root}/pg_entities_details_debug.json"
output_file="${ext_root}/process_groups.tsv"
rm "${pg_entity_detail_debug}" > /dev/null 2>&1

if [ -z ${ext_root+x} ]; then
	echo -e "Extension Root Directory not set...exiting..."
	exit 1
fi

pg_entities_json=$(mktemp "/tmp/pg_entities_fetch_XXXXXXXX")

# Call Dynatrace to fetch up to max entities of type "Process Group"
response_code=$(curl --connect-timeout 10 -k -s -w "%{http_code}" \
	-X GET "${entities_feed_url}?pageSize=${maxPageSize}&entitySelector=type%28%22PROCESS_GROUP%22%29&from=now-7d&to=now&sort=name" \
	-H "accept: application/json; charset=utf-8" \
	-H "Authorization: Api-Token $api_token" \
	-o "${pg_entities_json}")

if [[ $response_code = 200 ]]; then
	totalCount=$(jq ".totalCount" -r "${pg_entities_json}")
	if [[ $totalCount -gt 0 ]]; then
		if [[ $totalCount -gt ${maxPageSize} ]]; then
			echo -e "Total count > ${maxPageSize}, need to adjust page size in query"
		fi
		# Prepare output tsv file
		echo -e "Process_Group\tMonitoring_State\tProcess_Availability\tProcess_Group_Instance_Count\tTechnologies\tHost_Count\tHosts\tService_Count\tServices\tLogs_Monitored" > "${output_file}"

		line=0
		while [ $line -lt $totalCount ]
		do
			entityId=$(jq ".entities[$line] .entityId" -r "${pg_entities_json}" | tr -d '"')
			displayName=$(jq ".entities[$line] .displayName" -r "${pg_entities_json}" | tr -d '"')
			
			# Skip those process groups that may not be worth the analysis
			if [[ "${displayName}" == *"OneAgent"* || \
					"${displayName}" =~ "Linux System" || \
					"${displayName}" =~ "Windows System" || \
					"${displayName}" =~ "IGNORE" || \
					"${displayName}" =~ "Short-lived" ]]; then
				sleep 0
				#echo -e "Skipping Process Group: ${displayName}"
			else
				if [[ "${entityId}" == "null" ]]; then
					break
				else
					echo -e "\nEntity Id: $entityId"
					echo -e "Display Name: $displayName"
					retrieveEntity "$entityId"
				fi
			fi
			((line++))
		done
		
	else
		sleep 0
		# echo -e "\nResponse Code: $rtn_code"
		#cat ${pg_entities_json} | jq '.'
	fi
else
	echo -e "Response Code abnormal: $response_code"
fi
# Remove temporary files for process
cleanupFiles
echo -e "\nProcess complete.  $(date)\nProcess Group Entities: $line\nOutput file located here: ${output_file}"
