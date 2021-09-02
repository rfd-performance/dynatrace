# Dynatrace Extension - Okta Status

This extension is meant to be run to collect currently published status of Okta Trust services using the Feed Burner RSS channel below.

http://feeds.feedburner.com/OktaTrustRSS

This RSS feed is used by Okta to publish service degradations and disruptions.  When a new publication is discovered a problem alert will be opened in Dynatrace with the supporting details to both the RSS feed and the detailed status on the Okta site.

Requirements
1. Download all of the files (.ini/.py), the examples below assume you downloaded and are running from your home "~" directory.
2. Python v3
3. Python packages requests and feedparser installed
4. Some kind of job scheduler to run the script on a periodic basis (i.e. cron on Linux or Task Scheduler on Windows)
5. The addition of a tag with a key of "OKTA_STATUS" attached.  This should be for any application that is potentially impacted by an Okta service outage.

Operation:

  python3 ./statusFeed.py --customer <customer> --environment <environment> --iniFile </path/to/ini_file>
  
  Example: python3 ./statusFeed.py --customer RFD --environment LAB --iniFile ./env.ini
  
The problem alarm is set to timeout after 10 minutes.  So, you will want to run on a cycle that is 10 minutes or less.  
