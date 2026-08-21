#!/bin/bash
# PreToolUse guard: block git commands that silently destroy uncommitted work.
# Covered: git reset --hard, forced git clean, worktree-discarding checkout
# and restore. Same contract as block-git-push.sh: exit 2 blocks the call,
# stderr becomes the reason, and an explicit user request is confirmed by
# re-running the command with CLAUDE_DESTRUCTIVE_OK=1 as its first word.

payload=$(cat)

if command -v jq >/dev/null 2>&1; then
  cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // empty')
else
  cmd=$payload
fi

# Splice backslash-newline continuations like the shell does: removed
# entirely, so a continuation inside a word cannot split the subcommand.
nl=$'\n'
cmd=${cmd//\\$nl/}

# Matching runs on a copy with heredoc bodies dropped and quoted spans
# emptied. Heredoc bodies are data fed to a program, not commands, so
# documentation text in them cannot trip the guard (and their quotes cannot
# pair with real ones). Quotes are consumed left to right, whichever kind
# opens first, mirroring the shell. The tradeoff: a destructive flag hidden
# inside quotes or a command a heredoc feeds to an interpreter is missed,
# which shades into deliberate bypass and stays out of scope for a
# best-effort guard.
scan=$(printf '%s\n' "$cmd" | awk '
  # One left-to-right pass per line: quoted spans are dropped with correct
  # pairing, heredoc markers (quoted or not) survive as <<TAG, a here-string
  # <<< or a << inside quotes is not a marker. Arithmetic $(( )) spans are
  # consumed whole so their shifts never look like markers. Skipped lines
  # are held. If the terminator never appears the parse was wrong, and the
  # held lines are re-emitted so a live command is never silently dropped.
  function stripline(s,   out, i, c, c2, q, t, n) {
    out = ""; q = ""; n = length(s); i = 1
    while (i <= n) {
      c = substr(s, i, 1)
      if (q != "") { if (c == q) q = ""; i++; continue }
      if (c == "\"" || c == "\047") { q = c; i++; continue }
      if (c == "$" && substr(s, i + 1, 2) == "((") {
        i += 3
        while (i <= n && substr(s, i, 2) != "))") i++
        if (i <= n) i += 2
        continue
      }
      if (c == "<" && substr(s, i + 1, 1) == "<") {
        if (substr(s, i + 2, 1) == "<") { i += 3; continue }
        out = out "<<"; i += 2
        if (substr(s, i, 1) == "-") { out = out "-"; i++ }
        while (substr(s, i, 1) == " " || substr(s, i, 1) == "\t") i++
        t = ""; c2 = substr(s, i, 1)
        if (c2 == "\"" || c2 == "\047") { t = c2; i++ }
        while (i <= n && substr(s, i, 1) ~ /[A-Za-z0-9_-]/) { out = out substr(s, i, 1); i++ }
        if (t != "" && substr(s, i, 1) == t) i++
        continue
      }
      out = out c; i++
    }
    return out
  }
  skip != "" {
    line = $0
    if (dash) sub(/^\t+/, "", line)
    if (line == skip) { skip = ""; h = 0 } else { held[++h] = $0 }
    next
  }
  {
    stripped = stripline($0)
    if (match(stripped, /<<-?[A-Za-z_][A-Za-z0-9_-]*/) &&
        (RSTART == 1 || substr(stripped, RSTART - 1, 1) ~ /[[:space:]]/)) {
      tag = substr(stripped, RSTART, RLENGTH)
      dash = (tag ~ /^<<-/) ? 1 : 0
      sub(/^<<-?/, "", tag)
      skip = tag
    }
    print stripped
  }
  END { if (skip != "") for (j = 1; j <= h; j++) print stripline(held[j]) }')

# git plus optional flag tokens (with arguments) before the subcommand, the
# same prefix the push guard uses. Backslash-escaped spaces stay inside a
# token, so "git -C My\ Project reset" is still one prefix chain.
gitpre='(^|[^[:alnum:]_./-])git([[:space:]]+-([^[:space:]]|\\ )+([[:space:]]+(\\ |[^-[:space:]])([^[:space:]]|\\ )*)?)*[[:space:]]+'

# Flag tokens end at whitespace, a separator, a redirect, or a closing
# subshell, so a pathspec such as "-file.txt" after -- is never read as a
# flag and "(cd x && git reset --hard)" still terminates the token.
end='([[:space:];&|<>)`]|$)'

# Two derived views. The pathview copy removes redirect expressions, so a
# redirect target (./out.log, /dev/null) is never read as a pathspec and a
# redirect before " -- " cannot hide one. The flagview copy truncates each
# segment at its " -- " end-of-options marker, so a pathspec resembling a
# flag (a file named -f) is never read as one.
pathview=$(printf '%s\n' "$scan" | sed -E 's/[0-9]*[<>]{1,3}[[:space:]]*(&[0-9]*|[^[:space:];&|)]*)//g')
flagview=$(printf '%s\n' "$scan" | sed -E 's/ -- [^;&|)]*//g')

reason=""
if printf '%s\n' "$flagview" | grep -Eq "${gitpre}reset[^;&|]*--hard${end}"; then
  reason="git reset --hard discards uncommitted changes"
# Only -f/--force makes clean destructive: git refuses -x/-X/-d without it.
elif printf '%s\n' "$flagview" | grep -Eq "${gitpre}clean[^;&|]*([[:space:]]-[a-zA-Z]*f[a-zA-Z]*|--force)${end}"; then
  reason="forced git clean deletes untracked files"
elif printf '%s\n' "$flagview" | grep -Eq "${gitpre}checkout[^;&|]*([[:space:]]-[a-zA-Z]*f[a-zA-Z]*|--force)${end}"; then
  reason="forced git checkout discards uncommitted changes"
elif printf '%s\n' "$pathview" | grep -Eq "${gitpre}checkout[^;&|]*[[:space:]]--([[:space:]]|$)" ||
     printf '%s\n' "$pathview" | grep -Eq "${gitpre}checkout[^;&|]*[[:space:]]\.\.?(/[^[:space:];&|)]*)?${end}"; then
  reason="git checkout with a pathspec overwrites uncommitted changes"
elif printf '%s\n' "$scan" | grep -Eq "${gitpre}restore([^;&|]|$)"; then
  # Judge each command segment on its own flags: --staged on one restore must
  # not disarm the guard for a plain restore elsewhere in a compound command.
  # -S/-W are the short forms of --staged/--worktree, also in combined flags.
  # Flags live before the segment's " -- " marker. Pathspecs after it (a
  # file named --help or -SW) are not flags.
  while IFS= read -r seg; do
    printf '%s\n' "$seg" | grep -Eq "${gitpre}restore${end}" || continue
    segflags=${seg%% -- *}
    printf '%s\n' "$segflags" | grep -Eq -- '--help([[:space:]]|$)|[[:space:]]-h([[:space:]]|$)' && continue
    if ! printf '%s\n' "$segflags" | grep -Eq "${gitpre}restore[^;&|]*(--staged|[[:space:]]-[A-Za-z]*S[A-Za-z]*)${end}" ||
       printf '%s\n' "$segflags" | grep -Eq "${gitpre}restore[^;&|]*(--worktree|[[:space:]]-[A-Za-z]*W[A-Za-z]*)${end}"; then
      reason="git restore overwrites uncommitted changes in the worktree"
    fi
  done <<<"$(printf '%s\n' "$scan" | tr ';&|' '\n')"
fi

[ -z "$reason" ] && exit 0

# head -1 pins the override to the command's first word: a token at the start
# of a later line of a multi-line command does not disarm the guard.
if printf '%s\n' "$cmd" | head -1 | grep -Eq '^[[:space:]]*(env[[:space:]]+)?CLAUDE_DESTRUCTIVE_OK=1([[:space:]]|$)'; then
  exit 0
fi

cat >&2 <<REASON
Destructive git command blocked: $reason.
If the user explicitly asked for this, re-run the exact same command with
CLAUDE_DESTRUCTIVE_OK=1 as its first word to confirm. Otherwise choose a
non-destructive alternative (git stash, git restore --staged, a new branch)
or ask the user first.
REASON
exit 2
