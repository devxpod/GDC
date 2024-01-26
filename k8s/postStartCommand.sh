#!/usr/bin/env bash

if [ -r /usr/local/pyenv ]; then
    export PYENV_ROOT=/usr/local/pyenv
    command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
#    eval "$(pyenv virtualenv-init -)"

    if [ "$USE_PRECOMMIT" = "yes" ]; then
        if [[ ! -r /workspace/.git/hooks/pre-commit ||  "$(grep -c "File generated by pre-commit" /workspace/.git/hooks/pre-commit)" = "0" ]]; then
            echo "installing pre-commit hooks..."
            cd /workspace && pre-commit install --allow-missing-config
        else
            echo "pre-commit hooks already installed, skipping..."
        fi
        if [ -r /workspace/.git/hooks/pre-commit.legacy ]; then
            rm /workspace/.git/hooks/pre-commit.legacy
        fi
    fi
elif [ "$USE_PRECOMMIT" = "yes" ]; then
    echo "USE_PRECOMMIT=yes but python is not enabled. Please set PYTHON_VERSION environment variable"
fi

if [ -n "$PULUMI_VERSION" ]; then
    pulumi plugin install resource docker
    pulumi plugin install resource command
    pulumi plugin install resource aws
    pulumi plugin install resource postgresql
    pulumi plugin install resource mysql
fi
