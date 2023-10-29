#!/usr/bin/env bash
# make sure windows git bash does not alter paths
export MSYS_NO_PATHCONV=1

if [[ "$1" = "--help" || "$1" = "-h" ]]; then
  echo "Used to stop running localstack main container with name $LS_MAIN_CONTAINER_NAME"
  exit 0
fi

docker rm -f "$LS_MAIN_CONTAINER_NAME"
docker ps -a --format '{{.Names}}' | grep "^$(echo "$LS_MAIN_CONTAINER_NAME-" | tr "_" "-")" | xargs -I {} docker rm -f {}

sleep 2
