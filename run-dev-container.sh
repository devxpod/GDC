#!/usr/bin/env bash

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

if [ -r "./.env-gdc" ]; then
  echo "Loading project .env-gdc environment file"
  source ./.env-gdc
fi
if [ -r "./.env-gdc-local" ]; then
  echo "Loading project .env-gdc-local environment file"
  source ./.env-gdc-local
fi
CACHE_VOLUMES_REQUIRED="pulumi pkg_cache"
SHARED_VOLUMES_REQUIRED="shared home_config"

SHARED_VOLUMES="$SHARED_VOLUMES_REQUIRED $CACHE_VOLUMES_REQUIRED"
if [ -n "$SHARED_VOLUMES_EXTRA" ]; then
  SHARED_VOLUMES="$SHARED_VOLUMES $SHARED_VOLUMES_EXTRA"
fi
export SHARED_VOLUMES
# if we cant change to this folder bail
cd "$SCRIPT_DIR" || exit 1

if [[ -z "$1" || "$1" == "-h" || "$1" == "--help" ]]; then
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
  echo "GDC_ENTRYPOINT optional, runs a command in the GDC."
  echo "  the docker compose exit code will mirror the return code of the entrypoint command."
  echo "  if the entrypoint command returns a non-zero exit code even if GDC_RUN_MODE=daemon then compose will exit."
  echo "Full example: $0 webdev 80:8080 start"
  exit 0
fi

COMPOSE_FILES="-f docker-compose.yml"

if [ ! -d "./tmp" ]; then
  mkdir ./tmp
fi

# this is the stack name for compose
COMPOSE_PROJECT_NAME="$1"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME// /_}"
shift

export LS_MAIN_CONTAINER_NAME=${LS_MAIN_CONTAINER_NAME:="localstack_$COMPOSE_PROJECT_NAME"} # used by localstack to name main container
if [ "$USE_LOCALSTACK_HOST" = "yes" ]; then
  export HOSTNAME_EXTERNAL=${HOSTNAME_EXTERNAL:=host.docker.internal}
else
  export HOSTNAME_EXTERNAL=${HOSTNAME_EXTERNAL:=$LS_MAIN_CONTAINER_NAME}
fi

export DEVNET_NAME=${DEVNET_NAME:="devnet_$COMPOSE_PROJECT_NAME"}
if [ -z "$DEVNET_NAME" ]; then
  echo "Env variable DEVNET_NAME is not set !"
  exit 1
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
  else # anything else is considered a custom entry point command
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
      CUSTOM_ENVS="$CUSTOM_ENVS\n$ENV"
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

#echo "GDC_RUN_MODE=$GDC_RUN_MODE"
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
  echo "Adding compose layer workspace mount  dc-host-workspace-dir.yml"
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
  export USE_LOCALSTACK=yes
  if [ "$USE_LOCALSTACK_HOST" = "yes" ]; then
    echo "Adding compose layer dc-ls-host.yml"
    COMPOSE_FILES="$COMPOSE_FILES -f dc-ls-host.yml"
    if [ -n "$LOCALSTACK_HOST_DNS_PORT" ]; then
      COMPOSE_FILES="$COMPOSE_FILES -f dc-ls-host-dns.yml"
    fi
  else
    echo "Adding compose layer dc-ls.yml"
    COMPOSE_FILES="$COMPOSE_FILES -f dc-ls.yml"
  fi
  if [ "$USE_LOCALSTACK_PERSISTENCE" = "yes" ]; then
    COMPOSE_FILES="$COMPOSE_FILES -f dc-ls-persist.yml"
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
  docker-compose $COMPOSE_FILES down --rmi all
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

for v in $SHARED_VOLUMES; do
  if [ "$(docker volume ls | grep -Ec "local\s+$v\$")" = "0" ]; then
    echo "Creating shared volume $v"
    docker volume create "$v"
  fi
done

export GDC_COMPOSE_FILES=$COMPOSE_FILES
echo "GDC_COMPOSE_FILES $GDC_COMPOSE_FILES"
echo "SHARED_VOLUMES $SHARED_VOLUMES"
echo "GDC_ENTRYPOINT=$GDC_ENTRYPOINT"

GDC_DAEMON_MODE=""
if [ "$GDC_RUN_MODE" = "daemon" ]; then
  GDC_DAEMON_MODE="-d "
fi

if [ "$GDC_RUN_MODE" = "stop" ]; then
  docker-compose $COMPOSE_FILES down
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
#echo "--------------- OS = $OS ---------------"
if [ -n "$CLIP_CMD" ]; then
  #echo "CLIP_CMD=$CLIP_CMD"
  echo "docker exec -it $GDC_CONTAINER_NAME bash -l" | $CLIP_CMD > /dev/null 2>&1
fi

docker-compose $COMPOSE_FILES up $GDC_DAEMON_MODE --build --force-recreate
RC=$? # capture the compose exit code so we can emit it after any cleanup

if [ "$GDC_RUN_MODE" != "daemon" ]; then
  if [ "$NO_DEVNET_RM" != "yes" ]; then
    docker network rm "$DEVNET_NAME" 2> /dev/null
  fi
fi
echo "Compose exit code: $RC"
exit $RC
