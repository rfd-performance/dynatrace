# Scripts specifically for Windows

Most likely written in powershell or interacting with powershell.

## countFiles.ps1
Given a directory as a parameter, this powershell script will report the number of files and send the data to the local Dynatrace OneAgent.  Directory paths are normalized to remove special characters not permitted by the Dynatrace api such as colons and back slashes.  These items are replaced with an underscore "_".

Setup a scheduled task to export the data to Dynatrace on a periodic basis.  Use cases may vary.

## scheduler.ps1
This is a basic schedule that can be created from the windows command prompt using powershell.  Review the schedule after import.  There are many more options to use.

## createMaintenance.ps1
This is a powershell script that given three parameters (subject, description and time in minutes) will create a maintenance schedule in Dynatrace.   

## FilesOlderthanXmins.ps1
This script is intended to report a metric to Dynatrace with the value of the count of files in a specific directory older than five minutes.
