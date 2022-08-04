#!/usr/bin/env bash


if [ -z "$AWS_SESSION_EXPIRATION" ]; then
  REMAIN=""
else
  if [[ $OSTYPE =~ msys* ]] # GIT BASH
  then
    e=$(date -u -d "$AWS_SESSION_EXPIRATION" "+%s")
    s=$(date -u "+%s")
  fi
  if [[ "$OSTYPE" == "linux-gnu" ]] # WINDOWS WSL / linux
  then
    e=$(date -u -d "$AWS_SESSION_EXPIRATION" "+%s")
    s=$(date -u "+%s")
  fi
  if [[ $OSTYPE =~ darwin* ]] # MAC
  then
    e=$(date -j -u -f "%FT%T%Z"  "$AWS_SESSION_EXPIRATION" "+%s")
    s=$(date -u "+%s")
  fi
  diff=$((e - s))
  if [ "$diff" -le "0" ]; then
    REMAIN="X"
  else
    if [[ $OSTYPE =~ msys* ]] # GIT BASH
    then
      REMAIN=$(date -u -d @$diff "+%T")
    fi
    if [[ "$OSTYPE" == "linux-gnu" ]] # WINDOWS WSL / linux
    then
      REMAIN=$(date -u -d @$diff "+%T")
    fi
    if [[ $OSTYPE =~ darwin* ]] # MAC
    then
      REMAIN=$(date -j -u -f "%s" $diff "+%T")
    fi
  fi
fi
echo -n $REMAIN
