# Amazon Q pre block. Keep at the top of this file.
[[ -f "${HOME}/.local/share/amazon-q/shell/zshrc.pre.zsh" ]] && builtin source "${HOME}/.local/share/amazon-q/shell/zshrc.pre.zsh"
#
# .zshrc is sourced in interactive shells.
# It should contain commands to set up aliases,
# functions, options, key bindings, etc.
#

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

if [ -f $HOME/.local/bin/mise ]; then
  eval "$(${HOME}/.local/bin/mise activate zsh)"
  eval "$(mise hook-env -s zsh)"
  mise use fzf
  export FZF_BASE=$(mise where fzf)
fi

# if the init scipt doesn't exist then get to it!
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

autoload -U compinit
compinit

#allow tab completion in the middle of a word
setopt COMPLETE_IN_WORD

export HISTFILE="$HOME/.zsh_history"

case ":$PATH:" in
  *":${HOME}/.local/bin:"*) ;;
  *) export PATH="$PATH:${HOME}/.local/bin" ;;
esac

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

autoload -Uz compinit && compinit
autoload bashcompinit && bashcompinit
complete -C '/usr/local/bin/aws_completer' aws

case ":$PATH:" in
  *":${HOME}/.local/bin:"*) ;;
  *) export PATH="$PATH:${HOME}/.local/bin" ;;
esac
autoload -Uz compinit && compinit
autoload bashcompinit && bashcompinit


case ":$PATH:" in
  *":${HOME}/.local/bin:"*) ;;
  *) export PATH="$PATH:${HOME}/.local/bin" ;;
esac

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
eval "$(${HOME}/.local/bin/mise activate zsh)"
#export PROMPT='%1~ %# '

# Amazon Q post block. Keep at the bottom of this file.
[[ -f "${HOME}/.local/share/amazon-q/shell/zshrc.post.zsh" ]] && builtin source "${HOME}/.local/share/amazon-q/shell/zshrc.post.zsh"