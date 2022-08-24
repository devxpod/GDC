#!/usr/bin/env bash
# make sure windows git bash does not alter paths
export MSYS_NO_PATHCONV=1

IS_HOST_LS=$(echo "$GDC_COMPOSE_FILES" | grep -sc '\-f dc-ls-host.yml')

cd /root/gdc-host || exit 1

if [ "$IS_HOST_LS" = "0" ]; then
  docker-compose -f dc-ls-host.yml down
else
  docker-compose -f dc-ls.yml down
fi
