#!/usr/bin/env bash
# make sure windows git bash does not alter paths
export MSYS_NO_PATHCONV=1

docker rm -f "$LS_MAIN_CONTAINER_NAME"
sleep 2
