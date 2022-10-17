#!/usr/bin/env bash
# make sure windows git bash does not alter paths
export MSYS_NO_PATHCONV=1

docker rm -f "$AUTH0_CONTAINER_NAME"

sleep 2
