#!/usr/bin/env bash

# check for mise
if ! command -v mise &>/dev/null; then
    echo "Please install mise first (run 'curl https://mise.run | sh')"
    echo ""
    echo "Load mise into your path (add to your ~/.zshrc profile to always be available): "
    echo '   echo 'eval "$(~/.local/bin/mise activate zsh)"' >> ~/.zshrc'
    exit 1
else
    eval "$(mise activate bash)"
fi

mise install -y

task python:venv python:install
