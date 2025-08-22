#!/usr/bin/env bash

export ALWAYS_PROXY_PROBE=${ALWAYS_PROXY_PROBE:-false}
export PROXY_PROTOCOL=${PROXY_PROTOCOL:-http}
export PROXY_HOST=${PROXY_HOST:-localhost}
export PROXY_PORT=${PROXY_PORT:-8080}
export NOPROXY=${NOPROXY:-localhost,127.0.0.1}

export NTLM_CREDENTIALS=${NTLM_CREDENTIALS}

export BROWSER=""
export DEFAULT_USER="$(whoami)"

# Add more things to PATH only specific to this specific system
PATH_ADD=""

# This seems to cause some error with the zsh syntax highlighting
# AUTOSTART_SSH_AGENT="true"
