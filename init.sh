#!/usr/bin/env bash

source /etc/term_colors.sh

TITLE="GDC: $COMPOSE_PROJECT_NAME"
echo -n -e "$title_start$TITLE$title_end"


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


echo -e "$bldwht""============================================================================================== $txtrst"
echo -e "$bldgrn""connect to container shell via docker:   docker exec -it $COMPOSE_PROJECT_NAME-dev-1 bash -l $txtrst"

echo -e "user:$bldwht root $txtrst  password default unless changed is:$bldwht ContainersRule $txtrst"
if [ -n "$SSH_SERVER_PORT" ]; then
    echo -e "connect to container via ssh:$bldwht  ssh root@localhost -p $SSH_SERVER_PORT $txtrst"
    echo "if you get a REMOTE HOST IDENTIFICATION HAS CHANGED error use the following command to fix before connecting."
    echo "ssh-keygen -R [localhost]:$SSH_SERVER_PORT"
fi
echo -e "$bldwht""============================================================================================== $txtrst"
echo "sleeping forever...."
tail -f /dev/null 2>&1

