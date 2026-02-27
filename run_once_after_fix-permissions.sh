#!/bin/bash
set -euo pipefail

# Fix warnings from zsh completions about insecure directories
# This removes group-write permissions that cause compaudit warnings

if command -v brew &>/dev/null; then
  BREW_PREFIX="$(brew --prefix)"
  ZSH_COMP_DIR="${BREW_PREFIX}/share/zsh-completions"
  ZSH_SITE_FUNC="${BREW_PREFIX}/share/zsh/site-functions"

  for dir in "$ZSH_COMP_DIR" "$ZSH_SITE_FUNC"; do
    if [[ -d "$dir" ]]; then
      chmod g-w "$dir" 2>/dev/null || true
    fi
  done
fi

echo "Zsh completion directory permissions fixed."
