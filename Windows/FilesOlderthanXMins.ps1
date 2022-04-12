# Given path, send count of files > 5 minutes to Dynatrace using local ingest listener
#
$fullPath = "C:\inetpub\mailroot\Queue"
$numDays = 0
$numHours = 0
$numMins = 5

function getOldFiles($path, $maxDays, $maxHours, $maxMins) {
  $currDate = Get-Date
  #Get all children in the path where the last write time is greater than 5 minutes. psIsContainer checks whether the object is a folder.
  $oldFiles = @(Get-ChildItem $path -include *.* -recurse | where {($_.LastWriteTime -lt $currDate.AddDays(-$maxDays).AddHours(-$maxHours).AddMinutes(-$maxMins)) -and ($_.psIsContainer -eq $false)})

  $oldFileCount = 0

  for ($i = 0; $i -lt $oldFiles.Length; $i++) {
    $oldFileCount += 1
    $thisFile = $oldFiles[$i]
    Write-Host ("This file is old '" + $thisFile.Name + "' - " + $thisFile.LastWriteTime)
  }

  Write-Host ("A total of " + $oldFileCount + " old files were found.")
  try {

    # Format body for Dynatrace
    $Body = 'Email_Queue_Count gauge,'+$oldFileCount
    Write-Host 'Body: ' $Body

    # Send data to Dynatrace
    Invoke-RestMethod 'http://localhost:14499/metrics/ingest' -Body $Body -Method 'POST' -ContentType "text/plain; charset=utf-8"
  }
  catch {
    Write-Host 'Some kind of error'
    echo $_.Exception|format-list -force
    exit 1
  }
}

getOldFiles $fullPath $numDays $numHours $numMins
