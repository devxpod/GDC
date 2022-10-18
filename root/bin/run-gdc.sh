#!/usr/bin/env bash

P=$(pwd | sed 's/\/workspace//')
P="$HOST_PROJECT_PATH$P"

echo "Using host project path of $P"

CUSTOM_ENVS=""
oIFS="$IFS"
IFS=$'\n'
for ENV in $(env); do
  if [[ "$ENV" =~ ^GDC_ENV_ ]]; then
    if [ -z "$CUSTOM_ENVS" ]; then
      CUSTOM_ENVS="$ENV"
    else
      CUSTOM_ENVS="$CUSTOM_ENVS"$'\n'"$ENV"
    fi
  fi
done

CUSTOM_ENV_FILE="/tmp/run_gdc_custom_env_$COMPOSE_PROJECT_NAME"
if [ -r "$CUSTOM_ENV_FILE" ]; then
  rm -rf "$CUSTOM_ENV_FILE"
fi
  cat << EOF > "$CUSTOM_ENV_FILE"
export FORCE_PROJECT_PATH=$P
export NO_DEVNET_RM=yes
export DEVNET_NAME=$DEVNET_NAME
export OS=$HOST_OS
export GDC_DIR=$GDC_DIR
export HOME=$HOST_HOME
export PATH=$PATH
export USER=$USER
export LC_CTYPE=${LC_ALL:-${LC_CTYPE:-$LANG}}
export GDC_PARENT=$COMPOSE_PROJECT_NAME
EOF

if [ -n "$CUSTOM_ENVS" ]; then
  for i in $CUSTOM_ENVS; do
    cat << EOF >> "$CUSTOM_ENV_FILE"
export $i
EOF
  done

  echo "" >> "$CUSTOM_ENV_FILE"
  echo "CUSTOM_ENVS:   $CUSTOM_ENVS"
fi
IFS="$oIFS"
unset oIFS

echo
env -i bash --noprofile --rcfile "$CUSTOM_ENV_FILE" -ic "run-dev-container.sh $*"
