#!/usr/bin/env bash

# Clone the repo then run this script
# git clone https://github.com/zloeber/taskfiles.git
# cd taskfiles
# ./scripts/setup-aws-cloudshell.sh

# Start zsh on startup. No chsh :(
[[ $AWS_EXECUTION_ENV == "CloudShell" ]] && echo "In CloudShell, no need to install git/zsh" || sudo yum -y install git zsh && echo zsh >>~/.bashrc

# Install mise
if ! command -v mise &>/dev/null; then
  curl https://mise.run | sh
  eval "$(${HOME}/.local/bin/mise activate bash)"
else
  eval "$(mise activate bash)"
fi

if [[ ! -f ~/.config/mise/config.toml ]]; then
  echo "No mise.toml found, creating one"
  mise use -g task
  mise use -g fzf
fi

# install any requirements
mise install -y
