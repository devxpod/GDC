#!/usr/bin/env bash
bold=$(tput bold)
normal=$(tput sgr0)

USAGE=$(cat <<-END
./ssm-send-command.sh

   Example Usage:
   export AWS_REGION=us-east-1
   source ~/bin/assume-role.sh some.user some-identity arn:aws:iam::<account>:role/BiToolsIdentityAccessRole <mfa-token>
   source ~/bin/ssm-send-command.sh <instance-id> <command> <any_value_if_you_want_to_get_output>

   Example send command:
      source ~/bin/ssm-send-command.sh i-1nst4nc3ID "sudo rm /opt/app/airflow/output.log && /opt/app/airflow/update-plus.sh prod >> /opt/app/airflow/output.log"

END
)

# error/helper conditions
if [[ $# -lt 2 ]]; then
  echo "$USAGE"
  exit 0
fi

if [[ $1 == "-h" ]]; then
  echo "$USAGE"
  exit 0
fi

if ! [ -x "$(command -v aws)" ]; then
  echo 'Error: aws-cli is not installed.' >&2
  echo 'Try installing aws cli v2: go here - https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html' >&2
  echo 'Then install the ssm plugin from - https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html' >&2
  exit 1
fi

instance_id=$1
command=$2
wait_for_output=$3

echo "Starting session to:  $instance_id with command $command"

cmdId=$(aws ssm send-command --instance-ids "$instance_id" --document-name "AWS-RunShellScript" --query "Command.CommandId" --output text --parameters "commands=[${command}]")
[ $? -ne 0 ] && { echo "$USAGE"; exit 1; }
if [ -n "$wait_for_output" ] ; then
  while [ "$(aws ssm list-command-invocations --command-id "$cmdId" --query "CommandInvocations[].Status" --output text)" == "InProgress" ]; do sleep 1; done
  aws ssm list-command-invocations --command-id "$cmdId" --details --query "CommandInvocations[*].CommandPlugins[*].Output[]" --output text
fi

