#!/bin/bash
# PreToolUse guard: Claude Code may only push when the user explicitly asked for it.
# Claude Code pipes the tool call to stdin as JSON and treats exit code 2 as a block,
# with stderr shown to Claude as the reason. The "if" filter in settings.json is only
# a fast path: Claude Code spawns the hook conservatively for commands its rule parser
# cannot decompose, so this script inspects the actual command and decides itself.

payload=$(cat)

# jq scopes the checks to tool_input.command, so free text elsewhere in the payload
# (such as the tool call description) can neither trigger nor bypass the guard.
# Without jq the raw payload is a coarser but still safe approximation.
if command -v jq >/dev/null 2>&1; then
  cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // empty')
else
  cmd=$payload
fi

# Match a git push invocation in any part of a compound command, including flagged
# forms such as git -C <path> push and git -c <key>=<value> push.
if ! printf '%s\n' "$cmd" | grep -Eq '(^|[^[:alnum:]_./-])git([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+push([^[:alnum:]_-]|$)'; then
  exit 0
fi

case "$cmd" in
*CLAUDE_PUSH_OK=1*) exit 0 ;;
esac

cat >&2 <<'REASON'
Push blocked: pushing requires an explicit user request in the current conversation.
If the user explicitly asked for this push, re-run the exact same command prefixed
with CLAUDE_PUSH_OK=1 to confirm. Otherwise report that the commits exist locally
and let the user decide when to push.
REASON
exit 2
