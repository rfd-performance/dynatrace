# Dynatrace Extension - DMS Task Errors

This extension collects specific Validation States from AWS Database Migration Service (AWS DMS) and reports them to Dynatrace.  This is meant to be an example of how to capture events from an external data source/API/CLI and report them to Dynatrace as Events.

By default, this extension reports on the following DMS Task Validation States:
- Mismatched records
- Suspended records
- Table error
- Error


## Runtime Requirements
1. Download the `check_dms_tasks.sh` file to your ActiveGate EC2 as your standard service user (ie. ec2-user).  The examples below assume you downloaded and are running from your home "~" directory.
2. Make the script executable, `chmod +x ~/check_dms_tasks.sh`
3. [jq](https://stedolan.github.io/jq/) is installed.
4. [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) is installed
5. Some kind of job scheduler to run the script on a periodic basis (ie. cron on Linux)
6. Must use role-based authenticatjion for the AWS integration within Dynatrace. This uses separate roles, [Dynatrace_ActiveGate_role](https://www.dynatrace.com/support/help/setup-and-configuration/setup-on-cloud-platforms/amazon-web-services/amazon-web-services-integrations/cloudwatch-metrics#create-role-ag) and [Dynatrace_monitoring_role](https://www.dynatrace.com/support/help/setup-and-configuration/setup-on-cloud-platforms/amazon-web-services/amazon-web-services-integrations/cloudwatch-metrics#create-role-dt), as described in [Dynatrace's documentation on role-based AWS integration](https://www.dynatrace.com/support/help/setup-and-configuration/setup-on-cloud-platforms/amazon-web-services/amazon-web-services-integrations/cloudwatch-metrics#aws-policy-and-authentication)
7. Add the following IAM Policy Statement to the Dynatrace_monitoring_role defined in the Dynatrace-provided CloudFormation template referenced in the link above.

Use the example below to update the `Dynatrace_monitoring_role`'s IAM Policy Statement.  Be sure to replace `DMS_TASK_ARN1` and `DMS_TASK_ARN2` with your own Task ARNs.

``` json
{
    "Version": "2021-10-17",
    "Statement": [
        {
                "Sid": "ExampleDMSErrorMonitoringPolicyStatement",
                "Effect": "Allow",
                "Action": "dms:DescribeTableStatistics",
                "Resource": [
                    "DMS_TASK_ARN1",
                    "DMS_TASK_ARN2"
                ]
        }
    ]
}
```

## Operation

You should determine your preferred approach to populating credentials and secrets (see script for more details) and then run it.

``` shell
# Then following is an example of how these details could be acquired by a
# function, getSecrets AWS_ROLE_NAME SECRET_NAME
assume_role_arn="$(getSecrets Dynatrace_ActiveGate_role assume_role_arn)"
assume_role_session_name="$(getSecrets Dynatrace_ActiveGate_role assume_role_session_name)"
dt_tenant_id="$(getSecrets Dynatrace_ActiveGate_role dt_tenant_id)"
dt_domain="https://${DT_TENANT_ID}.live.dynatrace.com"
dt_token="$(getSecrets Dynatrace_ActiveGate_role dt_token)"
```

To alert on your own selected Validation States, change the value of the strings `test`-ed on line 102 of `check_dms_tasks.sh`.  The example below alerts on the following example DMS Validation States: `CHANGE`, `VALUES`, `HERE`.

``` shell 
# check_dms_tasks.sh:102
replication_errors="$(jq -r \
    '[.TableStatistics[] | select(.ValidationState | test("(CHANGE|VALUES|HERE)")).ValidationState] | unique | @csv' \
    <<<"${replication_error_resp}"
```

Read more about AWS DMS Validation States in the **Replication task statistics** section, [here](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Validating.html#Replication%20task%20statistics).

Once the `Dynatrace_monitoring_role` IAM role, Dynatrace credentials access within the script, and validation states have been configured, simply execute the script or run it on a schedule.

``` shell
# Once you have configured credentials and DMS Validation States for
# monitoring, simply run the script.
~/check_dms_tasks.sh

# Example cron job to run it every 5 minutes and appends it's output to a log
# and clears those logs every week on Sunday at midnight.
*/5 * * * * nice ~/check_dms_tasks.sh >> check_dms_tasks.out 2>&1
0 0 * * 0 rm -f ~/check_dms_tasks.out
```