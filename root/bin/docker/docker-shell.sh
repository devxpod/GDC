#!/usr/bin/env bash
CONTAINER=$(docker ps | grep "$1" | cut -f1 -d' ' | head -n1)

if [ -z "$CONTAINER" ]; then
    echo "container not found"
    exit 1
fi
SHELL="$2"
if [ -z "$SHELL" ]; then
    SHELL="bash -l"
fi
docker exec -tiu root "$CONTAINER" $SHELL "$3" "$4" "$5" "$6" "$7" "$8" "$9"
