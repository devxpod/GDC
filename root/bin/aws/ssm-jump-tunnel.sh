#!/usr/bin/env bash
bold=$(tput bold)
normal=$(tput sgr0)

USAGE=$(cat <<-END
./ssm-jump-tunnel.sh [EC2 Bastion instance id] [availability zone] [local port] [remote host] [remote port]
   Script to create an SSH tunnel through a private EC2 instance to another private resource port.
   For example:
     - your machine
     - bastion/jump host in AWS private subnet with access to the resource you want to tunnel to
     - resource you want to access such as an RDS endpoint

   Example Usage: ssm-jump-tunnel.sh i-abcd1234 us-west-2a 9191 myrdscluster.cluster-1234oubcj1jy.us-west-2.rds.amazonaws.com 5432
END
)


# error/helper conditions

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

# if we are running in a dev container listen on all interface so port can be forwarded to host if desired
if [ -n "$DEV_CONTAINER" ]; then
  interface="0.0.0.0:"
else
  interface=""
fi

instance_id=$1
shift
availability_zone=$1
shift
local_port=$1
shift
remote_host=$1
shift
remote_port=$1
shift

chars=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789
key_name="aws_temp_"
for i in {1..16} ; do
    key_name=$key_name"${chars:RANDOM%${#chars}:1}"
done

echo "Starting SSM tunnel to:  $remote_host:$remote_port with local port $local_port"
echo "Generating public key"
echo "ssh-keygen -q -t rsa -f ~/.ssh/$key_name -N '' <<<y 2>&1"
ssh-keygen -q -t rsa -f ~/.ssh/$key_name -N '' <<<y 2>&1
ret=$?
if [ $ret -ne 0 ]; then
  echo "Failed to generate $key_name rsa key with exit code ($ret). Aborting..."
  exit $ret
fi

echo "copying temp ssh key to instance ${1}"
echo "aws ec2-instance-connect send-ssh-public-key --instance-id $instance_id --instance-os-user ssm-user --availability-zone $availability_zone --ssh-public-key file://\"~/.ssh/$key_name.pub 2>&1\""
aws ec2-instance-connect send-ssh-public-key --instance-id $instance_id --instance-os-user ssm-user --availability-zone $availability_zone --ssh-public-key file://"~/.ssh/$key_name.pub" 2>&1
ret=$?
if [ $ret -ne 0 ]; then
  echo "Failed to copy $key_name rsa key to instance with exit code ($ret). Aborting..."
  rm ~/.ssh/$key_name ~/.ssh/$key_name.pub 2>&1 > /dev/null
  exit $ret
fi

echo "ssh -i ~/.ssh/$key_name -N -L $interface$local_port:$remote_host:$remote_port ssm-user@$instance_id -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ControlMaster=auto -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o ProxyCommand=\"aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters portNumber=%p\""
echo "the connection is not fully established until you see a message containing \"Permanently added '$instance_id' (ECDSA) to the list of known hosts.\""
echo "press ^C to close port forward and cleanup"
ssh -i ~/.ssh/$key_name -N -L $interface$local_port:$remote_host:$remote_port ssm-user@$instance_id -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ControlMaster=auto -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o ProxyCommand="aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters portNumber=%p" 2>&1
ret=$?
if [ $ret -ne 0 ]; then
  echo "Failed to open tunnel with exit code ($ret)."
fi
echo "Cleaning up rsa keys"
rm ~/.ssh/$key_name ~/.ssh/$key_name.pub 2>&1 > /dev/null

# immediately quit after ending the session
exit $ret
