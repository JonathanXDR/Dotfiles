# Global editor
export EDITOR="nano"
export KUBE_EDITOR="nano"

# Tool dirs (inits elsewhere)
export BUN_INSTALL="$HOME/.bun"
export NVM_DIR="$HOME/.nvm"
export SDKMAN_DIR="$HOME/.sdkman"
export KUBECONFIG_PATH="$HOME/.kube"

export RESOLV='/etc/resolv.conf'
export NPM_GLOBALS="$HOME/.npm.globals"

# Dotfiles metadata
export DOTFILES_REPO_PATH="$HOME/Developer/Git/GitHub/Dotfiles"
export DOTFILES_CONFIG_PATH="$HOME/Documents/General/Developer/configs/dotfiles"

# PATH (build once, mind order)
path_add() { [[ -d "$1" ]] && case ":$PATH:" in *":$1:"*) ;; *) export PATH="$1:$PATH";; esac }

path_add "$BUN_INSTALL/bin"
path_add "$HOME/.rvm/bin"
path_add "$HOME/.console-ninja/.bin"
path_add "/Library/Frameworks/Python.framework/Versions/Current/bin"
path_add "/Users/$USER/Library/Application Support/JetBrains/Toolbox/scripts"
