#!/usr/bin/env bash

if [ -n "$1" ]; then
  UN="$1"
elif [ -n "$AUTH0_DEFAULT_USER" ]; then
  UN="$AUTH0_DEFAULT_USER"
else
  UN="user1"
fi

if [ "$UN" = "-h" ] || [ "$UN" = "--help" ]; then
  echo "Usage: get-auth-token [username]"
  exit 0
fi

if [ -n "$AUTH0_LOCAL_USERS_FILE" ]; then
  FILE="/workspace/$AUTH0_LOCAL_USERS_FILE" # use override auth0 mock user file
else
  FILE="/root/gdc-host/auth0_mock/users.json" # use default auth0 mock user file
fi

PW=$(jq ".$UN.pw" "$FILE" -r)

RET=$(curl -s -X POST -H "Content-Type: application/json" -d "{\"username\":\"$UN\", \"pw\":\"$PW\"}" "http://$AUTH0_CONTAINER_NAME:3001/login?redirect=nope")
if [ -n "$RET" ]; then
  echo "$RET"
  exit 1
fi


TOKEN=$(curl -s "http://$AUTH0_CONTAINER_NAME:3001/access_token")
echo "$TOKEN"
