# load zgenom
ZGENOM_DIR="${HOME}/.zgenom"

[[ -d "$ZGENOM_DIR" ]] || git clone https://github.com/jandamm/zgenom.git --depth=1 "$ZGENOM_DIR"

source "$ZGENOM_DIR/zgenom.zsh"

# Check for plugin and zgenom updates every 7 days
# This does not increase the startup time.
zgenom autoupdate

ZGENOM_RESET_ON_CHANGE=(
  ${ZDOTDIR:-$HOME}/.zshrc
  ${ZDOTDIR:-$HOME}/.zshrc.local
)

# Install mise
if ! command -v mise &>/dev/null; then
  curl https://mise.run | sh
  eval "$(${HOME}/.local/bin/mise activate zsh)"
else
  eval "$(mise activate zsh)"
fi

eval "$(mise hook-env -s zsh)"

if [[ ! -f ~/.config/mise/config.toml ]]; then
  echo "No mise.toml found, creating one"
  mise use -g task
  mise use -g fzf
fi

export FZF_BASE=$(mise where fzf)

# if the init script doesn't exist then get to it!
if ! zgenom saved; then
    echo "Creating a zgenom save"

    zgenom oh-my-zsh

    # plugins
    zgenom oh-my-zsh plugins/git
    zgenom oh-my-zsh plugins/sudo
    zgenom oh-my-zsh plugins/docker
    zgenom oh-my-zsh plugins/terraform
    zgenom oh-my-zsh plugins/aws
    zgenom oh-my-zsh plugins/fzf
    zgenom oh-my-zsh plugins/vault
    
    ## These two like to fork up my path for whatever reason (jerks)
    #zgenom oh-my-zsh plugins/direnv
    
    zgenom oh-my-zsh plugins/command-not-found
    zgenom oh-my-zsh plugins/helm
    zgenom oh-my-zsh plugins/kubectl
    zgenom oh-my-zsh plugins/colored-man-pages
    zgenom oh-my-zsh plugins/history
    zgenom oh-my-zsh plugins/ssh-agent

    # Install ohmyzsh osx plugin if on macOS
    [[ "$(uname -s)" = Darwin ]] && zgenom ohmyzsh plugins/macos

    zgenom load zsh-users/zsh-history-substring-search
    zgenom load zsh-users/zsh-syntax-highlighting
    zgenom load unixorn/autoupdate-zgenom
    zgenom load lincheney/fzf-tab-completion

    # completions
    zgenom load zsh-users/zsh-completions
    zgenom load zsh-users/zsh-autosuggestions

    # theme
    zgenom load romkatv/powerlevel10k powerlevel10k
    zgenom load "${HOME}/_compdir/_task" --completion

    # save all to init script
    zgenom save

    # Compile your zsh files
    zgenom compile "$HOME/.zshrc"
fi

# Source in customizations here
[[ ! -f "${HOME}/.zshrc.local" ]] || source ${HOME}/.zshrc.local

# Enable Powerlevel10k instant prompt.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block, everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f "${HOME}/.p10k.zsh" ]] || source "${HOME}/.p10k.zsh"

# if [ -f $HOME/.profile ]; then
#   source $HOME/.profile
# fi

autoload -Uz compinit
compinit

export HISTFILE="$HOME/.zsh_history"
export PATH="/usr/local/sbin:$PATH"
# export CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
# export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
# export HTTPLIB2_CA_CERTS=/etc/ssl/certs/ca-certificates.crt
# export OPENSSL_CONF=/usr/local/etc/openssl@3/openssl.cnf
# export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt

case ":$PATH:" in
  *":${HOME}/.local/bin:"*) ;;
  *) export PATH="$PATH:${HOME}/.local/bin" ;;
esac

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
