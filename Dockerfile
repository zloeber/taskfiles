FROM python:3.12.1-bookworm
USER root:root

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    PIP_NO_INPUT=1

WORKDIR /home/appuser
COPY --chown=appuser:appuser ./ ./

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
  && rm -rf /var/lib/apt/lists/* \
#  && curl -o /usr/local/share/ca-certificates/some_additional_cert_to_trust.crt http://crl.domain.local/pki/some_additional_cert_to_trust.crt \
  && update-ca-certificates \
  && chown -R appuser.appuser /home/appuser \
  && curl -o /tmp/powershell.deb https://packages.microsoft.com/config/debian/11/packages-microsoft-prod.deb \
  && dpkg -i /tmp/powershell.deb \
  && apt-get update \
  && apt-get install --no-install-recommends -y powershell \
  && rm -rf /var/lib/apt/lists/* \
  && pwsh -Command Install-Module powershell-yaml -Force \
  && rm -rf /tmp/*

USER appuser

RUN ./configure.sh \
    && echo "source ~/.asdf/asdf.sh" >> ./.bashrc

COPY --chown=appuser:appuser ./config/.zshrc /home/appuser
COPY --chown=appuser:appuser ./config/.p10k.zsh /home/appuser

SHELL [ "/bin/zsh" ]
