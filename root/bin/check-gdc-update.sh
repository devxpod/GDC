#!/usr/bin/env bash

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Checks GDC repository for updated version of GDC."
  exit 0
fi

GDC_ROOT=/root/gdc-host
REPO_VER=$(git --work-tree=$GDC_ROOT --git-dir=$GDC_ROOT/.git describe --match 'v[0-9]*\.[0-9]*\.[0-9]*' --abbrev=0 --tags \
"$(git --work-tree=$GDC_ROOT --git-dir=$GDC_ROOT/.git rev-list --tags --max-count=1)" | cut -dv -f2)

OUR_VERSION=$(grep '\- DEV_CONTAINER=' $GDC_ROOT/docker-compose.yml | cut -d= -f2 | cut -d' ' -f1)

if [ "$REPO_VER" != "$OUR_VERSION" ]; then
  echo "Your GDC version $OUR_VERSION"
  echo "GDC Update $REPO_VER available! Please exit GDC, pull then restart GDC with env var  CLEAN=yes"
else
  echo "Your GDC version $OUR_VERSION is current."
fi
