#!/usr/bin/env bash
if [ -r /usr/local/pyenv ]; then
  echo "activating pyenv"
  export PYENV_ROOT=/usr/local/pyenv
  command -v pyenv > /dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init -)"
  echo "python version $(python --version)"
fi
