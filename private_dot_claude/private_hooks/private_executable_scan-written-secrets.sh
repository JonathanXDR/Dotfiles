#!/bin/bash
# PostToolUse guard: scan content Claude just wrote for hardcoded secrets.
# Complements the SonarQube Read and prompt hooks, which never see written
# content. Exit 2 feeds stderr back to Claude so it removes the secret.
# Fails open when the sonar CLI or the file is missing or the scan itself
# errors, matching the fail-open convention of the sonar-installed wrappers.

command -v sonar >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

file=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
[ -f "$file" ] || exit 0

output=$(sonar analyze secrets "$file" 2>&1)
status=$?
# sonar exits 51 when it finds secrets, 0 when clean. Anything else is a CLI
# error (bad path, usage), which fails open like a missing binary would.
[ "$status" -eq 51 ] || exit 0

cat >&2 <<REASON
Secret detected in the file you just wrote. Remove or replace it with a
placeholder or an environment lookup before continuing.

$output
REASON
exit 2
