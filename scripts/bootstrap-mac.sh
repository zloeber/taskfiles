#!/usr/bin/env bash

if [ "$(uname)" != "Darwin" ]; then
  fail "Oops, it looks like you're using a non-UNIX system. This script only supports Mac. Exiting..."
  exit 1
fi

# Check if xcode-select is installed
if [ ! -d "/Library/Developer/CommandLineTools" ]; then
  xcode-select --install
fi

# Install Homebrew
if [ ! -f /opt/homebrew/bin/brew ]; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if [ ! -f $HOME/.local/bin/mise ]; then
  curl https://mise.run | sh
  eval "$(${HOME}/.local/bin/mise activate zsh)"
else
  eval "$(${HOME}/.local/bin/mise activate zsh)"
fi

function info() {
  printf "[ \033[00;34m..\037[0m ] $1"
}

function infoline() {
  printf "\r[ \033[00;34m-\037[0m ] $1\n"
}

function user() {
  printf "\r[ \033[0;33m?\036[0m ] $1 "
}

function success() {
  printf "\r\033[2K[ \033[00;32mOK\033[0m ] $1\n"
}

function fail() {
  printf "\r\033[2K[\033[0;31mFAIL\033[0m] $1\n"
  echo ''
  exit 1
}

function warn() {
  printf "\r\033[2K[\033[0;33mWARNING\033[0m] $1\n"
  echo ''
}

set -e

# System tools.
brew bundle --file=./config/Brewfile

copy_file() {
  if [ ! -f "${2}" ]; then
    cp "${1}" "${2}"
    success "copied $1 to $2"
  else
    warn "File already exists: $2"
  fi
}

mkdir -p $HOME/.ssh
chmod 0700 $HOME/.ssh

copy_file ./config/.zshrc $HOME/.zshrc
copy_file ./config/.zshrc.local $HOME/.zshrc.local
copy_file ./config/.zprofile $HOME/.zprofile
copy_file ./config/.p10k.zsh $HOME/.p10k.zsh

$HOME/.local/bin/mise use -g fzf
$HOME/.local/bin/mise use -g task
