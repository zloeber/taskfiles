#!/bin/bash

# install task binary to local path
if [ ! -f ~/.asdf/asdf.sh ]; then
    git clone https://github.com/asdf-vm/asdf.git ~/.asdf
fi

. ~/.asdf/asdf.sh

cat .tool-versions | awk '{print $1;}' | xargs -I % sh -c 'asdf plugin add %'

asdf install

task python:venv python:install secrets

echo ""
echo "Load asdf into your path (add to your ~/.zshrc profile to always be available): "
echo "   source ~/.asdf/asdf.sh"
