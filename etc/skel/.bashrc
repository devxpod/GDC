START_TIME=$(date +%s)
if [ "$FORCE_INTERACTIVE" != "yes" ]; then
  # If not running interactively, don't do anything
  case $- in
    *i*) ;;
    *) return ;;
  esac
fi
# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000
# change location so its gets stored in a volume
HISTFILE=~/bash_history/.bash_history
PROMPT_COMMAND='history -a'
# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
  debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
  xterm-color | *-256color) color_prompt=yes ;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
  if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
    # We have color support; assume it's compliant with Ecma-48
    # (ISO/IEC-6429). (Lack of such support is extremely rare, and such
    # a case would tend to support setf rather than setaf.)
    color_prompt=yes
  else
    color_prompt=
  fi
fi

#if [ "$color_prompt" = yes ]; then
#  PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
#else
#  PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
#fi
unset color_prompt force_color_prompt

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
  test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
  alias ls='ls --color=auto'
  #alias dir='dir --color=auto'
  #alias vdir='vdir --color=auto'

  alias grep='grep --color=auto'
  alias fgrep='fgrep --color=auto'
  alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Alias definitions.
if [ -f ~/.bash_aliases ]; then
  . "$HOME/.bash_aliases"
fi

alias docker-compose="docker compose"

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

###### GDC configs #######

source /etc/term_colors.sh

OS=$(echo -n "$HOST_OS" | cut -d _ -f1)

if [ "$OS" = "Windows" ]; then
  echo "Detected Windows Host"
  HOST_PROJECT_PATH=$(echo "$HOST_PROJECT_PATH" | sed -E 's/^(\w):(.*)$/\/\1\2/' | tr '\\' /)
  export HOST_PROJECT_PATH
fi

if [ "$USE_COLOR_PROMPT" = "yes" ]; then
  export PS1="$p_bldred\u$p_bldylw@$p_txtgrn\h($COMPOSE_PROJECT_NAME) $p_bldblu\w$p_txtrst"'`__git_ps1`'"$p_txtrst\n$ "
else
  export PS1="\u@\h($COMPOSE_PROJECT_NAME) \w"'`__git_ps1`'"\n$ "
fi
TITLE="GDC: $COMPOSE_PROJECT_NAME shell"
echo -n -e "$title_start$TITLE$title_end"

if [ "$SHOW_VERSIONS_ON_LOGIN" = "yes" ]; then
  docker --version
fi

if [ -n "$PHP_VERSION" ]; then
  if [ "$SHOW_VERSIONS_ON_LOGIN" = "yes" ]; then
    echo "php version $(php --version)"
  fi
fi

if [ "$USE_DOT_NET" = "yes" ]; then
  export DOTNET_ROOT=/usr/local/dotnet
  export PATH=${PATH}:${DOTNET_ROOT}
  if [ "$SHOW_VERSIONS_ON_LOGIN" = "yes" ]; then
    echo ".NET version $(dotnet --list-sdks)"
  fi
fi

if [ -n "$GOLANG_VERSION" ]; then
  export GOPATH=/go
  export PATH=$PATH:$GOPATH/bin:/usr/local/go/bin
  if [ "$SHOW_VERSIONS_ON_LOGIN" = "yes" ]; then
    go version
  fi
fi

if [ -n "$RUST_VERSION" ]; then
  export PATH=$PATH:/root/.cargo/bin
  if [ "$SHOW_VERSIONS_ON_LOGIN" = "yes" ]; then
    echo "rustc version $(rustc --version)"
  fi
fi

if [ -r "$NVM_DIR/nvm.sh" ]; then
  echo "activating nvm env"
  . "$NVM_DIR/nvm.sh"
  if [ "$SHOW_VERSIONS_ON_LOGIN" = "yes" ]; then
    echo "node version $(node --version)"
    echo "npm version $(npm --version)"
  fi
fi

