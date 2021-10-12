#################################################################################
#
# Description: Example of how to created maintenance schedule in Dynatrace
#								using Powershell.
#
# Author: Tommy Noonan
# Date: 10/11/2021
#
# Example of how to run, assuming from the location of the script.
#
# C:\>powershell ./createMaintenance.ps1 -subject 'Subject of your Maintenance' -description 'Detailed Description of your maintenance' -duration 'duration_integer'
#
#################################################################################
param (
    [string]$subject,
    [string]$description,
    [int]$duration
)

$tenant="YOUR_TENANT_URL"
$api_token="YOUR_TENANT_API_TOKEN"

try {

	# Set start date/time
	$start_date = Get-Date
	$start_date = $start_date.ToUniversalTime()

	# Calculate number of seconds based on the parameter of minutes passed in
	$Number_of_Seconds = $duration * 60

	$end_date = $start_date.ToUniversalTime().AddSeconds($Number_of_Seconds)

	$start_date_str = (Get-Date -Date $start_date -Format "yyyy-MM-dd HH:mm")
	$end_date_str = (Get-Date -Date $end_date -Format "yyyy-MM-dd HH:mm")



	$Body = "
	{
	  ""name"": ""$subject"",
	  ""description"": ""$description"",
	  ""type"": ""PLANNED"",
	  ""suppression"": ""DONT_DETECT_PROBLEMS"",
	  ""suppressSyntheticMonitorsExecution"": true,
	  ""scope"": null,
	  ""schedule"": {
	    ""recurrenceType"": ""ONCE"",
	    ""start"": ""$start_date_str"",
	    ""end"": ""$end_date_str"",
	    ""zoneId"": ""UTC""
	  }
	}
	"

	$headers=@{ Authorization = "Api-Token $api_token" }
	$url = "$tenant/api/config/v1/maintenanceWindows"

	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
	$request = Invoke-RestMethod $url -Headers $headers -Body $Body -Method 'POST' -ContentType "application/json; charset=utf-8"
	$request.Content
}
catch {
	Write-Host '**** ERROR ****'
	echo $_.Exception|format-list -force
	exit 1
}
