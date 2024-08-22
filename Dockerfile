FROM ubuntu:24.04
# only effects build time and and makes it so we dont have to specify it every apt install
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# turn off documentation
COPY /etc/dpkg/dpkg.conf.d/01_nodoc /etc/dpkg/dpkg.conf.d/01_nodoc

# update system
RUN \
    --mount=type=cache,target=/var/cache/apt \
    apt-get update -y --fix-missing --no-install-recommends && apt-get -y --fix-missing --no-install-recommends upgrade
# install core
RUN \
    --mount=type=cache,target=/var/cache/apt \
    apt-get install -fy --fix-missing --no-install-recommends locales apt-transport-https \
    software-properties-common dselect zip unzip xz-utils zstd procps less dos2unix jq groff file bash-completion \
    inetutils-ping net-tools dnsutils ssh curl wget telnet-ssl netcat-traditional socat ca-certificates gnupg2 git \
    postgresql-client mysql-client fzf

# install dev
RUN \
    --mount=type=cache,target=/var/cache/apt \
    apt-get install -fy --fix-missing --no-install-recommends build-essential make libffi-dev libreadline-dev libncurses-dev libssl-dev \
    libsqlite3-dev libgdbm-dev libc6-dev libbz2-dev zlib1g-dev llvm liblzma-dev libpq-dev libcurl4-openssl-dev pkg-config

# install editors and any extra packages user has requested
ARG EXTRA_PACKAGES
RUN \
    --mount=type=cache,target=/var/cache/apt \
    apt-get install -fy --fix-missing --no-install-recommends joe nano vim $EXTRA_PACKAGES

# update default editor
RUN update-alternatives --install /usr/bin/editor editor /usr/bin/vim 80 && \
    update-alternatives --install /usr/bin/editor editor /usr/bin/vi 90

# add some extra locales to system
COPY /etc/locale.gen /etc/locale.gen
RUN LC_ALL=en_US.UTF-8 LC_CTYPE=en_US.UTF-8 LANG=en_US.UTF-8 locale-gen
RUN mkdir -p /usr/local/share/.cache

RUN mkdir -p /usr/local/data
WORKDIR /usr/local/data

# install docker
RUN install -m 0755 -d /etc/apt/keyrings
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
RUN chmod a+r /etc/apt/keyrings/docker.gpg
RUN echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
RUN apt-get update
RUN apt-get install -fy --fix-missing  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Install websocat
RUN  /bin/bash -c 'set -ex && \
    ARCH=`uname -m` && \
    PLATFORM=`uname -s | tr '[:upper:]' '[:lower:]'` && \
    if [ "$ARCH" = "x86_64" ]; then \
       echo "websocat x86_64" && \
       curl -L "https://github.com/vi/websocat/releases/download/v1.10.0/websocat.x86_64-unknown-linux-musl" -o /usr/local/bin/websocat;\
    else \
       echo "websocat assuming ARM" && \
       curl -L "https://github.com/vi/websocat/releases/download/v1.10.0/websocat.arm-unknown-linux-musleabi" -o /usr/local/bin/websocat;\
    fi; \
    chmod +x /usr/local/bin/websocat;'

# install php if requested
ARG PHP_VERSION
RUN /bin/bash -c 'if [ -n "${PHP_VERSION}" ] ; then \
    LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/php && apt update && \
    apt-get install -fy php${PHP_VERSION}-cli php-pear php${PHP_VERSION}-xml php${PHP_VERSION}-curl php${PHP_VERSION}-dev php${PHP_VERSION}-json php${PHP_VERSION}-mysql php${PHP_VERSION}-pgsql php${PHP_VERSION}-sqlite3; \
fi'

ARG USE_JAVA
RUN /bin/bash -c 'if [ "${USE_JAVA}" = "yes" ] ; then \
    apt-get install -fy default-jdk-headless; \
fi'

ARG USE_DOT_NET
RUN /bin/bash -c 'if [ "${USE_DOT_NET}" = "yes" ] ; then \
  wget https://dot.net/v1/dotnet-install.sh -O dotnet-install.sh; \
  chmod +x ./dotnet-install.sh; \
  ./dotnet-install.sh; \
  mkdir /usr/local/dotnet; \
  mv /root/.dotnet/* /usr/local/dotnet; \
fi'

ARG GOLANG_VERSION
RUN /bin/bash -c 'if [ -n "${GOLANG_VERSION}" ] ; then \
    ARCH=`uname -m` && \
    if [ "$ARCH" = "x86_64" ]; then \
       echo "go x86_64" && \
       curl -fsSL https://golang.org/dl/go${GOLANG_VERSION}.linux-amd64.tar.gz | tar -C /usr/local -xzf -; \
    else \
       echo "go assuming ARM" && \
       curl -fsSL https://golang.org/dl/go${GOLANG_VERSION}.linux-arm64.tar.gz | tar -C /usr/local -xzf -; \
    fi; \
fi'

