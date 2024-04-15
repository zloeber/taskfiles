FROM python:3.12.1-bookworm
USER root:root

ENV LANG=en_US.UTF-8 \
  LANGUAGE=en_US:en \
  PIP_NO_INPUT=1

RUN \
  set -e \
  && apt-get update && apt-get install -y \
  && apt-get --no-install-recommends install -y \
  ca-certificates \
  unzip \
  zip \
  jq \
  sed \
  diffutils \
  coreutils \
  bash \
  git \
  gnupg \
  curl \
  libc6 \
  make \
  libglib2.0-0 \
  openssh-client \
  openssl \
  tar \
  postgresql \
  graphviz \
  zsh \
  wget \
  sudo \
  && rm -rf /var/lib/apt/lists/*

ARG USERNAME=appuser
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Create the user
RUN groupadd --gid $USER_GID $USERNAME \
  && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME -s '/bin/zsh' \
  && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
  && chmod 0440 /etc/sudoers.d/$USERNAME

USER $USERNAME
WORKDIR /home/appuser
COPY --chown=appuser:appuser ./ ./

RUN ./configure.sh

COPY --chown=appuser:appuser ./config/.zshrc /home/appuser
COPY --chown=appuser:appuser ./config/.zshrc.local /home/appuser
COPY --chown=appuser:appuser ./config/.zprofile /home/appuser
COPY --chown=appuser:appuser ./config/.p10k.zsh /home/appuser

SHELL [ "/bin/zsh" ]
