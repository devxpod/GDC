#!/usr/bin/env bash

USAGE=$(cat <<-END
./ssm-jump-tunnel.sh [EC2 Bastion instance id] [region] [local port] [remote host] [remote port]
   Script to create an SSH tunnel through a private EC2 instance to another private resource port.
   For example:
     - your machine
     - bastion/jump host in AWS private subnet with access to the resource you want to tunnel to
     - resource you want to access such as an RDS endpoint

   Example Usage: ssm-jump-tunnel.sh i-abcd1234 eu-west-1 5432 db-cluster.cluster-abcdefg6reul.eu-west-1.rds.amazonaws.com 5432
END
)

if [[ $# -ne 5 ]]; then
  echo "$USAGE" >&2
  exit 1
fi

if ! [ -x "$(command -v aws)" ]; then
  echo 'Error: aws-cli is not installed.' >&2
  echo 'Try installing aws cli v2: go here - https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html' >&2
  echo 'Then install the ssm plugin from - https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html' >&2
  exit 1
fi


instance_id=$1
shift
region=$1
shift
local_port=$1
shift
remote_host=$1
shift
remote_port=$1
shift

echo "Starting SSM tunnel to:  $remote_host:$remote_port with local port $local_port"
echo "Press ^C to close port forward."

if [ -z "$DEV_CONTAINER" ]; then
  echo "The connection is not fully established until you see a message containing \"Waiting for connections...\""
  aws ssm start-session \
    --output text \
    --region "$region" \
    --target "$instance_id" \
    --document-name AWS-StartPortForwardingSessionToRemoteHost \
    --parameters host="$remote_host",portNumber="$remote_port",localPortNumber="$local_port"
  ret=$?
  if [ $ret -ne 0 ]; then
    echo "Failed to open tunnel with exit code ($ret)."
  fi
  exit $ret
else
  echo "socat exposing localhost:$local_port to GDC eth0...."
  aws ssm start-session \
    --output text \
    --region "$region" \
    --target "$instance_id" \
    --document-name AWS-StartPortForwardingSessionToRemoteHost \
    --parameters host="$remote_host",portNumber="$remote_port",localPortNumber="$local_port" &>/dev/null &

  # if we are running in a dev container listen on all interface so port can be forwarded to host if desired
  socat "tcp-l:$local_port",fork,reuseaddr,bind="$(ifconfig | grep inet | head -n1 | cut -dt -f2 | cut -d' ' -f2)" "tcp:127.0.0.1:$local_port"
fi