ARG RUST_VERSION
ARG CARGO_EXTRA
RUN  /bin/bash -c 'if [ -n "${RUST_VERSION}" ]; then \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain "${RUST_VERSION}"; \
    source "$HOME/.cargo/env"; \
    rustup completions bash > /etc/bash_completion.d/rustup; \
    if [ -n "${CARGO_EXTRA}" ]; then \
        cargo install ${CARGO_EXTRA}; \
    fi; \
fi'

# intstall python if requested
# install pyenv for backwards compatibility. uv is far better
RUN mkdir -p /build-tmp
COPY /root/bin/requirements.txt /build-tmp/requirements.txt
ARG PYTHON_VERSION
ARG PIP_EXTRA_REQUIREMENTS_TXT
ARG HOST_PROJECT_FOLDER_NAME
COPY tmp/$HOST_PROJECT_FOLDER_NAME-* /build-tmp/
RUN /bin/bash -c 'if [ -n "${PYTHON_VERSION}" ] ; then \
    apt-get install -fy python3-dev python3-openssl && \
    curl -LsSf https://astral.sh/uv/install.sh | sh && \
    source /root/.cargo/env && \
    export PYENV_ROOT=/usr/local/pyenv && \
    curl https://pyenv.run | bash && \
    export PATH="$PYENV_ROOT/bin:$PATH" && \
    ARCH=`uname -m` && \
    if [ "$ARCH" = "x86_64" ]; then \
      echo "python x86_64" && \
      export PY_ARCH="$ARCH"; \
    else \
      echo "python assuming ARM" && \
      export PY_ARCH="aarch64"; \
    fi; \
    echo "Checking for matching binary releases" && \
    curl -sL -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" https://api.github.com/repos/indygreg/python-build-standalone/releases/latest \
      | jq -r ".assets[].browser_download_url" \
      | grep -v "sha256" \
      | grep "$PY_ARCH-unknown-linux-gnu-install_only.tar.gz" \
      | grep "cpython-${PYTHON_VERSION}" > /tmp/download_url.txt; \
    grep "python-build-standalone" /tmp/download_url.txt; \
    if [ $? -eq 0 ]; then \
      echo "Prebuilt python found. Installing" && \
      curl -sL $( cat /tmp/download_url.txt ) | tar -xzv -C /usr/local --strip-components=1 python || exit 1; \
    else \
      echo "Binary version not found, using pyenv for install. Consider using only 2 parts in your PYTHON_VERSION example: 3.11 instead of 3.11.5" && \
      eval "$(pyenv init -)"; \
      eval "$(pyenv virtualenv-init -)" && \
      pyenv install -v $PYTHON_VERSION && \
      pyenv global $PYTHON_VERSION && \
      python -m pip install --upgrade pip; \
    fi; \
    pip install -r /build-tmp/requirements.txt && \
    if [ -n "${PIP_EXTRA_REQUIREMENTS_TXT}" ]; then \
        pip install -r "/build-tmp/${HOST_PROJECT_FOLDER_NAME}-pip-extra-requirements.txt" || exit 1; \
    fi; \
fi; \
'

# Install AWS CLI and SSM plugin
ARG USE_AWS
ARG AWS_VERSION
RUN  /bin/bash -c 'if [ "${USE_AWS}" = "yes" ] ; then \
    set -ex && \
    ARCH=`uname -m` && \
    if [ "$ARCH" = "x86_64" ]; then \
       echo "aws x86_64" && \
       curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWS_VERSION}.zip" -o "awscliv2.zip" && \
       curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb" && \
       curl -o /usr/local/bin/aws-iam-authenticator https://s3.us-west-2.amazonaws.com/amazon-eks/1.21.2/2021-07-05/bin/linux/amd64/aws-iam-authenticator; \
    else \
       echo "aws assuming ARM" && \
       curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64-${AWS_VERSION}.zip" -o "awscliv2.zip" && \
       curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_arm64/session-manager-plugin.deb" -o "session-manager-plugin.deb" && \
       curl -o /usr/local/bin/aws-iam-authenticator https://s3.us-west-2.amazonaws.com/amazon-eks/1.21.2/2021-07-05/bin/linux/arm64/aws-iam-authenticator; \
    fi; \
    chmod +x /usr/local/bin/aws-iam-authenticator && \
    unzip -q "awscliv2.zip" && ./aws/install && rm awscliv2.zip && \
    dpkg -i session-manager-plugin.deb && rm ./session-manager-plugin.deb; \
    apt install -fy --fix-missing --no-install-recommends amazon-ecr-credential-helper; \
fi'

RUN mkdir -p /root/.docker
COPY docker-config.json /root/.docker/config.json

ARG NODE_VERSION
ARG USE_BITWARDEN

