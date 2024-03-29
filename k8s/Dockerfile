FROM amd64/ubuntu:latest
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
    software-properties-common dselect zip unzip xz-utils procps less dos2unix jq groff file bash-completion \
    inetutils-ping net-tools dnsutils ssh curl wget telnet-ssl netcat socat ca-certificates gnupg2 git \
    postgresql-client mysql-client

# install dev
RUN \
    --mount=type=cache,target=/var/cache/apt \
    apt-get install -fy --fix-missing --no-install-recommends build-essential make libffi-dev libreadline-dev libncursesw5-dev libssl-dev \
    libsqlite3-dev libgdbm-dev libc6-dev libbz2-dev zlib1g-dev llvm libncurses5-dev liblzma-dev libpq-dev libcurl4-openssl-dev

# install editors and any extra packages user has requested
ARG EXTRA_PACKAGES
RUN \
    --mount=type=cache,target=/var/cache/apt \
    apt-get install -fy --fix-missing --no-install-recommends libncurses5 joe nano vim $EXTRA_PACKAGES

# update default editor
RUN update-alternatives --install /usr/bin/editor editor /usr/bin/vim 80 && \
    update-alternatives --install /usr/bin/editor editor /usr/bin/vi 90

# add some extra locales to system
COPY /etc/locale.gen /etc/locale.gen
RUN LC_ALL=en_US.UTF-8 LC_CTYPE=en_US.UTF-8 LANG=en_US.UTF-8 locale-gen
RUN mkdir -p /usr/local/share/.cache

# intstall python if requested
COPY /root/bin/requirements.txt /root/requirements.txt
ARG PYTHON_VERSION
RUN /bin/bash -c 'if [ -n "${PYTHON_VERSION}" ] ; then \
    apt-get install -fy python3-dev python3-openssl && \
    export PYENV_ROOT=/usr/local/pyenv && \
    curl https://pyenv.run | bash && \
    command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH" && \
    eval "$(pyenv init -)" && \
    eval "$(pyenv virtualenv-init -)" && \
    pyenv install -v $PYTHON_VERSION && \
    pyenv global $PYTHON_VERSION && \
    python -m pip install --upgrade pip && \
    pip install virtualenv pre-commit && \
    pip install -r /root/requirements.txt; \
fi; \
rm /root/requirements.txt; \
'

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
       echo "go x86_64" && \
       curl -fsSL https://golang.org/dl/go${GOLANG_VERSION}.linux-amd64.tar.gz | tar -C /usr/local -xzf -; \
fi'

RUN mkdir -p /usr/local/data
WORKDIR /usr/local/data

# Install websocat
RUN  /bin/bash -c 'set -ex && \
    echo "websocat x86_64" && \
    curl -L "https://github.com/vi/websocat/releases/download/v1.10.0/websocat.x86_64-unknown-linux-musl" -o /usr/local/bin/websocat;\
    chmod +x /usr/local/bin/websocat;'

# Install AWS CLI and SSM plugin
ARG USE_AWS
ARG AWS_VERSION
RUN  /bin/bash -c 'if [ "${USE_AWS}" = "yes" ] ; then \
    echo "aws x86_64" && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWS_VERSION}.zip" -o "awscliv2.zip" && \
    curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb" && \
    curl -o /usr/local/bin/aws-iam-authenticator https://s3.us-west-2.amazonaws.com/amazon-eks/1.21.2/2021-07-05/bin/linux/amd64/aws-iam-authenticator; \
    chmod +x /usr/local/bin/aws-iam-authenticator && \
    unzip -q "awscliv2.zip" && ./aws/install && rm awscliv2.zip && \
    dpkg -i session-manager-plugin.deb && rm ./session-manager-plugin.deb; \
    apt install -fy --fix-missing --no-install-recommends amazon-ecr-credential-helper; \
fi'

RUN mkdir -p /root/bash_history

RUN  mkdir /root/.aws
RUN  chmod 700 /root/.aws
COPY awsls/config.template /root/.aws
COPY awsls/credentials /root/.aws

ARG NODE_VERSION

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


ARG USE_CDK
# cdk is installed as global node cli module
RUN  /bin/bash -c 'if [ "${USE_CDK}" = "yes" ] ; then \
  wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor > /usr/share/keyrings/hashicorp-archive-keyring.gpg; \
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list; \
  apt-get update && apt-get install terraform; \
  . $NVM_DIR/nvm.sh && \
  npm -g i aws-cdk-local@latest aws-cdk@latest cdktf-cli@latest; \
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
RUN dos2unix /postStartCommand.sh /init.sh /etc/profile.d/* /etc/skel/.* /root/bin-extra/aws/*
RUN cp /etc/skel/.bashrc /root/.bashrc

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

# host project will be mounted here
RUN mkdir /workspace
WORKDIR /workspace

# transfer build args to env vars for container

ENV PHP_VERSION=$PHP_VERSION
ENV USE_JAVA=$USE_JAVA
ENV PYTHON_VERSION=$PYTHON_VERSION
ENV GOLANG_VERSION=$GOLANG_VERSION
ENV USE_DOT_NET=$USE_DOT_NET
ENV USE_AWS=$USE_AWS
ENV NODE_VERSION=$NODE_VERSION
ENV USE_BITWARDEN=$USE_BITWARDEN
ENV PULUMI_VERSION=$PULUMI_VERSION

ENV PATH="$PATH:/root/bin:/root/bin-extra:/root/gdc-host"

ENTRYPOINT /init.sh

