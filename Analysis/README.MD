# Process Group Details Export

Description: Script used to export process group information that can be used
for a number of different use cases.
#
Author: Tommy Noonan
Date: 06/20/2023
##Requirements
OS/Software 
- RedHat/Fedora variant OS (tested with Amazon Linux 2)
- curl (tested with 7.88.1)
- mktemp (tested with version 8.22)
- jq (test with version 1.5)

An API token with the "entities.read" & "settings.read" permissions

The output file is in tab-separated format (.tsv).  Open with something like Excel. The following
columns are present and in order below.
- Process Group Display Name - name as you will see in the Dynatrace Screen and it is also a hyperlinked cell that will take you directly to the process group to make any needed changes.
- Monitoring State - Is the process group currently configured for deep monitoring (transaction level monitoring)
- Process Availability - Is process group availability monitoring ON or OFF. If it's off then you will never see an alert if the identified process crashes for any reason.
- Process group instance count - Each process group can have one or more instances, typically running on different hosts.
- Technologies used by the process group
- Host count - The number of hosts that this process group is seen running on
- Host Names - The host names where the process group is running as well as the mode of the agent (FULL or INFRA).
- Service count - The number of identified services discovered
- Service Names - The list of service names discovered 
- Log files monitored - A list of log files that are configured to be monitored

	Set the variables in the main area of the shell script for your environment

		dynatrace_tenant_url="https://guu84124.apps.dynatrace.com"
		ext_root="$HOME/dynatrace"
		api_token="dt0c01.FDF6UM......."

There is an example output file called "process_groups.tsv" provided.
