#!/usr/bin/env bash

source /etc/term_colors.sh

TITLE="GDC: $COMPOSE_PROJECT_NAME"
echo -n -e "$title_start$TITLE$title_end"

dos2unix /root/gdc-host/.env-gdc*

cd /workspace || echo "$bldred Cant cd to /workspace!!!!! $txtrst"

if [ -x /postStartCommand.sh ]; then
. /postStartCommand.sh
fi



if [ -n "$GDC_ENTRYPOINT" ]; then
  $GDC_ENTRYPOINT
  EP_EC=$?
  if [ $EP_EC -ne 0 ] ; then
    echo "$bldred GDC_ENTRYPOINT returned non-zero exit code: $EP_EC  $txtrst"
    /root/bin-extra/auth0/stop-auth0.sh 2>/dev/null
    /root/bin-extra/ls/stop-ls.sh 2>/dev/null
    exit $EP_EC
  fi
  if [ "$GDC_RUN_MODE" != "daemon" ]; then
    /root/bin-extra/auth0/stop-auth0.sh 2>/dev/null
    /root/bin-extra/ls/stop-ls.sh 2>/dev/null
    exit 0
  fi
fi


echo -e "$bldwht""================================================================================ $txtrst"
echo -e "$bldgrn""Connect to GDC shell via docker with:  docker exec -it $GDC_CONTAINER_NAME bash -l $txtrst  $CLIPBOARD_MSG"

echo -e "user:$bldwht root $txtrst  password default unless changed is:$bldwht ContainersRule $txtrst"
if [ -n "$SSH_SERVER_PORT" ]; then
    echo -e "Connect to GDC via ssh:$bldwht  ssh root@localhost -p $SSH_SERVER_PORT $txtrst"
    echo "If you get a REMOTE HOST IDENTIFICATION HAS CHANGED error. "
    echo "Use the following command to fix before connecting:"
    echo -e "$bldgrn""ssh-keygen -R [localhost]:$SSH_SERVER_PORT $txtrst"
fi
if [ -n "$STARTUP_MSG" ]; then
  echo -e "$bldgrn""----- [ $STARTUP_MSG ] ----- $txtrst"
fi
echo -e "$bldwht""================================================================================ $txtrst"
echo "sleeping forever...."
tail -f /dev/null 2>&1

