#!/usr/bin/env bash

# get shell running the script not the #! shell
# sometimes shell is preceded by a - which needs to be removed.
# ACTUAL_SHELL is used to determine how to handle custom prompts
if [[ $OSTYPE =~ darwin* ]] # MAC
then
  ACTUAL_SHELL=$(ps -o comm= -p "$$" | sed 's/^-//')
else
  ACTUAL_SHELL=$(ps -p "$$" | sed 's/^-//')
fi
#echo $ACTUAL_SHELL

bold=$(tput bold)
normal=$(tput sgr0)

txtblk='\[\033[0;30m\]' # Black - Regular
txtred='\[\033[0;31m\]' # Red
txtgrn='\[\033[0;32m\]' # Green
txtylw='\[\033[0;33m\]' # Yellow
txtblu='\[\033[0;34m\]' # Blue
txtpur='\[\033[0;35m\]' # Purple
txtcyn='\[\033[0;36m\]' # Cyan
txtwht='\[\033[0;37m\]' # White
bldblk='\[\033[1;30m\]' # Black - Bold
bldred='\[\033[1;31m\]' # Red
bldgrn='\[\033[1;32m\]' # Green
bldylw='\[\033[1;33m\]' # Yellow
bldblu='\[\033[1;34m\]' # Blue
bldpur='\[\033[1;35m\]' # Purple
bldcyn='\[\033[1;36m\]' # Cyan
bldwht='\[\033[1;37m\]' # White
unkblk='\[\033[4;30m\]' # Black - Underline
undred='\[\033[4;31m\]' # Red
undgrn='\[\033[4;32m\]' # Green
undylw='\[\033[4;33m\]' # Yellow
undblu='\[\033[4;34m\]' # Blue
undpur='\[\033[4;35m\]' # Purple
undcyn='\[\033[4;36m\]' # Cyan
undwht='\[\033[4;37m\]' # White
bakblk='\[\033[40m\]'   # Black - Background
bakred='\[\033[41m\]'   # Red
bakgrn='\[\033[42m\]'   # Green
bakylw='\[\033[43m\]'   # Yellow
bakblu='\[\033[44m\]'   # Blue
bakpur='\[\033[45m\]'   # Purple
bakcyn='\[\033[46m\]'   # Cyan
bakwht='\[\033[47m\]'   # White
txtrst='\[\033[0m\]'    # Text Reset

USAGE=$(cat <<-END
source ./issue_mfa.sh [AWS_USERNAME] [AWS Profile Name] [AWS Role ARN] [MFA_TOKEN] [PROMPT_OPTIONS]
   Uses the Identity account to assume a cross-account role.
   Issues an aws security token and sets it automatically.
   If added the -v flag it will echos AWS_SECRET_ACCESS_KEY,
   AWS_ACCESS_KEY_ID, AWS_SECURITY_TOKEN, and AWS_SESSION_TOKEN
   as exports you can set in your shell.
   AWS_USERNAME is case-sensitive.
   PROMPT_OPTIONS=-p|-c|-t -t only updates title, -p updates title and will alter your prompt with info acout currently assume role and account -c does same as -p but with colors
END
)

# safety check for source
# https://stackoverflow.com/questions/2683279/how-to-detect-if-a-script-is-being-sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "${bold}ERROR:${normal} Check that you are properly sourcing the script"
    echo
    echo "This script should be run as:"
    echo "$ ${bold}source${normal} ./assume-role.sh [AWS_USERNAME] [AWS Profile Name] [AWS Role ARN] [MFA_TOKEN] "
    exit 1
fi

if ! [ -x "$(command -v jq)" ]; then
    echo 'Error: jq is not installed.' >&2
    echo 'Try: brew install jq' >&2
    return 1
fi

if ! [ -x "$(command -v aws)" ]; then
    echo 'Error: aws-cli is not installed.' >&2
    echo 'Try: brew install awscli' >&2
    return 1
fi

if [[ $1 == "-h" ]]; then
    echo "$USAGE"
    return 0
fi

