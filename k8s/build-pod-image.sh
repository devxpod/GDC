#!/usr/bin/env bash

echo "Loading container .env-gdc environment file"
source ".env-gdc-local"
source "../.env-gdc"

echo "building $1:$2"

export IMAGE=$1
export TAG=$2
docker compose build