#!/usr/bin/env bash

source /etc/term_colors.sh


if [ -x /postStartCommand.sh ]; then
. /postStartCommand.sh
fi
echo "sleeping forever...."
tail -f /dev/null 2>&1

