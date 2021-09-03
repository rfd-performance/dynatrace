#################################################################################
#
# Description: Count number of files in directory and report to Dynatrace
#               Assumes that you have OneAgent installed locally using the
#               default port AND have setup a scheduler (Task Scheduler?) in
#               Windows to run periodically
#
# Author: Tommy Noonan
# Date: 08/27/2021
#
# Example of how to run, assuming from the location of the script.
#
# C:\>powershell ./countFiles.ps1 'c:\Temp'
#
#################################################################################

if ((Test-Path -LiteralPath $args[0])) {

	try {

		# Change into the directory provided
		cd $args[0]

		# Determine number of files in current directory
		$Filecount = (Get-ChildItem -File | Measure-Object).Count
		Write-Host 'File Count: ' $Filecount

		# Create safe directory label
		$directory = $args[0] -replace "\:","_" -replace "\\","_"

		# Format body for Dynatrace
		$Body = $directory+' '+$Filecount
		Write-Host 'Body: ' $Body

		# Send data to Dynatrace
		Invoke-WebRequest 'http://localhost:14499/metrics/ingest' -Body $Body -Method 'POST' -ContentType "text/plain; charset=utf-8"
	}
	catch {
		Write-Host 'Some kind of error'
		echo $_.Exception|format-list -force
		exit 1
	}
}
else {
	Write-Host "Directory "$args[0]" does not exist...exiting"
}
