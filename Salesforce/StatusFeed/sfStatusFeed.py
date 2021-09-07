# Author: tnoonan
# Date: 11/30/2020
#
# Description: Extension written to call Salesforce Active Incident Feed.  Then determine whether the
# active incident is impacting a Salesforce list of instances. Because at the time of writing this you
# are unlikely to have Dynatrace "application" data, I went the route of creating a custom device named
# "Salesforce" that problems will be associated with.  If looks up by name and also creates if it doesn't
# exist.
#
# The full list of RSS Feeds were extracted from the following url.
# https://api.status.salesforce.com/v1/docs
#
# Usage: You must supply a valid customer ID, Environment, and path to ini file
#
import os, sys, requests, json, math, configparser, datetime, argparse, pprint

####
#### Subroutine area
####

# Parse incoming arguments to python script
def parseArguments() :
    parser = argparse.ArgumentParser('Evaluate status of AWS Services')
    parser.add_argument("--customer", help="Supply a customer acronym, like RFD")
    parser.add_argument("--environment", help="Supply either LAB, DR, TST, or PRD for example.")
    parser.add_argument("--iniFile", help="Supply path to ini file that contains necessary environment links")

    global args
    args = parser.parse_args()
    return

def getEntityIds() :
    print("Retrieving Salesforce Custom Device from Dynatrace for: " + str(args.customer) + "/" + str(args.environment) + " at "+ str(datetime.datetime.now()))

    try:
        # response = requests.get(config[args.customer + "_" + args.environment]['monitored_entities_url'], headers=headers)
        response = requests.get(config[args.customer + "_" + args.environment]['tenant_url']+"/api/v2/entities?pageSize=25&entitySelector=type(\"CUSTOM_DEVICE\")&from=now-7d&to=now", headers=headers)
        dynatraceDeviceData = json.loads(response.text)
        found = False
        entities = dynatraceDeviceData['entities']
        for entity in entities:
            if "salesforce" in str(entity['displayName']).lower():
                found = True
                entity_ids.append(entity['entityId'])
                break


        # If we didn't find the salesforce custom device, then let's create it.
        if found:
            print("Display Name: " + str(entity['displayName']))
            print("Entity Id: " + str(entity_ids))
        else:
            createCustomDevice()

    except requests.exceptions.RequestException as e:
        print("Error retrieving custom device data from Dynatrace: " + e)
        print("Response Code: " + str(response.status_code))
        quit()

    return

def createCustomDevice() :
    print("Creating Salesforce Custom Device in Dynatrace: " + str(args.customer) + "/" + str(args.environment) + " at "+ str(datetime.datetime.now()))
    global entityId

    # Build json payload for custom device
    payload = {}
    payload['customDeviceId'] = "SALESFORCE_SERVICES"
    payload['displayName'] = "Salesforce"
    payload['group'] = "SalesforceGroup"
    payload['ipAddresses'] = [ "44.229.53.192", "52.40.208.215" ]
    payload['listenPorts'] = [ 443 ]
    payload['faviconUrl'] = "https://trust.salesforce.com/static/images/logo.svg"
    payload['configUrl'] = ""
    payload['type'] = "salesforce_services"
    payload['properties'] = { }
    payload['dnsNames'] = [ "trust.salesforce.com" ]

    try:
        response = requests.post(config[args.customer + "_" + args.environment]['tenant_url']+"/api/v2/entities/custom", data=json.dumps(payload), headers=headers)
        # print("Response Code: " + str(response.status_code))
        # print("Response Body: " + response.text)
        dynatraceDeviceData = json.loads(response.text)

        if response.status_code == 201:
            entityId = dynatraceDeviceData['entityId']
            groupId = dynatraceDeviceData['groupId']
        else:
            print("Failed to add device...")

    except requests.exceptions.RequestException as e:
        print("Error creating device in Dynatrace: " + e)
        print("Response Code: " + str(response.status_code))
        quit()

    return

def buildDynatraceEventPayload(incident):

    # create a concatenated string list of impacted instances for this incident
    impacted_instances = ''
    for x in range(len(sfIncidentDetail['instanceKeys'])):
        if not impacted_instances:
            impacted_instances=sfIncidentDetail['instanceKeys'][x]
        else:
            impacted_instances=impacted_instances + ", " + sfIncidentDetail['instanceKeys'][x]

    print("Impacted Instances: " + str(impacted_instances))
    # create a concatenated string list of impacted services for this incident
    impacted_services = ''
    for x in range(len(sfIncidentDetail['serviceKeys'])):
        if not impacted_services:
            impacted_services=sfIncidentDetail['serviceKeys'][x]
        else:
            impacted_services=impacted_services + ", " + sfIncidentDetail['serviceKeys'][x]
    print("Impacted Services: " + str(impacted_services))

    pp.pprint(incident)

    payload = {}
    payload['title'] = label
    payload['description']  = description + "\n\nImpacted Services: " + impacted_services + "\nImpacted Instances: " + impacted_instances + "\n\nhttps://status.salesforce.com/"
    payload['eventType'] = "AVAILABILITY_EVENT"
    payload['timeoutMinutes'] = 10
    payload['source'] = 'Salesforce Status Extension (from RFD)'
    payload['attachRules'] = { }
    payload['attachRules']['entityIds'] = entity_ids
    print("Payload sending to Dynatrace\n\n"+json.dumps(payload, indent=4))
    return payload

