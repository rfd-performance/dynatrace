#
import json, configparser, argparse, traceback, sys

# begin functions

def parseArguments() :
    parser = argparse.ArgumentParser('Cleanup payload for Metric Anomaly update ')
    parser.add_argument("--json", help="Supply the json file to add the attributes to")
    parser.add_argument("--action", help="ENABLE or DISABLE")

    global args
    args = parser.parse_args()
    return

# end functions

# Main logic area

# Parse arguments passed into program
parseArguments()
#print(args.json)
with open(args.json, "r") as read_file:
    dynatrace_json = json.load(read_file)

    if "metadata" in dynatrace_json.keys():
        dynatrace_json.pop("metadata")
        print("Removed metadata element")

    dynatrace_json.pop("enabled")
    if "ENABLE" in args.action:
        dynatrace_json['enabled'] = 'true'
    else:
        dynatrace_json['enabled'] = 'false'

read_file.close()

new_json = open(args.json,'w')
new_json.write(json.dumps(dynatrace_json))
new_json.close()
