#!/usr/bin/env bash
bold=$(tput bold)
normal=$(tput sgr0)

USAGE=$(cat <<-END
./ssm-ssh.sh [EC2 instance id]

   Example Usage (select instance): ./ssm-ssh.sh i-abcdef1234
END
)

# error/helper conditions
if [[ $# -ne 1 ]]; then
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
shift

start_session() {
  echo "Starting session to:  $instance_id"
  aws ssm start-session --target $instance_id

  # immediately quit after ending the session
  # exit $?
}

start_session
