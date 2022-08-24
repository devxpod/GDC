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

IS_HOST_LS=$(echo "$GDC_COMPOSE_FILES" | grep -sc '\-f dc-ls-host.yml')



if [ "$IS_HOST_LS" = "0" ]; then
  docker-compose -f dc-ls-host.yml up -d --build --force-recreate
else
  docker-compose -f dc-ls.yml up -d --build --force-recreate
fi
