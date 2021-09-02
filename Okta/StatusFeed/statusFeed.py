# Author: tnoonan
# Date: 08/30/2021
#
# Description: Extension written to call the FeedBurner RSS syndication feed that Okta publishes
# their trust events.
# The full list of RSS Feeds were extracted from the following url.
# https://status.okta.com/
# http://feeds.feedburner.com/OktaTrustRSS
#
# Usage: You must supply a valid customer ID, Environment, and path to ini file
#
import os, sys, requests, feedparser, json, math, configparser, datetime, argparse, pprint


def parseArguments() :
    parser = argparse.ArgumentParser('Evaluate status of Okta Services')
    parser.add_argument("--customer", help="Supply a customer value")
    parser.add_argument("--environment", help="Supply something like LAB, DR, TST, or PRD")
    parser.add_argument("--iniFile", help="Supply path to ini file")

    global args
    args = parser.parse_args()
    return

def getEntityIds() :
    print("Retrieving Applications from Dynatrace for: " + str(args.customer) + "/" + str(args.environment) + " at "+ str(datetime.datetime.now()))

    try:
        print("Applications URL: " + str(config[args.customer + "_" + args.environment]['entity_application_feed_url']))
        response = requests.get(config[args.customer + "_" + args.environment]['entity_application_feed_url'], headers=headers)
        print("Response Code: " + str(response.status_code))
        print("Response Body: " + response.text)
        dynatraceAppData = json.loads(response.text)

        if not dynatraceAppData:
            print("Dynatrace Returned no Applications having OKTA_STATUS as a tag ...exiting")
            sys.exit(1)

        for i, val in enumerate(dynatraceAppData):
            entity_ids.append(str(dynatraceAppData[i]['entityId']))
            #print("Entity ID:" + str(dynatraceAppData[i]['entityId']))

    except requests.exceptions.RequestException as e:
        print("Error retrieving data from Dynatrace: " + e)
        print("Response Code: " + str(response.status_code))
        sys.exit(1)

    return

def buildDynatraceEventPayload():
    payload = {}
    payload['title'] = str(entry.title)
    payload['description']  =  str("\n"+entry.summary) + '\n\n' + str(entry.link) + "\n\nThi is a message retrieved from the Okta Trust RSS Feed (http://feeds.feedburner.com/OktaTrustRSS)\n\n"
    payload['eventType'] = "AVAILABILITY_EVENT"
    payload['timeoutMinutes'] = 10
    payload['source'] = 'OKTA Status Extension (from RFD)'
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
# looking specifically for entities with tag "OKTA_STATUS"
getEntityIds()
print("Entity Ids: " + str(entity_ids))

NewsFeed = feedparser.parse(str(config['OKTA']['rss_feed']))
# print("NewsFeed:" + str(NewsFeed))
print("OKTA RSS Feed: " + str(config['OKTA']['rss_feed'])+'\n')

#service_name=NewsFeed.feed.subtitle.replace(' Service Status', '')
service_name="Okta Status"
print("Service Name: " + service_name)
# print('Number of RSS posts :', len(NewsFeed.entries))
print("First entry\n" + str(json.dumps(NewsFeed.entries[0],indent=4)))
#if len(NewsFeed.entries) >= 1:
resolvedIssueCnt = 0
openIssueCnt = 0
otherCnt = 0

for x in range(len(NewsFeed.entries)):

    # Break out after certain amount.  They keep around a 2 year history.
    if x > 4:
        break

    entry = NewsFeed.entries[x]
    #print("First NewsFeed entry: " + str(entry))
    #entryTitle=entry.title
    #link=entry.title_detail.link
    #print("Link to issue: " + link)
    print("Title: " + entry.title)
    print("Link: " + str(entry.link))
    print("Summary: " + str(entry.summary))
    print("Updated: " + str(entry.updated))
    # Finding either of these strings means AWS sees no issues with their services
    if "degradation" in entry.title.lower() or "disruption" in entry.title.lower():
        if "resolve" in entry.title.lower():
            print("Issue is resolved...\n")
            resolvedIssueCnt +=1
        else:
            print("Open issue....\n")
            payload = buildDynatraceEventPayload()

            # Send event to Dynatrace
            sendEvent2Dynatrace(payload)
            openIssueCnt +=1

    else:
        otherCnt +=1

print("")
print("##### Summary #####")
print("Feed Content Items Checked: " + str(x))
print("Going back as far as: " + str(entry.updated))
print("Open Issues: " + str(openIssueCnt))
print("Resolved Issues: " + str(resolvedIssueCnt))
print("Count of non Disruption/Degradation: " + str(otherCnt))
print("")
print("Complete")
