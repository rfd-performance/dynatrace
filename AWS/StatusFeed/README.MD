# Dynatrace Extension - AWS Status

This extension is meant to be run to collect currently published status of AWS services using the Status feed provided by AWS to the public below.

https://status.aws.amazon.com/

This RSS feed is used by AWS to publish service degradations and disruptions. When a new publication is discovered a problem alert will be opened in Dynatrace with the supporting details to both the RSS feed and the detailed status on the AWS Status site.

Runtime Requirements

1. Download all of the files (.txt/.ini/.py), the examples below assume you downloaded and are running from your home "~" directory.
2. Python v3
3. Python packages "requests" and "feedparser" installed
4. Some kind of job scheduler to run the script on a periodic basis (i.e. cron on Linux or Task Scheduler on Windows)
5. The addition of a tag with a key of "AWS_STATUS" attached to an Application entity in Dynatrace. This should be for any application that is potentially impacted by an AWS service disruption.

Operation:

  python3 ~/awsStatusFeed.py --customer \<customer\> --environment \<environment\> --iniFile \</path/to/ini_file\>

  Example one time run: 
  
    python3 ./awsStatusFeed.py --customer RFD --environment LAB --iniFile ~/env.ini
  
Identifying AWS Services - The list of services that AWS provides is immense.  A txt file is provided (aws-services-rss-feeds.txt) that at least at this writing was a pretty comprehensive list of US based RSS feeds.  But if something is not there it can be added, the list of available RSS feeds was parsed from the contents of the AWS Status page (https://status.aws.amazon.com/)
  
A regularly occuring job as mentioned should be setup to execute at no more than a 10 minute interval based on the python code as it is now.  It's fine to run it more frequently but the timeout period for the alert in Dynatrace will take 10 minutes at least to clear once the status of the event changes. 
  
  Example cron job to run it every 5 minutes:

  */5 * * * * nice python3 ~/awsStatusFeed.py --customer RFD --environment PRD --iniFile ~/env.ini > ~/aws_status_rfd_prd.sysout 2>&1
