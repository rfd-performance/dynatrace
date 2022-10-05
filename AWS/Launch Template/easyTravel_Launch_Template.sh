#!/bin/bash
# This user data script can be used for a standalone ec2 launch or as a part
# of a launch template.  You will want to use a very specific ami id specified below.

# In us-east-1 use AMI ID: ami-0a59f0e26c55590e9

# This script will do the following after launch and with valid input parameters set.
#
#   1. Update the instance
#   2. Install a JDK
#   3. Install unzip
#   4. Install aws cli
#   5. Create/Update Route53 DNS Name
#   6. Download & Install OneAgent on the instance, given correct input values
#   7. Download, Install, and start the EasyTravel Web Application
#   8. Send a message via web hook to MS Teams
#
#
###
### Set values for you environment below
###
node="easyTravel1"
dt_domain="<your_tenant_id>.dynatrace-managed.com"
dt_token="dt0c01.7EPH5T3R..." # You want to populate with a token from the installation page
environment_id="d56c1...c3f8" # If Dynatrace Managed, enter environment ID
easy_travel_domain="your_domain.com" # This will be the domain referenced in route 53  like ".yourdomain.com"
route53_zone_id="Z006....2BD" # Enter the Zone ID of your public hosted zone in Route53
teams_webhook_url="https://your.webhook.office.com/webhookb2/685425c7.../IncomingWebhook/.../..."
###
### End Configuration
###

### Begin Installation process
sudo apt-get update
sudo apt-get install default-jdk -y
sudo apt-get install unzip -y

curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install

# Create payload to update Route53 Public Zone
JSON_FILE="/home/ubuntu/record_set.json"
touch $JSON_FILE

(
cat <<EOF
{
    "Comment": "Create easyTravel record set",
    "Changes": [
        {
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "${node}.${easy_travel_domain}",
                "Type": "CNAME",
                "TTL": 60,
                "ResourceRecords": [
                    {
                        "Value": "$(curl http://169.254.169.254/latest/meta-data/public-hostname)"
                    }
                ]
            }
        }
    ]
}
EOF
) > $JSON_FILE
echo "Creating DNS Record set"
aws route53 change-resource-record-sets --hosted-zone-id "${route53_zone_id}" --change-batch file://$JSON_FILE

if [[ "${dt_domain}" =~ "live.dynatrace.com" || "${dt_domain}" =~ "dynatrace-fedramp.com" ]]; then # SaaS or FedRamp Saas
  dt_url="https://${dt_domain}/api/v1/deployment/installer/agent/unix/default/latest?arch=x86&flavor=default"
else
  dt_url="https://${dt_domain}/e/${environment_id}/api/v1/deployment/installer/agent/unix/default/latest?arch=x86&flavor=default"
fi
# Download and install Dynatrace
wget -O /home/ubuntu/Dynatrace-OneAgent-Linux.sh "${dt_url}" --header="Authorization: Api-Token ${dt_token}"
sudo /bin/sh /home/ubuntu/Dynatrace-OneAgent-Linux.sh --set-infra-only=false --set-app-log-content-access=true --set-host-group=easyTravel --set-host-name=easyTravel

# Download, install and start Easy Travel
mkdir ./easytravel 2>&1 > /dev/null
wget -q -O /home/ubuntu/dynatrace-easytravel-linux-x86_64.jar https://etinstallers.demoability.dynatracelabs.com/latest/dynatrace-easytravel-linux-x86_64.jar
sudo java -jar /home/ubuntu/dynatrace-easytravel-linux-x86_64.jar -y -t /home/ubuntu/easytravel 2>&1 > /dev/null
cd /home/ubuntu/easytravel/resources
sudo /bin/bash installChromeDeps.sh 2>&1 > /dev/null
cd /home/ubuntu
sudo chown -R ubuntu:ubuntu /home/ubuntu/easytravel
cd /home/ubuntu/easytravel/weblauncher
sudo -Hu ubuntu sh -c "nohup /bin/bash weblauncher.sh 2>&1 &"

# Notify teams that environment is ready
curl --connect-timeout 10 -k -s \
  -H 'Content-Type: application/json' \
  -X POST \
  -d "{\"text\": \"${node} environment is ready for use.  http:\/\/${node}.${easy_travel_domain}:8094\"}" "${teams_webhook_url}"
