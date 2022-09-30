#!/usr/bin/env bash

P=$(pwd | sed 's/\/workspace//')
P="$HOST_PROJECT_PATH$P"

echo "Using host project path of $P"

echo
env -i bash --noprofile --norc -c \
"FORCE_PROJECT_PATH=$P \
NO_DEVNET_RM=yes \
DEVNET_NAME=$DEVNET_NAME \
OS=$HOST_OS \
GDC_DIR=$GDC_DIR \
HOME=$HOST_HOME \
PATH=$PATH \
USER=$USER \
LC_CTYPE=${LC_ALL:-${LC_CTYPE:-$LANG}} \
GDC_PARENT=$COMPOSE_PROJECT_NAME \
run-dev-container.sh $*"
