#!/usr/bin/env bash

AWS_DIR=~/shared/.aws

CONFIG=$AWS_DIR/config
CREDS=$AWS_DIR/credentials

echo "Setting up local AWS credentials"

if [ -r $CONFIG ]; then
    echo "existing config file detected. aborting..."
    exit
fi

if [ ! -r $AWS_DIR ]; then
    mkdir -p $AWS_DIR || exit 1
fi

echo "Enter aws username in format of  first.last"
read -r username
if [ -z "$username" ]; then
    echo "Blank username. aborting..."
    exit
fi

cat << EOF > $CONFIG
[profile $username-identity]
region=us-west-2
output=json

[profile localstack]
region=us-east-1
output=text
EOF

cat << EOF > $CREDS
[$username-identity]
aws_access_key_id=
aws_secret_access_key=

[localstack]
aws_access_key_id=test
aws_secret_access_kty=test
EOF

ln -s $AWS_DIR ~/.aws

echo "Sign in at this URL https://IDENT_ACCOUNT_ALIAS.signin.aws.amazon.com/console then navigate to https://us-east-1.console.aws.amazon.com/iam/home#/security_credentials to generate your AWS keys if you dont already have them."
echo "Edit $CREDS file and add keys to your identity section"
