osname=$(uname)
export PATH="$PATH:$HOME/.local/bin"
if [ "$osname" == "Darwin" ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi
eval "$(${HOME}/.local/bin/mise activate zsh)"