if [[ $# -lt 4 ]]; then
    echo "$USAGE" >&2
    return 1
fi

if [[ -z "${AWS_IDENTITY_ACCOUNT}" ]]; then
    echo "Env var AWS_IDENTITY_ACCOUNT must be set to the AWS Account Number for your Identity account"
    echo "$USAGE"
    return 0
fi

unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_SECURITY_TOKEN
unset AWS_SESSION_TOKEN
unset AWS_SESSION_EXPIRATION
unset AWS_ACCOUNT
unset AWS_ROLE

aws_out="$(aws sts assume-role --duration-seconds 43200 --output json --role-arn $3 --serial-number arn:aws:iam::${AWS_IDENTITY_ACCOUNT}:mfa/$1  --role-session-name $1 --profile $2 --token-code $4)"
ret=$?
if [ $ret -ne 0 ]; then
    echo -e "${bold}ERROR:${normal} Could not set AWS Sessions. Read error above..."
    return $ret
fi
aws_id=$(echo $aws_out | jq -r .Credentials.AccessKeyId)
aws_secret=$(echo $aws_out | jq -r .Credentials.SecretAccessKey)
aws_session=$(echo $aws_out | jq -r .Credentials.SessionToken)

export AWS_ACCESS_KEY_ID=$aws_id
export AWS_SECRET_ACCESS_KEY=$aws_secret
export AWS_SECURITY_TOKEN=$aws_session
export AWS_SESSION_TOKEN=$aws_session
if [[ $OSTYPE =~ darwin* ]] # MAC
then
  export AWS_SESSION_EXPIRATION=$(date -u -v "+12H" +"%FT%T%Z")
else
  export AWS_SESSION_EXPIRATION=$(date -u +%FT%T%Z -d "+12 hours")
fi

echo "${bold}AWS Session credentials saved. Will expire in 12 hours${normal}"

if [[ "$5" == "-v" ]]; then
    echo " export AWS_ACCESS_KEY_ID=$aws_id"
    echo " export AWS_SECRET_ACCESS_KEY=$aws_secret"
    echo " export AWS_SECURITY_TOKEN=$aws_session"
    echo " export AWS_SESSION_TOKEN=$aws_session"
    return
fi

# if prompt options not empty setup some vars and set terminal title
if [[ ! -z "$5" ]]; then
  export AWS_ACCOUNT="$(cut -f5 -d: <<<$3 | sed -e 's/[[:space:]]*$//')" # extract account from role arn
  export AWS_ROLE="$(cut -f6 -d: <<<$3  | cut -f2 -d/| sed -e 's/[[:space:]]*$//')" #extract role name from role arn
  export TITLE=$AWS_ROLE@$AWS_ACCOUNT # used for title and plain prompts
  NEWLINE=$'\n' # needed for zsh prompt
  echo -n -e "\033]0;$TITLE\007" # set title / tab

  function get_assume_remain()
  {
    if [ -z "$AWS_SESSION_EXPIRATION" ]; then
      REMAIN="X"
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
  }
  # if plain prompt alter options set
  if [[ "$5" == "-p" ]]; then
    echo "Setting plain prompt"

    function precmd()
    {
      if [ -z "$AWS_ACCESS_KEY_ID" ]; then
        if [[ $OSTYPE =~ msys* ]] # GIT BASH
        then
            export PS1="${debian_chroot:+($debian_chroot)}\u@\h:\w"'`__git_ps1`'"\n\$ "
        fi
        if [[ "$OSTYPE" == "linux-gnu" ]] # WINDOWS WSL / linux
        then
            export PS1="${debian_chroot:+($debian_chroot)}\u@\h:\w"'`__git_ps1`'"\n\$ "
        fi
        if [[ $OSTYPE =~ darwin* ]] # MAC
        then
          export PS1="%n@%m %1~%f%# "
        fi
        if [[ "$ACTUAL_SHELL" == "bash" ]] # bash shell
        then
            export PS1="${debian_chroot:+($debian_chroot)}\u@\h:\w\n\$ "
        fi
        if [[ "$ACTUAL_SHELL" == "zsh" ]] # zsh shell
        then
          export PS1="%n@%m %1~%f%# "
        fi
        return
      fi
      get_assume_remain
      if [[ $OSTYPE =~ msys* ]] # GIT BASH
      then
          export PS1="(${AWS_ROLE}@${AWS_ACCOUNT}@${AWS_REGION}$REMAIN)\n${debian_chroot:+($debian_chroot)}\u@\h:\w"'`__git_ps1`'"\n\$ "
      fi
      if [[ "$OSTYPE" == "linux-gnu" ]] # WINDOWS WSL / linux
      then
          export PS1="(${AWS_ROLE}@${AWS_ACCOUNT}@${AWS_REGION}$REMAIN)\n${debian_chroot:+($debian_chroot)}\u@\h:\w"'`__git_ps1`'"\n\$ "
      fi
      if [[ $OSTYPE =~ darwin* ]] # MAC
      then
        export PS1="($AWS_ROLE@$AWS_ACCOUNT@$AWS_REGION$REMAIN)${NEWLINE}%n@%m %1~%# "
      fi
      if [[ "$ACTUAL_SHELL" == "bash" ]] # bash shell
      then
          export PS1="(${AWS_ROLE}@${AWS_ACCOUNT}@${AWS_REGION}$REMAIN)\n${debian_chroot:+($debian_chroot)}\u@\h:\w\n\$ "
      fi
      if [[ "$ACTUAL_SHELL" == "zsh" ]] # zsh shell
      then
        export PS1="($AWS_ROLE@$AWS_ACCOUNT@$AWS_REGION$REMAIN)${NEWLINE}%n@%m %1~%# "
      fi
    }
    PROMPT_COMMAND=precmd
  fi
  # if color prompt alter option set
  if [[ "$5" == "-c" ]]; then
    echo "Setting color prompt"

    function precmd()
    {
      if [ -z "$AWS_ACCESS_KEY_ID" ]; then
        if [[ $OSTYPE =~ msys* ]] # GIT BASH
        then
            export PS1="${debian_chroot:+($debian_chroot)}$bldred\u$bldylw@$bldgrn\h$txtrst:$bldblu\w$txtrst"'`__git_ps1`'"\n\$ "
            return
        fi
        if [[ "$OSTYPE" == "linux-gnu" ]] # WINDOWS WSL / linux
        then
            export PS1="${debian_chroot:+($debian_chroot)}$bldred\u$bldylw@$bldgrn\h$txtrst:$bldblu\w$txtrst"'`__git_ps1`'"\n\$ "
        fi
        if [[ $OSTYPE =~ darwin* ]] # MAC
        then
          export PS1="%F{red}%n%F{yellow}@%F{green}%m%f %F{cyan}%1~%f%# "
        fi
        if [[ "$ACTUAL_SHELL" == "bash" ]] # bash shell
        then
            export PS1="${debian_chroot:+($debian_chroot)}$bldred\u$bldylw@$bldgrn\h$txtrst:$bldblu\w$txtrst\n\$ "
        fi
        if [[ "$ACTUAL_SHELL" == "zsh" ]] # zsh shell
        then
          export PS1="%F{red}%n%F{yellow}@%F{green}%m%f %F{cyan}%1~%f%# "
        fi
        return
      fi
      get_assume_remain
      if [[ $OSTYPE =~ msys* ]] # GIT BASH
      then
          export PS1="($bldpur${AWS_ROLE}$bldgrn@$bldpur${AWS_ACCOUNT}$bldgrn@$bldpur${AWS_REGION}$bldgrn$REMAIN$txtrst)\n${debian_chroot:+($debian_chroot)}$bldred\u$bldylw@$bldgrn\h$txtrst:$bldblu\w$txtrst"'`__git_ps1`'"\n\$ "
      fi
      if [[ "$OSTYPE" == "linux-gnu" ]] # WINDOWS WSL / linux
      then
          export PS1="($bldpur${AWS_ROLE}$bldgrn@$bldpur${AWS_ACCOUNT}$bldgrn@$bldpur${AWS_REGION}$bldgrn$REMAIN$txtrst)\n${debian_chroot:+($debian_chroot)}$bldred\u$bldylw@$bldgrn\h$txtrst:$bldblu\w$txtrst"'`__git_ps1`'"\n\$ "
      fi
      if [[ $OSTYPE =~ darwin* ]] # MAC
      then
        export PS1="(%F{magenta}$AWS_ROLE%F{yellow}@%F{magenta}$AWS_ACCOUNT%F{yellow}@%F{magenta}$AWS_REGION%F{yellow}$REMAIN%f)${NEWLINE}%F{red}%n%F{yellow}@%F{green}%m%f %F{cyan}%1~%f%# "
      fi
      if [[ "$ACTUAL_SHELL" == "bash" ]] # bash shell
      then
          export PS1="($bldpur${AWS_ROLE}$bldgrn@$bldpur${AWS_ACCOUNT}$bldgrn@$bldpur${AWS_REGION}$bldgrn$REMAIN$txtrst)\n${debian_chroot:+($debian_chroot)}$bldred\u$bldylw@$bldgrn\h$txtrst:$bldblu\w$txtrst\n\$ "
      fi
      if [[ "$ACTUAL_SHELL" == "zsh" ]] # zsh shell
      then
        export PS1="(%F{magenta}$AWS_ROLE%F{yellow}@%F{magenta}$AWS_ACCOUNT%F{yellow}@%F{magenta}$AWS_REGION%F{yellow}$REMAIN%f)${NEWLINE}%F{red}%n%F{yellow}@%F{green}%m%f %F{cyan}%1~%f%# "
      fi
    }

    PROMPT_COMMAND=precmd
  fi
fi

