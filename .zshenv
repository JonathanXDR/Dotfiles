# Global editor

# Make Neovim or the lowest common denominator that's aliased or symlinked to
# the vi command the default editor
export EDITOR="vi"
export KUBE_EDITOR="vi"

# Tool directories & paths
export PATH="$PATH:$HOME/.local/bin"
export BUN_INSTALL="$HOME/.bun"
export NVM_DIR="$HOME/.nvm"
export SDKMAN_DIR="$HOME/.sdkman"
export KUBECONFIG_PATH="$HOME/.kube"

export RESOLV='/etc/resolv.conf'
export NPM_GLOBALS="$HOME/.npm.globals"
export NPM_GLOBALS_LOCK_DIR="$HOME/.npm/_locks"

# Dotfiles metadata
export DOTFILES_REPO_PATH="$HOME/Developer/Git/GitHub/Dotfiles"
export DOTFILES_CONFIG_PATH="$HOME/Documents/General/Developer/configs/dotfiles"

# Docker & Kubernetes configs
export K3S_KUBECONFIG_MODE="644"
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

export DOTNET_CLI_TELEMETRY_OPTOUT=1