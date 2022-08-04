# Bitwarden CLI identity management workflow

## Overview

Bitwarden is an amazing open source password vault / OTP solution.

The vault portion is free and cloud synced, however the OTP portion requires a $10 / year subscription but is well worth it for the efficiency gained from not having to lookup and type / paste OTP tokens.

## Description

This workflow allows your securely store AWS account info and scripts so as not to have plain text files with aliases that would divulge sensitive info such as account numbers username and role names.

It also allows for assuming roles in any accounts you set up without having to lookup and type / paste MFA tokens.

## Installation
**Note: all tools and shell aliases (you will still need to create secure notes) are already installed in the dev container**

Start by going to https://vault.bitwarden.com/#/register  and creating and account getting the personal premium account.

Go to https://bitwarden.com/download/ and install the Bitwarden plugin for your browser. 
All major browsers are supported on both desktop and mobile.  
The bitwarden cli application is already installed in the dev container however if you want it on your host you can 
download the CLI executable and place it in your path.  
I recommend putting in a bin folder in your home dir and adding that bin folder to your path.

**_Note: If you want to be able to use biometrics to unlock your Bitwarden vault on your host then also install the desktop client._**

If you want to use this workflow on your host, and you don't have “jq” installed and in your path please download and install it. 
If your on Windows you can get the jq.exe and put it in the above recommended bin folder or someplace else in your path.

The SSM scripts are already installed in the dev container. 
If you want to use the workflow on your host, copy the scripts from this repo in the /root/bin/aws folder and
put in your bin folder or someplace in your path.

You must login to your vault in your browser, desktop application if you installed it for biometrics and in your dev containers.
Open a shell and type `bw login` to connect the cli to your Bitwarden account and initialize your cli vault.

If you are using this workflow on your host, add the following to your .bashrc or .zshrc file your home directory.  
This is not required in the dev container.  
```bash
export AWS_PROFILE=YOUR-identity
alias load_aliases="eval \`bw get item aws_bash_rc | jq -r '.notes'\`";
alias bw_reload="bw sync; load_aliases";
alias unlock='export BW_SESSION="$(bw unlock --raw)"; bw sync; load_aliases; echo "export BW_SESSION=$BW_SESSION;load_aliases"'
```
Replace **YOUR-identity** with your aws identity for example: `export AWS_PROFILE=paul.robello-identity`

## Setup of account and MFA

Setup Bitwarden to log into your AWS SSO account and assign it as your MFA device. 
It does not matter what you name the entry for this account in Bitwarden however I recommend aws-sso.

**_Note: When setting up Bitwarden OTP only populate the box with the secret, not the rest of provided URL parameters._**

Next setup Bitwarden to log into your AWS Identity in the identity account and assign it as your MFA provider. 
This entry must be named “aws-ident”. The reason this name is required, is because it must be a known name for the scripts below to auto obtain your MFA OTP token to assume roles.

## Bitwarden secure notes as scripts

Using your browser log into your Bitwarden vault and create a secure note named aws_bash_rc with the following content:

```bash
alias aws_otp="bw get totp 'aws-ident' | tr -d '\n'";
alias aws_otp_copy="bw get totp 'sandbox admin mfa'";  
alise aws_assume="source assume-role.sh YOUR_AWS_SSO_ACCOUNT YOUR-identity";
alias aws_assume_role="aws_assume arn:aws:iam::TARGET_ACCOUNT_NUM:role/ROLE_NAME \`aws_otp\`";  
alias aws_jump="export AWS_REGION=TARGET_AWS_REGION;ssm-ssh.sh EC2_INSTANCE_ID";  
alias aws_scp="export AWS_REGION=TARGET_AWS_REGION;ssm-scp.sh EC2_INSTANCE_ID us-east-1a";  
alias aws_rds_pf="export AWS_REGION=TARGET_AWS_REGION;ssm-jump-tunnel.sh EC2_INSTANCE_ID TARGET_AWS_REGION_AZ 5432 RDS_DNS_NAME 5432";

echo "aliases loaded";
```
Replace the following values in the template above with:
* RDS_DNS_NAME - DNS name of RDS or RDS proxy to connect to.
* EC2_INSTANCE_ID - EC2 instance id you want to ssh to or relay port forward through. 
* TARGET_AWS_REGION - Target AWS region where ec2 instance resides.
* TARGET_AWS_REGION_AZ - Target AWS region qualified with az where ec2 instance resides. example us-east-1a. 
* TARGET_ACCOUNT_NUM - AWS account number for the target account.
* ROLE_NAME - Name of the role you want to assume in the TARGET_ACCOUNT_NUM.
* YOUR-identity - Your AWS identity for example:  export AWS_PROFILE=paul.robello-identity
* YOUR_AWS_SSO_ACCOUNT - Your AWS single sign on account for example:

**_Note: For the script eval to work all lines must end with a semicolon._**

The above script block is soft wrapping some lines, when you enter them ensure they are on a single line.

### Alias Descriptions:
#### Core
* unlock - unlocks your vault, syncs it with cloud, and calls load_aliases.
* * if you are using the dev container and PERSIST_BITWARDEN_SESSION=yes then it will also write your session key to /root/persisted/.bw_session and this file will be sourced by any other shells you open to reduce need to unlock vault.
* load_aliases - loads the secure note with name aws-ident into your environment.
* bw_reload - syncs vault with cloud and calls load_aliases.
* aws-otp-copy - if aws and bitwarden are enabled this will get and display your aws MFA token with a newline.
* aws-otp - if aws and bitwarden are enabled this will get and display your aws MFA token without a newline so it can be embedded in aliases and scripts.

#### Custom
* aws_assume - used by role_assume to reduce boilerplate when you have lots of assume role aliases.
* aws_assume_role - grabs your MFA token and assumes a role in the target account
* aws_jump - opens an ssh session to the jump host in the target account.
* aws_scp - copies files to or from the jump host in the target account.
* aws_rds_pf - creates a port forward from your localhost through the jump host in the target account to the Postgres RDS instance.

You can use the above blueprint for as many accounts as you interact with, just give them unique aliases.

## Testing workflow

Open a new shell. You should see “unlock” printed in your terminal to remind you that you need to either unlock your vault or paste the vault session key.

**_Note: If you don't see “unlock” printed in your terminal then it's probably because you are not using bash as your shell and must include the .bashrc script into your shell startup sequence._**

Since this is the first shell you need to type `unlock` and enter you master password.  
If this succeeds you should see “aliases loaded” after a few moments.

Now type aws_assume_role and hit enter. In a few moments you should see that your credentials will expire in 12 hours.

**_Note: Sometimes the aws_assume_role will fail with message about invalid MFA token, just retry a few times waiting 5 or so seconds between each try. 
I think this is due to some kind of clock skew issue for the MFA token generation._**

**_Note: The role being assumed must be set to have a 12 hour expiration otherwise the assume role script will fail_**

After you have assumed the role you can now execute other SSM / AWS commands or use any of your other aliases such as js_prod_jump to open an ssh session to the jumphost.
