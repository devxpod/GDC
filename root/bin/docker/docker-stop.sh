#!/usr/bin/env bash
CONTAINER=$(docker ps | grep "$1" | cut -f1 -d' ' | head -n1)

if [ -z "$CONTAINER" ]; then
    echo "container not found"
    exit 1
fi
docker stop "$CONTAINER"
