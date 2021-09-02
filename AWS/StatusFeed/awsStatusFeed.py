# Author: tnoonan
# Date: 11/30/2020
#
# Description: Extension is written to call AWS General RSS Feeds on their services
# provided.  For example for things like cloudformation, cloudfront, cognito, etc.
# The full list of RSS Feeds were extracted from the following url.
# https://status.aws.amazon.com
#
# Usage: You must supply a valid customer ID, Environment, and path to ini file
#
import os, sys, requests, feedparser, json, math, configparser, datetime, argparse, pprint


def parseArguments() :
    parser = argparse.ArgumentParser('Evaluate status of AWS Services')
    parser.add_argument("--customer", help="Supply a customer acronym, like RFD")
    parser.add_argument("--environment", help="Supply either LAB, DR, TST, or PRD for example.")
    parser.add_argument("--iniFile", help="Supply path to ini file that contains necessary environment links")

    global args
    args = parser.parse_args()
    return

def getEntityIds() :
    print("Retrieving Applications from Dynatrace for: " + str(args.customer) + "/" + str(args.environment) + " at "+ str(datetime.datetime.now()))

    try:
        response = requests.get(config[args.customer + "_" + args.environment]['entity_application_feed_url'], headers=headers)
        # print("Response Code: " + str(response.status_code))
        # print("Response Body: " + response.text)
        dynatraceAppData = json.loads(response.text)

        if not dynatraceAppData:
            print("Dynatrace Returned no Applications...exiting")
            sys.exit(1)

        for i, val in enumerate(dynatraceAppData):
            entity_ids.append(str(dynatraceAppData[i]['entityId']))
            #print("Entity ID:" + str(dynatraceAppData[i]['entityId']))

    except requests.exceptions.RequestException as e:
        print("Error retrieving data from Dynatrace: " + e)
        print("Response Code: " + str(response.status_code))
        sys.exit(1)

    return

def buildDynatraceEventPayload(service_name, service_status):
    payload = {}
    payload['title'] = service_name
    payload['description']  = "This may potentially impact the identified application.\n\n" + service_status
    payload['eventType'] = "AVAILABILITY_EVENT"
    payload['timeoutMinutes'] = 10
    payload['source'] = 'AWS Status Extension (from RFD)'
    # payload['annotationType'] = 'defect'
    # payload['annotationDescription'] = 'Extended Description text here....'
    payload['attachRules'] = { }
    payload['attachRules']['entityIds'] = entity_ids
    # payload['attachRules'][1]['tagRule'] = [ { "meTypes": [ "APPLICATION" ], "tags": [ { "context": "CONTEXTLESS", "key": "PRD" } ] } ]
    # print(payload)
    print(json.dumps(payload))
    return payload

def sendEvent2Dynatrace(event):
    try:
      response = requests.post(config[args.customer + "_" + args.environment]['event_feed_url'], data=json.dumps(event), headers=headers)
      print("Succesfully sent data to Dynatrace, response code: " + str(response.status_code))
      print("Response Body: " + str(response.text))
    except:
      e = sys.exc_info()[0]
      print("Error sending data to Dynatrace: " + str(e))
      print("Response Code: " + str(response.status_code))

    return
###
### End function area
###

##############
### Main logic
##############

# create summary variables
servicesChecked = 0
serviceRegionCheck = 0
serviceNormal = 0
serviceNotNormal = 0
serviceNoStatus = 0

# Other values declared
entity_ids = []

# Parse arguments passed into program
parseArguments()

# Load configuration file supplied
config = configparser.ConfigParser()
config.read(args.iniFile)
config.sections()

token = "Api-Token " + config[args.customer + "_" + args.environment]['api_token']
headers = {'Accept': 'application/json','Content-Type': 'application/json', 'Authorization': token}

# Retrieve Application Entity ID's from Dynatrace
# looking specifically for entities with tag "AWS_STATUS"
getEntityIds()
# print("Entity Ids: " + str(entity_ids))

with open(config[args.customer + "_" + args.environment]['aws_rss_feeds']) as feed_list:
   for cnt, line in enumerate(feed_list):
       #print("Line {}: {}".format(cnt, line))
       if line.startswith('['):
            # print("Processing " + line)
            servicesChecked +=1
            #continue
       else:
            serviceRegionCheck +=1
            # print("Processing RSS Feed: " + line)
            if "us-" in line:
                if str(config[args.customer + "_" + args.environment]['aws_region']) in line:
                    print("Call this feed: " + line)
                else:
                    # Contains a region, but not the one that this app runs in.
                    print("Skipping this feed: " + line)
                    continue

            else:
                # no "us-" in string
                print("Call this feed: " + line)

            NewsFeed = feedparser.parse(str(line))

            service_name=NewsFeed.feed.subtitle.replace(' Service Status', '')
            print("Service Name: " + service_name)
            # print('Number of RSS posts :', len(NewsFeed.entries))

            if len(NewsFeed.entries) >= 1:
                entry = NewsFeed.entries[0]
                service_status=entry.title
                print("Service Status: " + str(json.dumps(service_status, indent=4)))
                # Finding either of these strings means AWS sees no issues with their services
                if "normal" in service_status.lower():
                    # print("Service Working Normally")
                    serviceNormal +=1
                elif "informational" in service_status.lower() and ("resolved" in service_status.lower() or "insufficient" in service_status.lower()):
                    # print("Service Working Normally")
                    serviceNormal +=1
                else:
                    print("SERVICE ALERT: " + service_status)
                    # Create Event Payload for Dynatrace
                    payload = buildDynatraceEventPayload(service_name, service_status)

                    # Send event to Dynatrace
                    sendEvent2Dynatrace(payload)

                    serviceNotNormal +=1
            else:
                # print("No status to report")
                serviceNoStatus +=1

print("")
print("##### Summary #####")
print("Services Checked:" + str(servicesChecked))
print("Services by Region Checked: " + str(serviceRegionCheck))
print("Services with no status: " + str(serviceNoStatus))
print("Services Reporting Normal: " + str(serviceNormal))
print("Services Reporting Abnormal: " + str(serviceNotNormal))
print("Complete")
