## createMaintenance.sh
A Bash script that will create a maintenance downtime schedule in Dynatrace for you.  This script can be used as a starting point to further refine a downtime to specific resources.

## countFiles.ps1
Given a directory as a parameter, this powershell script will report the number of files and send the data to the local Dynatrace OneAgent.  Directory paths are normalized to remove special characters not permitted by the Dynatrace api such as colons and back slashes.  These items are replaced with an underscore "_".

Setup a scheduled task to export the data to Dynatrace on a periodic basis.  Use cases may vary.

## scheduler.ps1
This is a basic schedule that can be created from the windows command prompt using powershell.  Review the schedule after import.  There are many more options to use.

## createMaintenance.ps1
This is a powershell script that given three parameters (subject, description and time in minutes) will create a maintenance schedule in Dynatrace.   

## updateCustomEventState.sh
This is a bash script that will change the state of a custom event in Dynatrace. You would either be calling to enable or disable the custom event.

## ./lib/CleanCustomEventStatePayload.py
This python script is used by updateCustomEventState.sh to cleanup the payload that is sent for update to Dynatrace.
