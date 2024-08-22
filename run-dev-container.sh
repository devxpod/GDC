#!/usr/bin/env bash

if [ -z "$ARCH" ]; then
  export ARCH=$(uname -m)
fi

if [ -z "$COMPOSE_BIN" ]; then
  COMPOSE_BIN="docker compose"
fi
echo "Using compose bin '$COMPOSE_BIN'"
export COMPOSE_BIN

docker --version

# make sure windows git bash does not alter paths
export MSYS_NO_PATHCONV=1
# gets folder where this script actually lives, resolving symlinks if needed
# this folder is the docker root for building the container
SCRIPT_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]:-$0}")")" &> /dev/null && pwd 2> /dev/null)"

if [ -z "$GDC_DIR" ]; then
  GDC_DIR=$SCRIPT_DIR
fi
export GDC_DIR

if [ -r "$SCRIPT_DIR/.env-gdc" ]; then
  echo "Loading container .env-gdc environment file"
  source "$SCRIPT_DIR/.env-gdc"
fi

if [ -r "$SCRIPT_DIR/.env-gdc-local" ]; then
  echo "Loading container .env-gdc-local environment file"
  source "$SCRIPT_DIR/.env-gdc-local"
fi


# this will get mounted under /workspace in container
if [ "$USE_WORKSPACE" = "yes" ]; then
  HOST_PROJECT_PATH=$(pwd)
else
  HOST_PROJECT_PATH=''
fi

if [ -n "$FORCE_PROJECT_PATH" ]; then
  HOST_PROJECT_PATH="$FORCE_PROJECT_PATH"
fi

HOST_PROJECT_FOLDER_NAME="$(basename "$HOST_PROJECT_PATH")"
export HOST_PROJECT_FOLDER_NAME

if [ ! -d "$GDC_DIR/tmp" ]; then
  mkdir "$GDC_DIR/tmp"
fi
rm -rf "$GDC_DIR/tmp/$HOST_PROJECT_FOLDER_NAME-*"
cp "$GDC_DIR/noop" "$GDC_DIR/tmp/$HOST_PROJECT_FOLDER_NAME-noop"

path1=$GDC_DIR
path2=$HOST_PROJECT_PATH

