#!/usr/bin/env bash

# install mise if not already installed to local path
if [ ! -f ~/.local/bin/mise ]; then
    curl https://mise.run | sh
fi

eval "$(~/.local/bin/mise activate zsh)"

mise install -y

task python:venv python:install

echo ""
echo "Load mise into your path (add to your ~/.zshrc profile to always be available): "
echo '   echo 'eval "$(~/.local/bin/mise activate zsh)"' >> ~/.zshrc'