if [ "$USE_BITWARDEN" = "yes" ]; then
  if [ "$SHOW_VERSIONS_ON_LOGIN" = "yes" ]; then
    echo "bitwarden cli version $(bw --version)"
  fi
  alias load_aliases="eval \`bw get item bw_bash_rc | jq -r '.notes'\`"
  alias bw_reload="bw sync; load_aliases"

  if [ "$PERSIST_BITWARDEN_SESSION" = "yes" ]; then
    alias unlock='export BW_SESSION="$(bw unlock --raw)"; bw sync; load_aliases; echo "export BW_SESSION=$BW_SESSION">/root/persisted/.bw_session'
    alias unlock_quiet='export BW_SESSION="$(bw unlock --raw)"; bw sync; load_aliases; echo "export BW_SESSION=$BW_SESSION">/root/persisted/.bw_session'
    if [ -r ~/persisted/.bw_session ]; then
      echo "Attempting to load existing bitwarden session..."
      . "$HOME/persisted/.bw_session"
      BW_RC=$(bw get item bw_bash_rc --nointeraction 2>/dev/null | jq -r '.notes' 2>/dev/null)
      if [ -z "$BW_RC" ] ; then
        echo -e $bldred"Existing session invalid$txtrst. Please run '$bldgrn""unlock$txtrst'"
        rm -f ~/persisted/.bw_session
        bw sync --nointeraction --quiet
      else
        eval $BW_RC
      fi
      unset BW_RC
    else
      echo -e $bldylw"No existing bitwarden session found$txtrst. Please run '$bldgrn""unlock or unlock_quiet$txtrst'"
    fi
  else
    alias unlock='export BW_SESSION="$(bw unlock --raw)"; bw sync; load_aliases; echo "export BW_SESSION=$BW_SESSION;load_aliases"'
    alias unlock_quiet='export BW_SESSION="$(bw unlock --raw)"; bw sync; load_aliases; echo "load_aliases"'
  fi

  if [ "$USE_AWS" = "yes" ]; then
    alias aws-otp="bw get totp 'aws-ident' | tr -d '\n'"
  fi
fi

if [ "$USE_AWS" = "yes" ]; then
  export PATH="$PATH:/root/bin-extra/aws"
  alias unset-aws="unset AWS_PROFILE AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION AWS_SESSION_TOKEN AWS_SECURITY_TOKEN AWS_SESSION_EXPIRATION PULUMI_BACKEND_URL PULUMI_CONFIG_PASSPHRASE"
  if [ ! -r ~/.aws/config ]; then
    echo "**** No AWS credentials found, run setup-aws.sh to configure ****"
  fi
  if [ "$SHOW_VERSIONS_ON_LOGIN" = "yes" ]; then
    echo "aws cli version $(aws --version)"
  fi
fi

if [ "$USE_CDK" = "yes" ]; then
  if [ "$SHOW_VERSIONS_ON_LOGIN" = "yes" ]; then
    echo "cdk version $(cdk --version)"
    echo "terraform version $(terraform -version)"
    echo "cdktf version $(cdktf --version)"
  fi
fi

if [ "$USE_LOCALSTACK" = "yes" ]; then
  if [ "$USE_LOCALSTACK_HOST" = "yes" ]; then
    export LOCALSTACK_HOST=host.docker.internal:4566
    alias awsl="aws --no-sign-request --endpoint-url http://$LOCALSTACK_HOST"
  else
    alias awsl="aws --endpoint-url http://$LS_MAIN_CONTAINER_NAME:4566"
    export LOCALSTACK_HOST=localstack:4566
  fi
  if [ -n "$LOCALSTACK_STATIC_IP" ]; then
    echo "Localstack static ip: $LOCALSTACK_STATIC_IP"
  fi
fi

if [ -n "$GDC_DNS_PRI_IP" ]; then
  echo "GDC PRI DNS IP $GDC_DNS_PRI_IP"
fi
if [ -n "$GDC_DNS_SEC_IP" ]; then
  echo "GDC SEC DNS IP $GDC_DNS_SEC_IP"
fi

if [ -n "$PULUMI_VERSION" ]; then
  alias pr="clear;pulumi refresh -fy"
  alias pu="clear;pulumi up -fy"
  if [ "$SHOW_VERSIONS_ON_LOGIN" = "yes" ]; then
    echo "pulumi version $(pulumi version)"
  fi
fi

if [ -r /usr/local/pyenv ]; then
  echo "activating pyenv"
  export PYENV_ROOT=/usr/local/pyenv
  command -v pyenv > /dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init -)"
  #eval "$(pyenv virtualenv-init -)"
  if [ "$SHOW_VERSIONS_ON_LOGIN" = "yes" ]; then
    echo "python version $(python --version)"
  fi
fi

if [ -r ~/venv/bin/activate ]; then
  echo "activating python venv"
  . "$HOME/venv/bin/activate"
  if [ "$SHOW_VERSIONS_ON_LOGIN" = "yes" ]; then
    echo "python version $(python --version)"
  fi
fi

export PATH="$PATH:/root/bin-extra/ls"
export PATH="$PATH:/root/bin-extra/auth0"

alias ls_gdc_network="docker network inspect "$DEVNET_NAME" | jq -r '.[0].Containers[].Name'"

if [ -r ~/persisted/bash_rc_ext.sh ]; then
  . "$HOME/persisted/bash_rc_ext.sh"
fi

if [ "$CHECK_UPDATES" = "yes" ]; then
  /root/bin-extra/check-gdc-update.sh
fi

if [[ -n "$PROXY_URL" && "$PROXY_AUTO_EXPORT_ENV" = "yes" ]]; then
  export HTTP_PROXY=$PROXY_URL
  export HTTPS_PROXY=$PROXY_URL
fi

END_TIME=$(date +%s)
echo "Shell startup took $(($END_TIME - $START_TIME)) seconds"
