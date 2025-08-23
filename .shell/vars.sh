#!/usr/bin/env bash

# ---------------------------- Proxy configuration --------------------------- #

export ALWAYS_PROXY_PROBE=${ALWAYS_PROXY_PROBE:-false}
export PROXY_PROTOCOL=${PROXY_PROTOCOL:-http}
export PROXY_HOST=${PROXY_HOST:-localhost}
export PROXY_PORT=${PROXY_PORT:-8080}
export NOPROXY=${NOPROXY:-localhost,127.0.0.1}

# ----------------------------------- Auth ----------------------------------- #

export NTLM_CREDENTIALS=${NTLM_CREDENTIALS}

# ----------------------------------- Misc ----------------------------------- #

export DEFAULT_USER=$USER

# Add more things to PATH only specific to this specific system
# This will be automatically added to PATH by paths.sh
export PATH_ADD=""

# This seems to cause some error with the zsh syntax highlighting
# AUTOSTART_SSH_AGENT="true"