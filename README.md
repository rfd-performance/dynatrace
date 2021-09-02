# Dynatrace Scripts
### This is a repository of scripts that can help you with the operation of Dynatrace.  They are split between Linux and Windows. They are provided as-is with no warranty.  We (RFD www.rfdinc.com) can assist you with modification or creation of additional integration pieces with Dynatrace.

***Linux***
* createDowntime.sh - This script will allow you to call your dynatrace tenant and setup a fixed length (minutes) downtime schedule given the subject and description

***Windows***
* countFiles.ps1 - A script that will, given an existing directory name, send the name of that directory and the count of files contained within to Dynatrace.  This one assumes you are running this as a scheduled task on a Windows host on some periodic basis.  

***Okta (python based so you can run on Windows or Linux)***
* statusFeed.py - A python script that will, read the RSS feed that Okta publishes Service Degradation and Disruption information.  This data is then publised tto Dynatrace for a potentailly impacted application.  Continually running on a schedule (< 10mins) will allow problem to stay open for as long as Okta says there is an issue.
