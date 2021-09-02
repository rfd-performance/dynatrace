# Dynatrace Extension - AWS Status

This extension is meant to be run to collect currently published status of AWS services using the Status feed provided by AWS to the public below.

https://status.aws.amazon.com/

This RSS feed is used by AWS to publish service degradations and disruptions. When a new publication is discovered a problem alert will be opened in Dynatrace with the supporting details to both the RSS feed and the detailed status on the Okta site.

Runtime Requirements

1. Python v3
2. Python packages requests and feedparser installed
3. Some kind of job scheduler to run the script on a periodic basis (i.e. cron on Linux or Task Scheduler on Windows)
4. The addition of a tag with a key of "OKTA_STATUS" attached. This should be for any application that is potentially impacted by an AWS service disruption.

Operation:

  python3 ./awsStatusFeed.py --customer <customer> --environment <environment> --iniFile </path/to/ini_file>

  Example one time run: 
  
    python3 ./statusFeed.py RFD LAB ./env.ini
  
  Example cron job to run it every 5 minutes:
  
    */5 * * * * nice python3 ~/awsStatusFeed.py --customer RFD --environment PRD --iniFile ~/env.ini > ~/aws_status_rfd_prd.sysout 2>&1

A regularly occuring job as mentioned should be setup to execute at no more than a 10 minute interval based on the python code as it is now.  It's fine to run it more frequently but the timeout period for the alert in Dynatrace will take 10 minutes at least to clear. 
