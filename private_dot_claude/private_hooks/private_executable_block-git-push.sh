#!/bin/bash
# PreToolUse guard: Claude Code may only push when the user explicitly asked for it.
# Claude Code pipes the tool call to stdin as JSON and treats exit code 2 as a block,
# with stderr shown to Claude as the reason. The "if" filter in settings.json is only
# a fast path: Claude Code spawns the hook conservatively for commands its rule parser
# cannot decompose, so this script inspects the actual command and decides itself.

payload=$(cat)

# jq scopes the checks to tool_input.command, so free text elsewhere in the payload
# (such as the tool call description) can neither trigger nor bypass the guard.
# Without jq the raw payload is a coarser stand-in that can only over-block, because
# the override below anchors to the start of a line and JSON never begins with it.
if command -v jq >/dev/null 2>&1; then
  cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // empty')
else
  cmd=$payload
fi

# Splice backslash-newline continuations like the shell does: removed
# entirely, so a continuation inside a word cannot split the subcommand.
nl=$'\n'
cmd=${cmd//\\$nl/}

# Match a git push invocation in any part of a compound command, including flagged
# forms such as git -C <path> push and the subtree porcelain. git stash push stays
# allowed because it never writes to a remote. The check also runs on a copy with
# quoted spans emptied, so a quoted flag argument (git -C "My Project" push) cannot
# hide the push, while quoted text mentions still over-block by design.
scan=$(printf '%s\n' "$cmd" | sed -E "s/(\"[^\"]*\"|'[^']*')//g")
if ! printf '%s\n%s\n' "$cmd" "$scan" | grep -Eq '(^|[^[:alnum:]_./-])git([[:space:]]+-([^[:space:]]|\\ )+([[:space:]]+(\\ |[^-[:space:]])([^[:space:]]|\\ )*)?)*[[:space:]]+(subtree[[:space:]]+)?push([^[:alnum:]_-]|$)'; then
  exit 0
fi

# The override only counts as the first word of the command, exactly as the
# message below instructs. head -1 keeps a token at the start of a later line
# of a multi-line command, or a mere mention elsewhere, from disarming the guard.
if printf '%s\n' "$cmd" | head -1 | grep -Eq '^[[:space:]]*(env[[:space:]]+)?CLAUDE_PUSH_OK=1([[:space:]]|$)'; then
  exit 0
fi

cat >&2 <<'REASON'
Push blocked: pushing requires an explicit user request in the current conversation.
If the user explicitly asked for this push, re-run the exact same command with
CLAUDE_PUSH_OK=1 as its first word to confirm. The guard matches text mentions of
git push too, so if this command does not actually push, the same override applies.
Otherwise report that the commits exist locally and let the user decide when to push.
REASON
exit 2