def sendEvent2Dynatrace(event):
    try:
      # response = requests.post(config[args.customer + "_" + args.environment]['event_feed_url'], data=json.dumps(event), headers=headers)
      response = requests.post(config[args.customer + "_" + args.environment]['tenant_url']+"/api/v1/events", data=json.dumps(event), headers=headers)
      print("Succesfully sent data to Dynatrace, response code: " + str(response.status_code))
      print("Response Body: " + str(response.text))
    except:
      e = sys.exc_info()[0]
      print("Error sending data to Dynatrace: " + str(e))
      print("Response Code: " + str(response.status_code))

    return

# Routine to build a python list object out of SF instances listed in a text file.
def loadSFInstances():
    global sf_instances
    sf_instances = []
    sf_instances = str(config[args.customer + "_" + args.environment]['sf_instances']).split(',')
    # with open(config[args.customer + "_" + args.environment]['instance_file']) as instance_list:
    #    idx=0
    #    for x, instance_name in enumerate(instance_list):
    #
    #        if instance_name.startswith('#'):
    #            continue
    #        else:
    #            sf_instances.append(instance_name.replace('\n',''))

    print("Loaded Instances: " + str(sf_instances))

    if len(sf_instances) == 0:
        print("No Salesforce instances loaded from file....exiting.")
        quit()

    return

def retrieveActiveIncidents() :
    print("Retrieving Active Incidents from Salesforce at: "+ str(datetime.datetime.now()))

    try:
        response = requests.get(config['SALESFORCE']['active_incident_feed'], headers=headers)
        global sfActiveIncidentData
        sfActiveIncidentData = json.loads(response.text)
        ###################################################
        # Temporarily assign test data
        # sfActiveIncidentData = test_active_events
        ###################################################

        if not sfActiveIncidentData:
            print("Salesforce returned no active incidents...exiting")
            quit()
        else:
            for incident in sfActiveIncidentData:
                print("incident id: " + str(incident['id']))
                # Checking here if any instances in our defined instance list is within the reported instance keys list returned
                if any(x in sf_instances for x in incident['instanceKeys']):
                    print("Found one of our instances in the reported incident...")
                    retrieveIncidentDetail(incident['id'])
                    # Let's send an event to Dynatrace
                    payload = buildDynatraceEventPayload(incident)
                    sendEvent2Dynatrace(payload)
                else:
                    print("None of our instances found in the list of returned from open incident...")

    except requests.exceptions.RequestException as e:
        print("Error retrieving active incident data from Salesforce: " + e)
        print("Response Code: " + str(response.status_code))
        quit()

    return

def retrieveIncidentDetail(id) :

    print("Retrieving Incident details from Salesforce for at: "+ str(datetime.datetime.now()))

    try:
        detail_feed = str(config['SALESFORCE']['incident_detail_feed']).replace('_INCIDENT_NUMBER_',str(id))

        response = requests.get(detail_feed, headers=headers)
        global sfIncidentDetail
        sfIncidentDetail = json.loads(response.text)

        ###################################################
        # Temporarily assign test data
        # sfIncidentDetail = test_active_event_detail
        ###################################################
        # pp.pprint(sfIncidentDetail)
        global description
        description = ''
        if not sfIncidentDetail:
            print("Salesforce returned no incident details...exiting")
            quit()
        else:
            print("\n\nRight before incidentimpacts loop" + str(type(sfIncidentDetail['IncidentImpacts'])))
            for item in sfIncidentDetail['IncidentImpacts']:
                pp.pprint(item)
                print("What type is item: " + str(type(item)))
                print("Item: " + str(item.get('text')))

                if description:
                    description = description + "\n\n" + "( " + str(item.get('label')) + ") : " + str(item.get('text'))
                else:
                    description = str(item.get('text'))
            global impact_cnt
            impact_cnt=impact_cnt + len(sfIncidentDetail['IncidentImpacts'])
            print("Impact Cnt: " + str(impact_cnt))
            description = description.replace("'","\'")
            print("Right after incidentimpacts loop\n\n" + description + "\n\n")
            # Grabbing the label from the first entry
            global label
            label = sfIncidentDetail['IncidentImpacts'][0].get('label')
            print("Label: " + label)

    except requests.exceptions.RequestException as e:
        print("Error retrieving incident detail from Salesforce: " + e)
        print("Response Code: " + str(response.status_code))
        quit()

    return

def loadTestFile(filename) :
    # JSON file
    f = open (filename, "r")
    # Return dictionary
    return json.loads(f.read())

###
### End subroutine area
###

##############
### Main logic
##############

# create variables
instancesChecked = 0
global description
global impact_cnt
impact_cnt=0
global label

# Other values declared
entity_ids = []

# Setup a pretty print object
pp = pprint.PrettyPrinter(indent=4)

# Parse arguments passed into script
parseArguments()

# Load configuration file supplied
config = configparser.ConfigParser()
config.read(args.iniFile)
config.sections()

token = "Api-Token " + config[args.customer + "_" + args.environment]['api_token']
headers = {'Accept': 'application/json','Content-Type': 'application/json', 'Authorization': token}

# Retrieve Application Entity ID's from Dynatrace
# looking specifically for entities with tag "SALESFORCE_STATUS"
getEntityIds()

# Read the Salesforce instances from file that are of concern.  We build a list and then compare those
# to any instances that may be impacted by actively identified issues from Salesforce Trust status.
loadSFInstances()

# Call Salesforce API to retrieve open incidents
retrieveActiveIncidents()

print("")
print("##### Summary #####")
print("SF Instances Checked:" + str(instancesChecked))
print("SF Impacted Count:" + str(impact_cnt))
print("Complete")