# Find the common prefix of the two paths
prefix=""
for (( i=0; i<${#path1}; i++ )); do
  if [ "${path1:$i:1}" != "${path2:$i:1}" ]; then
    break
  fi
  prefix="$prefix${path1:$i:1}"
done
prefix=${prefix%/}

# Compute the relative path from path1 to path2
rel_path=""
if [ "$prefix" == "/" ]; then
  prefix=""
fi
if [ "${path1#$prefix/}" != "$path1" ]; then
  up_dirs=$(echo "${path1#$prefix/}" | tr '/' '\n' | wc -l)
  up_dirs=$(printf "../%.0s" $(seq 1 $((up_dirs))))
  rel_path="$up_dirs${path2#$prefix/}"
else
  rel_path="$path2"
fi
export HOST_PROJECT_REL_PATH=$rel_path
echo "Project path relative to GDC $HOST_PROJECT_REL_PATH"
unset path1 path2 prefix up_dirs rel_path

if [ -r "./.env-gdc" ]; then
  echo "Loading project .env-gdc environment file"
  source ./.env-gdc
fi
if [ -r "./.env-gdc-local" ]; then
  echo "Loading project .env-gdc-local environment file"
  source ./.env-gdc-local
fi

if [[ "$USE_HOME_BIN" = "yes" || "$USE_AWS_HOME" = "yes" ]]; then
  USE_HOST_HOME=yes
fi

export USE_HOST_HOME=${USE_HOST_HOME:=yes} # mount home directory from host

if [ -n "$LS_VERSION" ]; then # if we use localstack, we should install aws cli
  export USE_LOCALSTACK=yes
  export USE_AWS=${USE_AWS:=yes} # install latest aws cli, ssm plugin, and ecr helper
else
  export USE_AWS=${USE_AWS:=no} # install latest aws cli, ssm plugin, and ecr helper
fi

if [ "$USE_AWS" = "yes" ]; then
  if [ -z ${AWS_VERSION+x} ]; then
    export AWS_VERSION=latest # install latest version of aws cli
  fi
fi

export USE_CDK=${USE_CDK:=$USE_AWS}  # install latest aws cdk, terraform and cdk for terraform. requires node install

# if bitwarden is enabled, ensure node is also enabled
if [[ "$USE_BITWARDEN" = "yes" && -z "$NODE_VERSION" ]]; then
  export NODE_VERSION=20 # install this version of node.
fi

# if cdk is enabled, ensure node is also enabled
if [[ "$USE_CDK" = "yes" && -z "$NODE_VERSION" ]]; then
  export NODE_VERSION=20 # install this version of node.
fi

if [[ -z ${PYTHON_VERSION+x} ]]; then
  export PYTHON_VERSION=3.11 # latest aws lambda supported runtime
fi

export USE_PRECOMMIT=${USE_PRECOMMIT:=no} # use pre-commit hooks in git to format and lint files
# pre-commit requires python and will enable it if needed
if [[ -z ${PYTHON_VERSION+x} && "$USE_PRECOMMIT" = "yes" ]]; then
  export PYTHON_VERSION=3.11 # install this python version
fi

if [ -n "$LOCALSTACK_API_KEY" ] || [ -n "$LOCALSTACK_AUTH_TOKEN" ]; then
  export LS_IMAGE=${LS_IMAGE:="localstack/localstack-pro"} # use pro image if API key is provided
else
  export LS_IMAGE=${LS_IMAGE:="localstack/localstack"} # can override with custom image location. Still uses LS_VERSION to create final image location.
fi

if [[ "$AWS_VERSION" = "latest" ]]; then
  # latest version
  export AWS_VERSION=$(curl -s https://raw.githubusercontent.com/aws/aws-cli/v2/awscli/__init__.py | grep __version__ | cut -f3 -d' ' | tr -d "'")
  if [[ -z "$AWS_VERSION" ]]; then # if failed to fetch use known good version
    export AWS_VERSION=2.15.36
  fi
fi

if [[ "$GOLANG_VERSION" = "latest" ]]; then
  export GOLANG_VERSION=$(curl -s https://go.dev/VERSION?m=text | head -n 1 | tr -d 'go')
  if [[ -z "$GOLANG_VERSION" ]]; then
    export GOLANG_VERSION='1.22.2' # install this golang version as fallback if latest fails
  fi
fi

if [ -n "$PYTHON_VERSION" ]; then
  if [ -n "$PIP_EXTRA_REQUIREMENTS_TXT" ]; then
    export PIP_EXTRA_REQUIREMENTS_TXT
    cp "$HOST_PROJECT_PATH/$PIP_EXTRA_REQUIREMENTS_TXT" "$GDC_DIR/tmp/$HOST_PROJECT_FOLDER_NAME-pip-extra-requirements.txt" || exit 1
  fi
fi

# Function to convert a string to a number in the range 10-200
convert_string_to_number() {
    local input_string=$1

    # Compute a simple hash of the string
    local hash_value=$(echo -n "$input_string" | md5sum | cut -d' ' -f1 | tr -cd '0-9' | cut -c 1-5)

    # Ensure the hash value is treated as base-10
    local numeric_value=$((10#$hash_value))

    # Scale the hash value to the range 10-200
    local scaled_value=$((10 + numeric_value % 191))

    echo $scaled_value
}

if [ "$USE_LOCALSTACK_DNS" = "yes" ]; then
  if [[ -n "$DEVNET_SUBNET" && -z "$LOCALSTACK_STATIC_IP" ]]; then
    echo "ERROR: When USE_LOCALSTACK_DNS=yes and DEVNET_SUBNET is specified, you must also specify LOCALSTACK_STATIC_IP"
    exit 1
  fi
  if [[ -z "$DEVNET_SUBNET" && -z "$LOCALSTACK_STATIC_IP" ]]; then
    D=$(date)
    OCTET=$(convert_string_to_number "$CI_JOB_TOKEN,$D")
    export DEVNET_SUBNET="172.$OCTET.0.0/16"
    export LOCALSTACK_STATIC_IP="172.$OCTET.0.10"
  fi
  export GDC_DNS_PRI_IP="$LOCALSTACK_STATIC_IP"
fi

export DEVNET_SUBNET
export LOCALSTACK_STATIC_IP


CACHE_VOLUMES_REQUIRED="pulumi pkg_cache terraform"
SHARED_VOLUMES_REQUIRED="shared home_config"

SHARED_VOLUMES="$SHARED_VOLUMES_REQUIRED $CACHE_VOLUMES_REQUIRED"
if [ -n "$SHARED_VOLUMES_EXTRA" ]; then
  SHARED_VOLUMES="$SHARED_VOLUMES $SHARED_VOLUMES_EXTRA"
fi
export SHARED_VOLUMES

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  echo "usage: $0 STACK_NAME [GDC_RUN_MODE | PORT_FWD | GDC_ENTRYPOINT]..."
  echo "current working directory will be mounted in container on /workspace."
  echo "Env vars are set in the following order with last to set winning"
  echo "Shell env, $SCRIPT_DIR/.env-gdc, $SCRIPT_DIR/.env-gdc-local"
  if [ "$USE_WORKSPACE" = "yes" ]; then
    echo "$HOST_PROJECT_PATH/.env-gdc, $HOST_PROJECT_PATH/.env-gdc-local"
  fi
  echo "STACK_NAME required, is used to name the stack in case you want to run more than one."
  echo "GDC_RUN_MODE optional, valid values are start, stop, daemon, clean. start is the default."
  echo "  start will start the GDC environment."
  echo "  daemon will start a GDC environment in the background."
  echo "  stop will shutdown a running GDC environment running in foreground or background."
  echo "  clean start GDC environment with CLEAN=yes flag."
  echo "PORT_FWD optional, is in compose port forward format. Example 80:8080 or 4000-4005. You can specify this param more than once."
  echo "GDC_ENTRYPOINT optional, runs a command in the GDC. Should be last parameter."
  echo "  the docker compose exit code will mirror the return code of the entrypoint command."
  echo "  if the entrypoint command returns a non-zero exit code even if GDC_RUN_MODE=daemon then compose will exit."
  echo "Full example: $0 webdev 80:8080 start"
  exit 0
fi

run_modes=("start" "stop" "daemon" "clean")


# if we cant change to this folder bail
cd "$SCRIPT_DIR" || exit 1

variable="$1"

if [[ ! " ${run_modes[*]} " =~ " ${variable} " ]]; then
  if [[ ! "$variable" =~ ^[0-9]+[:-][0-9]+ ]]; then
    if [ -n "$1" ]; then
      GDC_NAME="$1"
      shift
    fi
  fi
fi
unset variable

if [[ -z "$GDC_NAME" ]]; then
  # start with folder name
  string="$HOST_PROJECT_FOLDER_NAME"
  # if folder name is less than 12 chars, then use it
  if [ "${#string}" -lt 12 ]; then
    new_string="$string"
  else
    # Replace all hyphens and underscores with spaces
    temp_string="${string//[-_]/ }"
    # Loop through each word in the string, and take lowercase first letter of each word
    new_string=""
    for word in $temp_string; do
        new_string="$new_string$(echo "$word" | awk '{print tolower(substr($0,1,1))}') "
    done
    # Remove any whitespace from the new string
    new_string="${new_string// /}"
    # if new string is less than 3 chars, fall back to folder name
    if [ "${#new_string}" -lt 3 ]; then
      new_string="$HOST_PROJECT_FOLDER_NAME"
    fi
  fi
  GDC_NAME="$new_string"
fi
if [[ -z "$GDC_NAME" ]]; then
  echo "GDC_NAME environment variable not set and no name argument specified."
  exit 1
fi

COMPOSE_FILES="-f docker-compose.yml"

if [ -n "$GDC_DNS_PRI_IP" ]; then
  echo "Adding compose layer dc-dns.yml"
  COMPOSE_FILES="$COMPOSE_FILES -f dc-dns.yml"
fi

# this is the stack name for compose
COMPOSE_PROJECT_NAME="$GDC_NAME"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME//[ -]/_}"

export LS_MAIN_CONTAINER_NAME=${LS_MAIN_CONTAINER_NAME:="localstack_$COMPOSE_PROJECT_NAME"} # used by localstack to name main container
if [ "$USE_LOCALSTACK_HOST" = "yes" ]; then
  export LOCALSTACK_HOST=${LOCALSTACK_HOST:=host.docker.internal:4566}
else
  export LOCALSTACK_HOST=${LOCALSTACK_HOST:=$LS_MAIN_CONTAINER_NAME:4566}
fi
export LOCALSTACK_HOSTNAME=$(echo "$LOCALSTACK_HOST" | cut -d: -f1)

export DEVNET_NAME=${DEVNET_NAME:="devnet_$COMPOSE_PROJECT_NAME"}
if [ -z "$DEVNET_NAME" ]; then
  echo "Env variable DEVNET_NAME is not set !"
  exit 1
fi

# setup docker devnet network if needed
if [ -z "$(docker network ls --format '{{.Name}}' --filter name="$DEVNET_NAME")" ]; then
  if [ -n "$DEVNET_SUBNET" ]; then
    DEVNET_SUBNET="--subnet $DEVNET_SUBNET"
  else
    DEVNET_SUBNET=""
  fi
  if [ -n "$DEVNET_GATEWAY" ]; then
    DEVNET_GATEWAY="--gateway $DEVNET_GATEWAY"
  else
    DEVNET_GATEWAY=""
  fi
  echo "Network $DEVNET_NAME not found. creating... $DEVNET_SUBNET $DEVNET_GATEWAY"
  docker network create --attachable -d bridge $DEVNET_SUBNET $DEVNET_GATEWAY "$DEVNET_NAME"
else
  echo "Network $DEVNET_NAME found"
fi


CUSTOM_PORTS=""
for i in $(seq 0 9); do
  v="PORT_FWD$i"
  a="${!v}"
  if [ -n "$a" ]; then
    if [[ "$a" =~ ^[0-9]+[:-][0-9]+ ]]; then
      if [ -z "$CUSTOM_PORTS" ]; then
        CUSTOM_PORTS="$a"
      else
        CUSTOM_PORTS="$CUSTOM_PORTS $a"
      fi
    else
      echo "Bad port forward syntax for $v=$a"
      exit 1
    fi
  fi # end port forward var not empty
done # end for 0-9

for a; do
  if [[ "$a" =~ ^[0-9]+[:-][0-9]+ ]]; then # matches custom port forward syntax
    if [ -z "$CUSTOM_PORTS" ]; then
      CUSTOM_PORTS="$a"
    else
      CUSTOM_PORTS="$CUSTOM_PORTS $a"
    fi
  elif [[ "$a" =~ ^start|stop|daemon|clean ]]; then # matches daemon run mode
    GDC_RUN_MODE="$a"
  elif [ -n "$a" ]; then # anything else is considered a custom entry point command
    GDC_ENTRYPOINT="$a"
  fi
done # for all parameters

CUSTOM_PORT_FILE="./tmp/custom_ports_$COMPOSE_PROJECT_NAME.yml"
if [ -r "$CUSTOM_PORT_FILE" ]; then
  rm -rf "$CUSTOM_PORT_FILE"
fi
if [ -n "$CUSTOM_PORTS" ]; then
  cat << EOF > "$CUSTOM_PORT_FILE"
version: "3.8"

services:
  dev:
    ports:
EOF

  for i in $CUSTOM_PORTS; do
    cat << EOF >> "$CUSTOM_PORT_FILE"
      - "$i"
EOF
  done
  echo "" >> "$CUSTOM_PORT_FILE"
  COMPOSE_FILES="$COMPOSE_FILES -f $CUSTOM_PORT_FILE"
  echo "CUSTOM_PORTS=$CUSTOM_PORTS"
fi

CUSTOM_ENVS=""
oIFS="$IFS"
IFS=$'\n'
for ENV in $(env); do
  if [[ "$ENV" =~ ^GDC_ENV_ ]]; then
    ENV=${ENV#GDC_ENV_}
    if [ -z "$CUSTOM_ENVS" ]; then
      CUSTOM_ENVS="$ENV"
    else
      CUSTOM_ENVS="$CUSTOM_ENVS"$'\n'"$ENV"
    fi
  fi
done

CUSTOM_ENV_FILE="./tmp/custom_env_$COMPOSE_PROJECT_NAME.yml"
if [ -r "$CUSTOM_ENV_FILE" ]; then
  rm -rf "$CUSTOM_ENV_FILE"
fi
if [ -n "$CUSTOM_ENVS" ]; then
  cat << EOF > "$CUSTOM_ENV_FILE"
version: "3.8"

services:
  dev:
    environment:
EOF

  for i in $CUSTOM_ENVS; do
    cat << EOF >> "$CUSTOM_ENV_FILE"
      - $i
EOF
  done

  echo "" >> "$CUSTOM_ENV_FILE"
  COMPOSE_FILES="$COMPOSE_FILES -f $CUSTOM_ENV_FILE"
  echo "CUSTOM_ENVS=$CUSTOM_ENVS"
fi
IFS="$oIFS"
unset oIFS

#echo "GDC_ENTRYPOINT=$GDC_ENTRYPOINT"
#exit
export HOST_HOME="$HOME"
export HOST_PROJECT_PATH
export COMPOSE_PROJECT_NAME
export CUSTOM_PORTS
export GDC_ENTRYPOINT
export DEVNET_NAME

if [ "$USE_WORKSPACE" = "yes" ]; then
  echo "HOST_PROJECT_PATH = $HOST_PROJECT_PATH"
fi
echo "COMPOSE_PROJECT_NAME = $COMPOSE_PROJECT_NAME"

if [ -z "$USE_HOST_HOME" ]; then
  echo "Env variable USE_HOST_HOME is not set !"
  exit 1
fi

# enable mounting of current folder to /workspace in container
if [ "$USE_WORKSPACE" = "yes" ]; then
  echo "Adding compose layer workspace mount dc-host-workspace-dir.yml"
  COMPOSE_FILES="$COMPOSE_FILES -f dc-host-workspace-dir.yml"
fi

# enable mounting and copying data from host users home dir
if [ "$USE_HOST_HOME" = "yes" ]; then
  echo "Adding compose layer dc-host-home-dir.yml"
  COMPOSE_FILES="$COMPOSE_FILES -f dc-host-home-dir.yml"
fi

# this will forward port and start ssh server
if [ -n "$SSH_SERVER_PORT" ]; then
  echo "Adding compose layer dc-ssh.yml"
  COMPOSE_FILES="$COMPOSE_FILES -f dc-ssh.yml"
fi

# this will start localstack container
if [ -n "$LS_VERSION" ]; then
  if [ "$LS_VERSION" = "latest" ]; then
    docker pull "$LS_IMAGE"
  fi
  export USE_LOCALSTACK=yes
  echo "Adding compose layer dc-ls.yml"
  COMPOSE_FILES="$COMPOSE_FILES -f dc-ls.yml"

  if [ "$USE_LOCALSTACK_PRO" = "yes" ]; then
    echo "Adding compose layer dc-ls-pro.yml"
    COMPOSE_FILES="$COMPOSE_FILES -f dc-ls-pro.yml"
  fi

  if [ -n "$LOCALSTACK_STATIC_IP" ]; then
    COMPOSE_FILES="$COMPOSE_FILES -f dc-ls-static-ip.yml"
  fi
  if [ "$USE_LOCALSTACK_HOST" = "yes" ]; then
    echo "Adding compose layer dc-ls-host.yml"
    COMPOSE_FILES="$COMPOSE_FILES -f dc-ls-host.yml"
    if [ -n "$LOCALSTACK_HOST_DNS_PORT" ]; then
      COMPOSE_FILES="$COMPOSE_FILES -f dc-ls-host-dns.yml"
    fi
  fi
  if [ "$USE_LOCALSTACK_PERSISTENCE" = "yes" ]; then
    COMPOSE_FILES="$COMPOSE_FILES -f dc-ls-persist.yml"
  fi
  if [ "$USE_LOCALSTACK_SHARED" = "yes" ]; then
    COMPOSE_FILES="$COMPOSE_FILES -f dc-ls-shared.yml"
  fi
fi

# mount host ls volume dir in container
if [ "$USE_LOCALSTACK" = "yes" ]; then
  export LOCALSTACK_VOLUME_DIR="$HOST_PROJECT_PATH/ls_volume"
  echo "LOCALSTACK_VOLUME_DIR = $LOCALSTACK_VOLUME_DIR"
  if [ ! -r "$LOCALSTACK_VOLUME_DIR" ]; then
    mkdir -p "$LOCALSTACK_VOLUME_DIR"
  fi
fi

if [ "$USE_AUTH0_HOST" = "yes" ] || [ "$USE_AUTH0" = "yes" ]; then
  export AUTH0_CONTAINER_NAME=${AUTH0_CONTAINER_NAME:="auth0_mock_$COMPOSE_PROJECT_NAME"} # set name of auth0 container so more than one can be used in parallel
  # add custom auth0 users file
  if [ -n "$AUTH0_LOCAL_USERS_FILE" ]; then
    echo "Adding compose layer dc-auth0-local-users.yml"
    COMPOSE_FILES="$COMPOSE_FILES -f dc-auth0-local-users.yml"
  fi
fi

# this will start auth0 mock server with host port forward
if [ "$USE_AUTH0_HOST" = "yes" ]; then
  echo "Adding compose layer dc-auth0-host.yml"
  COMPOSE_FILES="$COMPOSE_FILES -f dc-auth0-host.yml"
  export AUTH0_DOMAIN="http://host.docker.internal:$AUTH0_HOST_PORT"
# this will start auth0 mock server in container only
elif [ "$USE_AUTH0" = "yes" ]; then
  echo "Adding compose layer dc-auth0.yml"
  COMPOSE_FILES="$COMPOSE_FILES -f dc-auth0.yml"
  export AUTH0_DOMAIN="http://$AUTH0_CONTAINER_NAME:3001"
fi


# this will start mitm proxy server
if [[ -n "$USE_PROXY" && "$USE_PROXY" != "no" ]]; then
  if [ -z "$PROXY_VOLUME_DIR" ]; then
    PROXY_VOLUME_DIR="$HOST_PROJECT_PATH/proxy_volume"
  fi
  export PROXY_VOLUME_DIR
  echo "Adding compose layer dc-proxy.yml"
  COMPOSE_FILES="$COMPOSE_FILES -f dc-proxy.yml"

  if [[ -n "$USE_PROXY_HOST" && "$USE_PROXY_HOST" != "no" ]]; then
    echo "Adding compose layer dc-proxy-host.yml"
    COMPOSE_FILES="$COMPOSE_FILES -f dc-proxy-host.yml"
    if [[ "$USE_PROXY" = "web" ]]; then
      echo "Adding compose layer dc-proxy-web-host.yml"
      COMPOSE_FILES="$COMPOSE_FILES -f dc-proxy-web-host.yml"
    fi
  else
    if [[ "$USE_PROXY" = "web" ]]; then
      echo "Adding compose layer dc-proxy-web.yml"
      COMPOSE_FILES="$COMPOSE_FILES -f dc-proxy-web.yml"
    fi
  fi
  if [[ "$USE_PROXY" = "dump" ]]; then
    echo "Adding compose layer dc-proxy-dump.yml"
    COMPOSE_FILES="$COMPOSE_FILES -f dc-proxy-dump.yml"
  fi
  export PROXY_URL=http://$PROXY_CONTAINER_NAME:8080
  export PROXY_URL_SSL=https://$PROXY_CONTAINER_NAME:8080
fi

# forwards ssh agent socket to container
if [[ -z "$NO_SSH_AGENT" && -r "$SSH_AUTH_SOCK" ]]; then
  if [[ $OSTYPE =~ darwin* && -r "$SSH_AUTH_SOCK" ]]; then # MAC
    echo "Adding compose layer dc-ssh-agent.yml"
    echo "forwarding mac ssh agent to container"
    export SSH_AUTH_SOCK=/run/host-services/ssh-auth.sock
    COMPOSE_FILES="$COMPOSE_FILES -f dc-ssh-agent.yml"
  elif [[ $OSTYPE =~ msys* ]]; then # GIT BASH
    echo "not forwarding windows ssh agent to container. not ready"
    #        export SSH_AUTH_SOCK=//./pipe/openssh-ssh-agent
    #        COMPOSE_FILES="$COMPOSE_FILES -f dc-ssh-agent.yml"
  fi
fi

if [ ! -r ./custom-yml.d ]; then
  mkdir ./custom-yml.d
fi
if [ -n "$(ls -A ./custom-yml.d)" ]; then
  for filename in ./custom-yml.d/*.yml; do
    echo "Adding custom compose layer from $filename"
    COMPOSE_FILES="$COMPOSE_FILES -f $filename"
  done
fi

# add user specified compose file to list
if [ -n "$COMPOSE_EX" ]; then
  echo "Adding custom compose layer $COMPOSE_EX"

  if [[ "${COMPOSE_EX:0:1}" == "/" ]] ; then
    echo "Absolute path detected. Converting to relative..."
    path1=$GDC_DIR
    path2=$(dirname "$COMPOSE_EX")

    # Find the common prefix of the two paths
    prefix=""
    for (( i=0; i<${#path1}; i++ )); do
      if [ "${path1:$i:1}" != "${path2:$i:1}" ]; then
        break
      fi
      prefix="$prefix${path1:$i:1}"
    done
    prefix=${prefix%/}

    # Compute the relative path from path1 to path2
    rel_path=""
    if [ "$prefix" == "/" ]; then
      prefix=""
    fi
    if [ "${path1#$prefix/}" != "$path1" ]; then
      up_dirs=$(echo "${path1#$prefix/}" | tr '/' '\n' | wc -l)
      up_dirs=$(printf "../%.0s" $(seq 1 $((up_dirs))))
      rel_path="$up_dirs${path2#$prefix/}"
    else
      rel_path="$path2"
    fi
    echo "Custom compose layer $COMPOSE_EX relative path computed as $rel_path/$(basename "$COMPOSE_EX")"
    COMPOSE_EX=$rel_path/$(basename "$COMPOSE_EX")
    unset path1 path2 prefix up_dirs rel_path
  fi
  COMPOSE_FILES="$COMPOSE_FILES -f $COMPOSE_EX"
fi

if [ -n "$HOST_CUSTOM_MOUNT" ]; then
  COMPOSE_FILES="$COMPOSE_FILES -f dc-host-custom-mount.yml"
fi
export HOST_CUSTOM_MOUNT

if [ "$GDC_RUN_MODE" = "clean" ]; then
  CLEAN_ONLY="yes"
fi
# remove old stack and prune image files
if [ "$CLEAN" = "yes" ] || [ "$CLEAN_ONLY" = "yes" ]; then
  $COMPOSE_BIN $COMPOSE_FILES down --rmi all
  docker network rm "$DEVNET_NAME" 2> /dev/null

  for v in $SHARED_VOLUMES_EXTRA; do
    if [ "$(docker volume ls | grep -Ec "local\s+$v\$")" = "1" ]; then
      echo "Attempting to remove shared extra volume $v. This may fail if other containers are using it."
      docker volume rm "$v"
    fi
  done
  for v in $CACHE_VOLUMES_REQUIRED; do
    if [ "$(docker volume ls | grep -Ec "local\s+$v\$")" = "1" ]; then
      echo "Attempting to remove shared cache volume $v. This may fail if other containers are using it."
      docker volume rm "$v"
    fi
  done

  docker system prune -f
  if [ "$CLEAN_ONLY" = "yes" ]; then
    exit
  fi
fi

if [ "$PULUMI_VERSION" = "latest" ]; then
  if ! PULUMI_VERSION=$(curl --retry 3 --fail --silent -L "https://www.pulumi.com/latest-version"); then
    echo "error: could not determine latest version of Pulumi, try specifying version X.Y.Z to install an explicit version"
    exit 1
  fi
  echo "Latest pulumi version is $PULUMI_VERSION"
fi


for v in $SHARED_VOLUMES; do
  if [ "$(docker volume ls | grep -Ec "local\s+$v\$")" = "0" ]; then
    echo "Creating shared volume $v"
    docker volume create "$v"
  fi
done

export GDC_COMPOSE_FILES=$COMPOSE_FILES

GDC_DAEMON_MODE=""
if [ "$GDC_RUN_MODE" = "daemon" ]; then
  GDC_DAEMON_MODE="-d "
  export COPY_CMD_TO_CLIPBOARD="no"
fi

echo "COMPOSE_PROJECT_NAME=$COMPOSE_PROJECT_NAME"
echo "GDC_RUN_MODE=$GDC_RUN_MODE"
echo "CUSTOM_PORTS=$CUSTOM_PORTS"
echo "GDC_COMPOSE_FILES=$GDC_COMPOSE_FILES"
echo "SHARED_VOLUMES=$SHARED_VOLUMES"
echo "GDC_ENTRYPOINT=$GDC_ENTRYPOINT"
echo "COPY_CMD_TO_CLIPBOARD=$COPY_CMD_TO_CLIPBOARD"
if [ -n "$LOCALSTACK_STATIC_IP" ]; then
  echo "LOCALSTACK_STATIC_IP=$LOCALSTACK_STATIC_IP"
fi
#exit ########### DEBUG #############

if [ "$GDC_RUN_MODE" = "stop" ]; then
  $COMPOSE_BIN $COMPOSE_FILES down
  if [ "$NO_DEVNET_RM" != "yes" ]; then
    docker network rm "$DEVNET_NAME" 2> /dev/null
  fi
  exit
else
  GDC_RUN_MODE="start"
fi
export GDC_CONTAINER_NAME=$COMPOSE_PROJECT_NAME"-$DEV_CONTAINER_NAME"
export GDC_ENTRYPOINT
export CI_JOB_TOKEN
export CI_PROJECT_DIR
export NO_DEVNET_RM

if [ `docker ps --format "{{.Names}}" | grep -c "$GDC_CONTAINER_NAME" | tr -d '\n'''` != "0" ]; then
  echo "$GDC_CONTAINER_NAME already running. Exiting..."
  exit 1
fi

OS="$(uname -s)"
if [[ "$OS" =~ ^MINGW64 ]]; then
  CLIP_CMD=clip.exe
elif [ "$OS" = "Linux" ]; then
  CLIP_CMD=xclip
elif [ "$OS" = "Darwin" ]; then
  CLIP_CMD=pbcopy
else
  CLIP_CMD=""
fi

CLIPBOARD_MSG=""
if [[ "$COPY_CMD_TO_CLIPBOARD" = "yes"  &&  -n "$CLIP_CMD" ]]; then
  if echo "docker exec -it $GDC_CONTAINER_NAME bash -l" | $CLIP_CMD > /dev/null 2>&1;  then
    CLIPBOARD_MSG="Command copied to clipboard."
  fi
fi
export CLIPBOARD_MSG
if [ "$GDC_RUN_MODE" = "daemon" ]; then
  $COMPOSE_BIN $COMPOSE_FILES up $GDC_DAEMON_MODE --build --force-recreate &>/dev/null
  RC=$? # capture the compose exit code so we can emit it after any cleanup
else
  $COMPOSE_BIN $COMPOSE_FILES up $GDC_DAEMON_MODE --build --force-recreate
  RC=$? # capture the compose exit code so we can emit it after any cleanup
fi


if [ "$GDC_RUN_MODE" != "daemon" ]; then
  if [ "$NO_DEVNET_RM" != "yes" ]; then
    docker network rm "$DEVNET_NAME" 2> /dev/null
  fi
fi
echo "Compose exit code: $RC"
exit $RC
