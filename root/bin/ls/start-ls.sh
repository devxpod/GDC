#!/usr/bin/env bash
# make sure windows git bash does not alter paths
export MSYS_NO_PATHCONV=1

cd /root/gdc-host || exit 1

if [ -r ".env-gdc" ]; then
  echo "Loading container .env-gdc environment file"
  source ".env-gdc"
fi

if [ -r ".env-gdc-local" ]; then
  echo "Loading container .env-gdc-local environment file"
  source ".env-gdc-local"
fi

if [ -r "/workspace/.env-gdc" ]; then
  echo "Loading project .env-gdc environment file"
  source "/workspace/.env-gdc"
fi
if [ -r "/workspace/.env-gdc-local" ]; then
  echo "Loading project .env-gdc-local environment file"
  source "/workspace/.env-gdc-local"
fi

export LS_VERSION=${LS_VERSION:='latest'}

IS_HOST=$(echo "$GDC_COMPOSE_FILES" | grep -sc '\-f dc-ls-host.yml')
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage $0 [host|internal]"
  echo "if no parameters are passed, then GDC launch env variables are used to automatically determine mode."
  exit 0
elif [ "$1" = "host" ]; then
  IS_HOST="1"
elif [ "$1" = "internal" ]; then
  IS_HOST="0"
fi

COMPOSE_FILES="-f dc-ls.yml"
if [ "$IS_HOST" = "1" ]; then
  echo "start-ls.sh using host mode"
  COMPOSE_FILES="$COMPOSE_FILES -f dc-ls-host.yml"
fi
if [ -n "$LOCALSTACK_STATIC_IP" ]; then
    COMPOSE_FILES="$COMPOSE_FILES -f dc-ls-static-ip.yml"
fi
if [ -n "$LOCALSTACK_HOST_DNS_PORT" ]; then
  COMPOSE_FILES="$COMPOSE_FILES -f dc-ls-host-dns.yml"
fi
if [ "$USE_LOCALSTACK_PERSISTENCE" = "yes" ]; then
  COMPOSE_FILES="$COMPOSE_FILES -f dc-ls-persist.yml"
fi

if [ -z "$COMPOSE_BIN" ]; then
  COMPOSE_BIN="docker compose"
fi

$COMPOSE_BIN $COMPOSE_FILES up -d --build --force-recreate

sleep 5
