#!/usr/bin/env bash

if [ -x /postStartCommand.sh ]; then
. /postStartCommand.sh
fi
echo "=============================================================================================="
echo "connect to container shell via docker:   docker exec -it $COMPOSE_PROJECT_NAME-dev-1 bash -l"

echo "user: root   password default unless changed is: ContainersRule"
if [ -n "$SSH_SERVER_PORT" ]; then
    echo "connect to container via ssh:  ssh root@localhost -p $SSH_SERVER_PORT"
    echo "if you get a REMOTE HOST IDENTIFICATION HAS CHANGED error use the following command to fix before connecting."
    echo "ssh-keygen -R [localhost]:$SSH_SERVER_PORT"
fi
echo "=============================================================================================="
echo "sleeping forever...."
tail -f /dev/null 2>&1
