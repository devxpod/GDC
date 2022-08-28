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

IS_HOST=$(echo "$GDC_COMPOSE_FILES" | grep -sc '\-f dc-auth0-host.yml')
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage $0 [host|internal]"
  echo "if no parameters are passed, then GDC launch env variables are used to automatically determine mode."
  exit 0
elif [ "$1" = "host" ]; then
  IS_HOST="1"
elif [ "$1" = "internal" ]; then
  IS_HOST="0"
fi

if [ "$IS_HOST" = "0" ]; then
  echo "start-auth0.sh using container mode"
  docker-compose -f dc-auth0.yml up -d --build --force-recreate
else
  echo "start-auth0.sh using host mode"
  docker-compose -f dc-auth0-host.yml up -d --build --force-recreate
fi
sleep 5
