#!/usr/bin/env bash

P=$(pwd | sed 's/\/workspace//')
P="$HOST_PROJECT_PATH$P"

echo "Using host project path of $P"

echo
env -i bash --noprofile --norc -c \
"FORCE_PROJECT_PATH=$P \
NO_DEVNET_RM=$NO_DEVNET_RM \
OS=$HOST_OS \
GDC_DIR=$GDC_DIR \
HOME=$HOST_HOME \
PATH=$PATH \
run-dev-container.sh $@"
