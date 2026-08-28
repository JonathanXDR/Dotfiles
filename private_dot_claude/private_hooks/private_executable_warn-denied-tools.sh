#!/bin/bash
# SessionStart notice: a bare tool name in a project's permissions.deny (for example
# "Bash" rather than "Bash(rm *)") withdraws that tool from the session schema, so it is
# neither callable nor listed as a deferred tool. Deny also outranks allow at every
# precedence level below admin policy. Absent this notice the gap reads as a Claude Code
# fault, and a whole session can go into rediscovering the cause.

payload=$(cat)

# The settings files are JSON, and separating a bare deny rule from a scoped one needs a
# real parser. Stay silent rather than guess.
command -v jq >/dev/null 2>&1 || exit 0

# Claude Code resolves project settings from the working directory and does not walk up
# to the repository root, so a session started in a subdirectory never loads them. Look
# in the same single place, or the notice would fire where the denial does not apply.
project=$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$project" ] || project=${CLAUDE_PROJECT_DIR:-$PWD}

findings=""
for name in settings.json settings.local.json; do
  file=$project/.claude/$name
  [ -f "$file" ] || continue

  # Scoped rules such as Bash(git push *) constrain a command without withdrawing the
  # tool. Those are ordinary guards, so only bare names are reported.
  denied=$(jq -r '
    [ .permissions.deny // [] | .[]
      | select(test("^(Bash|Read|Edit|Write|NotebookEdit|Glob|Grep|Task|Agent|WebFetch|WebSearch)$")) ]
    | join(", ")' "$file" 2>/dev/null)

  [ -n "$denied" ] && findings="$findings$file denies: $denied"$'\n'
done

[ -n "$findings" ] || exit 0

# The same text reaches the user as a notice and Claude as context. The tools are gone
# either way by now. The point is that neither party spends the session on the mystery.
jq -n --arg f "$findings" '
  "Project settings removed core tools from this session.\n" + $f +
  "No allow rule or permission mode restores them. Starting the session from a subdirectory opts out, since project settings load from the working directory."
  | {
      systemMessage: .,
      hookSpecificOutput: { hookEventName: "SessionStart", additionalContext: . }
    }'
