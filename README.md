# Dynatrace Automation and Extension Scripts
### This is a repository of scripts that can help you with the operation of Dynatrace.  They are split between Linux and Windows. They are provided as-is with no warranty.  We (RFD www.rfdinc.com) can assist you with modification or creation of additional integration pieces with Dynatrace.

***Linux***
* Create Downtime - This script will allow you to call your dynatrace tenant and setup a fixed length (minutes) downtime schedule given the subject and description

***Windows***
* Count files in a directory - A script that will, given an existing directory name, send the name of that directory and the count of files contained within to Dynatrace.  This one assumes you are running this as a scheduled task on a Windows host on some periodic basis.  

***AWS Status (python based so you can run on Windows or Linux)***
* A python script that will read the RSS feeds that AWS publishes Service Degradation and Disruption information.  This data is then published to Dynatrace for a potentailly impacted application.  Continually running on a schedule (< 10mins) will allow problem to stay open for as long as AWS says there is an issue.

***Okta Status (python based so you can run on Windows or Linux)***
* A python script that will read the RSS feed that Okta publishes Service Degradation and Disruption information.  This data is then published to Dynatrace for a potentailly impacted application.  Continually running on a schedule (< 10mins) will allow problem to stay open for as long as Okta says there is an issue.

***Salesforce Status (python based so you can run on Windows or Linux)***
* A python script that will reach out to the Salesforce trust api to read active incidents reported by the SF team.  Incidents and the instances that they impact are compared agains a list of your organization's instances of concern.  If it matches then a Dynatrace problem is opened with the details.  This extension will automatically(with proper permissions) create a custom "Salesforce" service in Dynatrace which is the impacted entity when a problem arises.  Continually running on a schedule (< 10mins) will allow problem to stay open for as long as Salesforce says there is an issue.

***Analysis***
* Scripts to export process groups and services from a dynatrace environment to a csv file.  This allows you to use filtering in Excel across a complicated environment to complete tasks such as high availability analysis.  It's easy to determine how many services run on a single host, for example.  Otherwise you may be forced to go service by service.  Or, if you wanted to review the technologies that a large environment has, this makes it a snap.
