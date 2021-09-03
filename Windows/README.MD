# Scripts specifically for Windows

Most likely written in powershell or interacting with powershell.

## countFiles.ps1
Given a directory as a parameter, this powershell script will report the number of files and send the data to the local Dynatrace OneAgent.  Directory paths are normalized to remove special characters not permitted by the Dynatrace api such as colons and back slashes.  These items are replaced with an underscore "_".

Setup a scheduled task to export the data to Dynatrace on a periodic basis.  Use cases may vary.

