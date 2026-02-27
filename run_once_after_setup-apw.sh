#!/bin/bash
set -euo pipefail

# Start the Apple Passwords CLI daemon if available.
# apw requires the background daemon to serve password lookups for chezmoi templates.

if command -v apw &>/dev/null; then
  echo "Apple Passwords CLI (apw) is available."

  # Check if the daemon is already running
  if ! pgrep -f "apw daemon" &>/dev/null; then
    echo "Starting apw daemon..."
    apw daemon start 2>/dev/null || true
  else
    echo "apw daemon already running."
  fi
else
  echo "apw not found. Install Apple Passwords CLI to enable secret injection."
  echo "See: https://developer.apple.com/documentation/apple_passwords"
fi
