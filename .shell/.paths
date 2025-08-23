#!/usr/bin/env bash

# ----------------------------- Core System Paths ---------------------------- #

# Local user binaries
path:add "$HOME/.local/bin"

# -------------------------- Development Tool Paths -------------------------- #

# Bun JavaScript runtime
path:add "$BUN_INSTALL/bin"

# Ruby Version Manager
path:add "$HOME/.rvm/bin"

# Console Ninja (browser debugger)
path:add "$HOME/.console-ninja/.bin"

# Python Framework (macOS specific)
path:add "/Library/Frameworks/Python.framework/Versions/Current/bin"

# JetBrains Toolbox scripts
path:add "/Users/$USER/Library/Application Support/JetBrains/Toolbox/scripts"

# Coursier (Scala package manager)
path:append "/Users/$USER/Library/Application Support/Coursier/bin"

# ----------------- Package Manager & Runtime Initializations ---------------- #

# Homebrew initialization (macOS)
if [[ -x "/opt/homebrew/bin/brew" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x "/usr/local/bin/brew" && $(arch) == "i386" ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# Python version management
if command -v pyenv >/dev/null 2>&1; then
  eval "$(pyenv init --path)"
fi

# Node Version Manager
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  source "$NVM_DIR/nvm.sh"
elif [[ -s "/opt/homebrew/opt/nvm/nvm.sh" ]]; then
  source "/opt/homebrew/opt/nvm/nvm.sh"
fi

# NVM bash completion
if [[ -s "$NVM_DIR/bash_completion" ]]; then
  source "$NVM_DIR/bash_completion"
elif [[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ]]; then
  source "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"
fi

# Ruby Version Manager (load as function)
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"

# ---------------------- System-specific PATH additions ---------------------- #

# Add system-specific paths from environment variable
[[ -n "${PATH_ADD}" ]] && path:append "${PATH_ADD}"