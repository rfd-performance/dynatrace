# Dynatrace Extension - Salesforce Status

This extension is meant to be run to collect currently published status of Salesforce trust services using the API provided by Salesforce to the public below.

https://api.status.salesforce.com/v1/docs/

This API is used by Salesforce to publish service degradations and disruptions. When a new publication is discovered a problem alert will be opened in Dynatrace with the supporting details and a link to the Salesforce Status page.

Runtime Requirements

1. Download all of the files (.ini/.py), the examples below assume you downloaded and are running from your home "~" directory.
2. Python v3
3. Python package "requests" installed
4. Some kind of job scheduler to run the script on a periodic basis (i.e. cron on Linux or Task Scheduler on Windows)

Operation:

  python3 ~/sfStatusFeed.py --customer \<customer\> --environment \<environment\> --iniFile \</path/to/ini_file\>

  Example one time run: 
  
    python3 ./sfStatusFeed.py --customer RFD --environment LAB --iniFile ~/env.ini
  
The ini file includes a property for providing a comma delimited list of Salesforce instances.  You should provide a list of instances that are associated with your organization.

A regularly occuring job as mentioned should be setup to execute at no more than a 10 minute interval based on the python code as it is now.  It's fine to run it more frequently but the timeout period for the alert in Dynatrace will take 10 minutes at least to clear once the status of the event changes. 
  
  Example cron job to run it every 5 minutes:

  */5 * * * * nice python3 ~/sfStatusFeed.py --customer RFD --environment LAB --iniFile ~/env.ini > ~/sf_status_rfd_lab.sysout 2>&1
