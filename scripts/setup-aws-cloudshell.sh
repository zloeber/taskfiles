#!/usr/bin/env bash

# Start zsh on startup. No chsh :(
[[ $AWS_EXECUTION_ENV == "CloudShell" ]] && echo "In CloudShell, no need to install git/zsh" || sudo yum -y install git zsh && echo zsh >>~/.bashrc

# Install mise
# check for mise
if ! command -v mise &>/dev/null; then
  curl https://mise.run | sh
  eval "$(${HOME}/.local/bin/mise activate bash)"
else
  eval "$(mise activate bash)"
fi

if [[ ! -f ~/mise.toml ]]; then
  echo "No mise.toml found, creating one"
  mise init
  mise use task
  mise use fzf
fi

mise install -y
