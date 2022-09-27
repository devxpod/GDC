#!/usr/bin/env bash
# make sure windows git bash does not alter paths
export MSYS_NO_PATHCONV=1
# gets folder where this script actually lives, resolving symlinks if needed
# this folder is the docker root for building the container
SCRIPT_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]:-$0}")")" &> /dev/null && pwd 2> /dev/null)"

export GDC_DIR=$SCRIPT_DIR

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

if [ -r ".env-gdc" ]; then
  echo "Loading project .env-gdc environment file"
  source ".env-gdc"
fi
if [ -r ".env-gdc-local" ]; then
  echo "Loading project .env-gdc-local environment file"
  source ".env-gdc-local"
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
  echo "usage: $0 STACK_NAME [PORT_FWD1] [PORT_FWD2]"
  echo "current folder will be mounted in container on /workspace."
  echo "Env vars are set in the following order with last to set winning"
  echo "Shell env, $SCRIPT_DIR/.env-gdc, $SCRIPT_DIR/.env-gdc-local"
  if [ "$USE_WORKSPACE" = "yes" ]; then
    echo "$HOST_PROJECT_PATH/.env-gdc, $HOST_PROJECT_PATH/.env-gdc-local"
  fi
  echo "STACK_NAME required, is used to name the stack in case you want to run more than one."
  echo "PORT_FWD1 optional, is in compose port forward format. Example 80:8080. If not provided will fall back to environment variable."
  echo "PORT_FWD2 optional, is in compose port forward format. Example 2000-2020. If not provided will fall back to environment variable."
  echo "Full example: $0 webdev 80:8080"
  exit 0
fi

# this is the stack name for compose
COMPOSE_PROJECT_NAME="$1"
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME// /_}"

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

if [ -n "$2" ]; then
  PORT_FWD1="$2"
fi

if [ -n "$3" ]; then
  PORT_FWD2="$3"
fi

export HOST_PROJECT_PATH
export COMPOSE_PROJECT_NAME
export PORT_FWD1
export PORT_FWD2
export DEVNET_NAME

if [ "$USE_WORKSPACE" = "yes" ]; then
  echo "HOST_PROJECT_PATH = $HOST_PROJECT_PATH"
fi
echo "COMPOSE_PROJECT_NAME = $COMPOSE_PROJECT_NAME"
if [ -n "$PORT_FWD1" ]; then
  echo "PORT_FWD1 = $PORT_FWD1"
fi
if [ -n "$PORT_FWD2" ]; then
  echo "PORT_FWD2 = $PORT_FWD2"
fi

if [ -z "$USE_HOST_HOME" ]; then
  echo "Env variable USE_HOST_HOME is not set !"
  exit 1
fi

COMPOSE_FILES="-f docker-compose.yml"

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
# forwards 1st set of ports
if [ -n "$PORT_FWD1" ]; then
  echo "Adding compose layer dc-port-fwd1.yml"
  COMPOSE_FILES="$COMPOSE_FILES -f dc-port-fwd1.yml"
fi
# forwards 2nd set of ports
if [ -n "$PORT_FWD2" ]; then
  echo "Adding compose layer dc-port-fwd2.yml"
  COMPOSE_FILES="$COMPOSE_FILES -f dc-port-fwd2.yml"
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
fi

# mount host ls volume dir in container
if [ "$USE_LOCALSTACK" = "yes" ]; then
  echo "Adding compose layer ls-volume.yml"
  if [ "$OS" = "Windows_NT" ]; then
    export LOCALSTACK_VOLUME_DIR="/c/tmp/ls_volume_$COMPOSE_PROJECT_NAME"
  else
    export LOCALSTACK_VOLUME_DIR="/tmp/ls_volume_$COMPOSE_PROJECT_NAME"
  fi
  echo "LOCALSTACK_VOLUME_DIR = $LOCALSTACK_VOLUME_DIR"
  if [ ! -r "$LOCALSTACK_VOLUME_DIR" ]; then
    mkdir -p "$LOCALSTACK_VOLUME_DIR"
  fi
  COMPOSE_FILES="$COMPOSE_FILES -f ls-volume.yml"
fi

# this will start auth0 mock server with host port forward
if [ "$USE_AUTH0_HOST" = "yes" ]; then
  echo "Adding compose layer dc-auth0-host.yml"
  COMPOSE_FILES="$COMPOSE_FILES -f dc-auth0-host.yml"
  export AUTH0_URL="http://host.docker.internal:$AUTH0_HOST_PORT"
# this will start auth0 mock server in container only
elif [ "$USE_AUTH0" = "yes" ]; then
  echo "Adding compose layer dc-auth0.yml"
  COMPOSE_FILES="$COMPOSE_FILES -f dc-auth0.yml"
  export AUTH0_URL="http://$AUTH0_CONTAINER_NAME:3001"
fi

if [ "$USE_AUTH0_HOST" = "yes" ] || [ "$USE_AUTH0" = "yes" ]; then
  export AUTH0_CONTAINER_NAME=${AUTH0_CONTAINER_NAME:="auth0_mock_$COMPOSE_PROJECT_NAME"} # set name of auth0 container so more than one can be used in parallel
  # add custom auth0 users file
  if [ -n "$AUTH0_LOCAL_USERS_FILE" ]; then
    echo "Adding compose layer dc-auth0-local-users.yml"
    COMPOSE_FILES="$COMPOSE_FILES -f dc-auth0-local-users.yml"
  fi
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

# add user specified compose file to list
if [ -n "$COMPOSE_EX" ]; then
  echo "Adding compose layer $COMPOSE_EX"
  COMPOSE_FILES="$COMPOSE_FILES -f $COMPOSE_EX"
fi

# remove old stack and prune image files
if [ "$CLEAN" = "yes" ] || [ "$CLEAN_ONLY" = "yes" ]; then
  docker-compose $COMPOSE_FILES down --rmi all
  docker network rm "$DEVNET_NAME"

  for v in $SHARED_VOLUMES_EXTRA; do
    if [ "$(docker volume ls | grep -Ec "local\s+$v\$")" = "1" ]; then
      echo "Removing shared extra volume $v"
      docker volume rm "$v"
    fi
  done
  for v in $CACHE_VOLUMES_REQUIRED; do
    if [ "$(docker volume ls | grep -Ec "local\s+$v\$")" = "1" ]; then
      echo "Removing shared cache volume $v"
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
echo "Using compose files $GDC_COMPOSE_FILES"
echo "Using shared volumes $SHARED_VOLUMES"

if [ "$GDC_DAEMON_MODE" = "start" ]; then
  GDC_DAEMON_MODE="-d "
elif [ "$GDC_DAEMON_MODE" = "stop" ]; then
  docker-compose $COMPOSE_FILES down
  docker network rm "$DEVNET_NAME" 2>/dev/null
  exit
else
  GDC_DAEMON_MODE=""
fi
export GDC_CONTAINER_NAME=$COMPOSE_PROJECT_NAME"-dev-1"
export GDC_ENTRYPOINT
docker-compose $COMPOSE_FILES up $GDC_DAEMON_MODE --build --force-recreate
if [ "$GDC_DAEMON_MODE" != "start" ]; then
  docker network rm "$DEVNET_NAME" 2>/dev/null
fi
