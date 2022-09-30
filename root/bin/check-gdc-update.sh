#!/usr/bin/env bash

source /etc/term_colors.sh

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Checks GDC repository for updated version of GDC."
  exit 0
fi

GDC_ROOT=/root/gdc-host
REPO_VER=$(git --work-tree=$GDC_ROOT --git-dir=$GDC_ROOT/.git describe --match 'v[0-9]*\.[0-9]*\.[0-9]*' --abbrev=0 --tags \
"$(git --work-tree=$GDC_ROOT --git-dir=$GDC_ROOT/.git rev-list --tags --max-count=1)" | cut -dv -f2)

OUR_VERSION=$(grep '\- DEV_CONTAINER=' $GDC_ROOT/docker-compose.yml | cut -d= -f2 | cut -d' ' -f1)

if [ "$REPO_VER" != "$OUR_VERSION" ]; then
  P1=$(printf "%03d" "$(echo "$REPO_VER"| cut -d. -f1)")
  P2=$(printf "%03d" "$(echo "$REPO_VER"| cut -d. -f2)")
  P3=$(printf "%03d" "$(echo "$REPO_VER"| cut -d. -f3)")
  RV="$P1$P2$P3"
  P1=$(printf "%03d" "$(echo "$OUR_VERSION"| cut -d. -f1)")
  P2=$(printf "%03d" "$(echo "$OUR_VERSION"| cut -d. -f2)")
  P3=$(printf "%03d" "$(echo "$OUR_VERSION"| cut -d. -f3)")
  OV="$P1$P2$P3"
  if [ "$RV" -gt "$OV" ]; then
    echo "Your GDC version $OUR_VERSION"
    echo -e "$txtylw""GDC Update $REPO_VER available! Please exit GDC, pull then restart GDC with env var  CLEAN=yes $txtrst"
    exit
  fi
fi

echo "Your GDC version $OUR_VERSION is current."