# if bitwarden is enabled so will node
ENV NVM_DIR /usr/local/nvm
RUN  /bin/bash -c 'if [ -n "${NODE_VERSION}" ]; then \
    mkdir -p "$NVM_DIR" && \
    curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash && \
    . $NVM_DIR/nvm.sh && \
    nvm install "${NODE_VERSION}" && \
    nvm alias default "${NODE_VERSION}" && \
    nvm use default "${NODE_VERSION}" && \
    npm -g i npm@latest yarn npm-check-updates; \
fi'

# bitwarden is installed as global node cli module
RUN  /bin/bash -c 'if [ "${USE_BITWARDEN}" = "yes" ] ; then \
  . $NVM_DIR/nvm.sh && \
  npm -g i @bitwarden/cli; \
fi'

ARG USE_CDK
# cdk is installed as global node cli module
RUN  /bin/bash -c 'if [ "${USE_CDK}" = "yes" ] ; then \
  wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor > /usr/share/keyrings/hashicorp-archive-keyring.gpg; \
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list; \
  . $NVM_DIR/nvm.sh && \
  npm -g i aws-cdk-local@latest aws-cdk@latest; \
fi'

# if pulumi version is set then install pulumi
ARG PULUMI_VERSION
RUN  /bin/bash -c 'if [ -n "${PULUMI_VERSION}" ]; then \
    curl -fsSL https://get.pulumi.com/ | bash -s -- --version $PULUMI_VERSION && \
    mv ~/.pulumi/bin/* /usr/local/bin; \
fi'

COPY /etc/term_colors.sh /etc/term_colors.sh
COPY /etc/profile.d /etc/profile.d/
COPY /etc/skel /etc/skel/
COPY /etc/ssh /etc/ssh/
COPY /etc/bash_completion.d /etc/bash_completion.d
COPY init.sh /init.sh
COPY /root/bin/ /root/bin-extra
COPY postStartCommand.sh /


RUN chmod a+rx -R /init.sh /postStartCommand.sh /root/bin-extra

# fix line endings in case files where copied from windows
RUN dos2unix /postStartCommand.sh /init.sh /etc/profile.d/* /etc/skel/.* /root/bin-extra/aws/* /root/bin-extra/docker/*
RUN cp /etc/skel/.*rc  /root/


WORKDIR /root

# removed temp data folder
RUN rm -rf /usr/local/data

# set default root password
ARG ROOT_PW=ContanersRule
RUN yes "$ROOT_PW" | passwd root

# install extras
RUN \
    --mount=type=cache,target=/var/cache/apt \
    apt-get install -fy --fix-missing --no-install-recommends gettext-base

ARG TERRAFORM_VERSION

# terraform is installed
RUN /bin/bash -c 'if [ -n "${TERRAFORM_VERSION}" ]; then \
    set -ex; \
    ARCH=`uname -m`; \
    if [ "${TERRAFORM_VERSION}" = "latest" ]; then \
        wget -O- https://apt.releases.hashicorp.com/gpg | \
        gpg --dearmor >/usr/share/keyrings/hashicorp-archive-keyring.gpg; \
        echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
        https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list; \
        apt-get update && apt-get install -y terraform; \
    else \
        if [ "$ARCH" = "x86_64" ]; then \
           echo "aws x86_64"; \
           curl "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" -o terraform.zip; \
        else \
           echo "aws assuming ARM"; \
           curl "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_arm64.zip" -o terraform.zip; \
        fi; \
        unzip -q terraform.zip; \
        mv terraform /usr/local/bin; \
        rm terraform.zip; \
    fi; \
    . $NVM_DIR/nvm.sh && \
    npm -g i cdktf-cli@latest; \
fi'

# host project will be mounted here
RUN mkdir /workspace
WORKDIR /workspace

# transfer build args to env vars for container
ENV PHP_VERSION=$PHP_VERSION
ENV USE_JAVA=$USE_JAVA
ENV PYTHON_VERSION=$PYTHON_VERSION
ENV PIP_EXTRA_REQUIREMENTS_TXT=$PIP_EXTRA_REQUIREMENTS_TXT
ENV GOLANG_VERSION=$GOLANG_VERSION
ENV USE_DOT_NET=$USE_DOT_NET
ENV USE_AWS=$USE_AWS
ENV NODE_VERSION=$NODE_VERSION
ENV RUST_VERSION=$RUST_VERSION
ENV CARGO_EXTRA=$CARGO_EXTRA
ENV USE_BITWARDEN=$USE_BITWARDEN
ENV PULUMI_VERSION=$PULUMI_VERSION
ENV TERRAFORM_VERSION=$TERRAFORM_VERSION

ENV PATH="$PATH:/root/bin:/root/bin-extra:/root/bin-extra/docker:/root/gdc-host"

ENTRYPOINT /init.sh

