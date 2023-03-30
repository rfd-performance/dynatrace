#################################################################################
#
# Description: Example of how to created maintenance schedule in Dynatrace
#								using Powershell.
#
# Author: Tommy Noonan & Winston Myers
# Date: 03/30/2023
#
# Example of how to run, assuming from the location of the script.
#
# C:\>powershell ./createMaintenanceV2.ps1 -subject 'Subject of your Maintenance' -description 'Detailed Description of your maintenance' -duration 'duration_integer'
#
#################################################################################
param (
    [string]$subject,
    [string]$description,
    [int]$duration
)

$tenant="YOUR_TENANT_URL"
# Be sure that your tenant API token has the settings.write scope
$api_token="YOUR_TENANT_API_TOKEN"

try {

	# Set start date/time
	$start_date = Get-Date
	$start_date = $start_date.ToUniversalTime()

	# Calculate number of seconds based on the parameter of minutes passed in
	$Number_of_Seconds = $duration * 60

	$end_date = $start_date.ToUniversalTime().AddSeconds($Number_of_Seconds)

	$start_date_str = (Get-Date -Date $start_date -Format "yyyy-MM-ddTHH:mm:ss")
	$end_date_str = (Get-Date -Date $end_date -Format "yyyy-MM-ddTHH:mm:ss")

    $timezone = ((Get-Timezone).Id | Out-String)


	$Body = "[{
		""schemaId"": ""builtin:alerting.maintenance-window"",
		""scope"": ""environment"",
		""value"": {
			""enabled"": true,
			""generalProperties"": {
				""name"": ""$subject"",
				""description"": ""$description"",
				""maintenanceType"": ""PLANNED"",
				""suppression"": ""DETECT_PROBLEMS_DONT_ALERT"",
				""disableSyntheticMonitorExecution"": true
			},
			""schedule"": {
				""scheduleType"": ""ONCE"",
				""onceRecurrence"": {
					""startTime"": ""$start_date_str"",
					""endTime"": ""$end_date_str"",
					""timeZone"": ""UTC""
				}
			},
			""filters"": []
		}
	}]
	"

	$headers=@{ Authorization = "Api-Token $api_token" }
	$url = "$tenant/api/v2/settings/objects?validateOnly=false"

	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
	$request = Invoke-RestMethod $url -Headers $headers -Body $Body -Method 'POST' -ContentType "application/json; charset=utf-8"
	$request.Content
}
catch {
	Write-Host '**** ERROR ****'
	echo $_.Exception|format-list -force
	exit 1
}
