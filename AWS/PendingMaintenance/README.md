# Dynatrace Extension - AWS Managed Service Pending Maintenance

This extension collects and reports Dynatrace Events based on pending maintenance to various AWS managed services not exposed via AWS native services like Amazon EventBridge.  Monitored managed service maintenance actions include:
- Relational Database Service (RDS) Pending Maintenance
- Database Migration Service (DMS) Pending Maintenance

This is meant to be an example of how to capture events from an external data source/API/CLI and report them to Dynatrace as Events.

## Runtime Requirements
1. Download the `check_aws_pending_maint.sh` file to your ActiveGate EC2 as your standard service user (ie. ec2-user).  The examples below assume you downloaded and are running from your home "~" directory.
2. Make the script executable, `chmod +x ~/check_aws_pending_maint.sh`
3. [jq](https://stedolan.github.io/jq/) is installed.
4. [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) is installed
5. Some kind of job scheduler to run the script on a periodic basis (ie. cron on Linux)
6. Must use role-based authenticatjion for the AWS integration within Dynatrace. This uses separate roles, [Dynatrace_ActiveGate_role](https://www.dynatrace.com/support/help/setup-and-configuration/setup-on-cloud-platforms/amazon-web-services/amazon-web-services-integrations/cloudwatch-metrics#create-role-ag) and [Dynatrace_monitoring_role](https://www.dynatrace.com/support/help/setup-and-configuration/setup-on-cloud-platforms/amazon-web-services/amazon-web-services-integrations/cloudwatch-metrics#create-role-dt), as described in [Dynatrace's documentation on role-based AWS integration](https://www.dynatrace.com/support/help/setup-and-configuration/setup-on-cloud-platforms/amazon-web-services/amazon-web-services-integrations/cloudwatch-metrics#aws-policy-and-authentication)
7. Add the following IAM Policy Statement to the `Dynatrace_monitoring_role` defined in the Dynatrace-provided CloudFormation template referenced above. Use the example below to update the `Dynatrace_monitoring_role`'s IAM Policy Statement.  Be sure to replace the `RDS_INSTANCE_ARN` and `DMS_REPLICATION_INSTANCE` with the resources you wish to monitor in the `Resource` array below.

``` json
{
    "Version": "2021-10-17",
    "Statement": [
        {
                "Sid": "ExamplePendingMaintenancePolicyStatement",
                "Effect": "Allow",
                "Action": [
                    "dms:DescribePendingMaintenanceActions", 
                    "rds:DescribePendingMaintenanceActions"
                ],
                "Resource": [
                    "RDS_INSTANCE_ARN1",
                    "RDS_INSTANCE_ARN2",
                    "DMS_REPLICATION_INSTANCE_ARN1",
                    "DMS_REPLICATION_INSTANCE_ARN2"
                ]
        }
    ]
}
```

## Operation

You should determine your preferred approach to populating credentials and secrets.  The following assumes that some function `getSecrets` was defined previously and is used as an example.

``` shell
# Then following is an example of how these details could be acquired by a
# function, getSecrets AWS_ROLE_NAME SECRET_NAME
assume_role_arn="$(getSecrets Dynatrace_ActiveGate_role assume_role_arn)"
assume_role_session_name="$(getSecrets Dynatrace_ActiveGate_role assume_role_session_name)"
dt_tenant_id="$(getSecrets Dynatrace_ActiveGate_role dt_tenant_id)"
dt_domain="https://${DT_TENANT_ID}.live.dynatrace.com"
dt_token="$(getSecrets Dynatrace_ActiveGate_role dt_token)"
```

Once the `Dynatrace_monitoring_role` IAM role and Dynatrace credentials have been configured, simply execute the script or run it on a schedule.

``` shell
# Once you have configured credentials and DMS Validation States for
# monitoring, simply run the script.
~/check_aws_pending_maint.sh

# Example cron job to run it every 5 minutes and appends it's output to a log
# and clears those logs every week on Sunday at midnight.
*/5 * * * * nice ~/check_aws_pending_maint.sh >> check_aws_pending_maint.out 2>&1
0 0 * * 0 rm -f ~/check_aws_pending_maint.out
```