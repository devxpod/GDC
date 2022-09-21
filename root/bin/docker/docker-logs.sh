#!/usr/bin/env bash

CONTAINER="$1"
shift
CONTAINER=$(docker ps | grep "$CONTAINER" | cut -f1 -d' ' | head -n1)

if [ -z "$CONTAINER" ]; then
    echo "container not found"
    exit 1
fi
docker logs -f "$CONTAINER"
