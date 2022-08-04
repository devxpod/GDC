#!/usr/bin/env bash

file="$1"

if [ -z "$file" ]; then
  file=aws_session
fi

env | grep AWS_ | sed 's/^AWS_/export AWS_/'> "$file"
env | grep PULUMI_ | sed 's/^PULUMI_/export PULUMI_/'>> "$file"
