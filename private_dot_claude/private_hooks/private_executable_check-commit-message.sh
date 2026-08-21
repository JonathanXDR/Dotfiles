#!/bin/bash
# PreToolUse guard: validate the commit message Claude is about to create.
# Checks the Conventional Commits subject shape (lowercase type) and rejects
# Claude attribution trailers. Bodies and footers stay unrestricted so
# repository conventions keep working. The check binds only the agent: it
# fails open whenever the message cannot be extracted from the command
# (editor-based commits, exotic quoting), and CLAUDE_COMMIT_OK=1 as the
# command's first word acknowledges a repository whose documented commit
# convention intentionally differs.

payload=$(cat)

if command -v jq >/dev/null 2>&1; then
  cmd=$(printf '%s' "$payload" | jq -r '.tool_input.command // empty')
else
  exit 0
fi

# The shell removes backslash-newline entirely, so splice with nothing.
nl=$'\n'
cmd=${cmd//\\$nl/}

# Gate on a copy with heredoc bodies dropped and quoted spans emptied: the
# command's structure, not message or documentation text, decides whether
# this is a git commit invocation. Quotes are consumed left to right,
# whichever kind opens first, mirroring the shell. Extraction below still
# reads the real quotes from $cmd.
# One left-to-right pass per line: quoted spans are dropped with correct
# pairing, heredoc markers (quoted or not) survive as <<TAG, a here-string
# <<< or a << inside quotes is not a marker, and arithmetic $(( )) spans are
# consumed whole so their shifts never look like markers. Skipped lines are
# held; if the terminator never appears the parse was wrong, and the held
# lines are re-emitted so a live command is never silently dropped. With
# raw=1 the heredoc bodies are still dropped but each surviving line is
# emitted with its quotes intact.
stripper='
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
    print (raw ? $0 : stripped)
  }
  END { if (skip != "") for (j = 1; j <= h; j++) print (raw ? held[j] : stripline(held[j])) }'
scan=$(printf '%s\n' "$cmd" | awk "$stripper")
body=$(printf '%s\n' "$cmd" | awk -v raw=1 "$stripper")

# Only inspect actual git commit invocations. Backslash-escaped spaces stay
# inside a token, so "git -C My\ Repo commit" is still one prefix chain.
gitpre='(^|[^[:alnum:]_./-])git([[:space:]]+-([^[:space:]]|\\ )+([[:space:]]+(\\ |[^-[:space:]])([^[:space:]]|\\ )*)?)*[[:space:]]+'
printf '%s\n' "$scan" | grep -Eq "${gitpre}commit([^[:alnum:]_-]|$)" || exit 0

# head -1 pins the override to the command's first word: a token at the start
# of a later line of a multi-line command does not disarm the guard.
if printf '%s\n' "$cmd" | head -1 | grep -Eq '^[[:space:]]*(env[[:space:]]+)?CLAUDE_COMMIT_OK=1([[:space:]]|$)'; then
  exit 0
fi

block() {
  cat >&2 <<REASON
Commit blocked: $1
Fix the message and re-run. If this repository's documented commit convention
intentionally differs, re-run the exact same command with CLAUDE_COMMIT_OK=1
as its first word to confirm.
REASON
  exit 2
}

# Every commit invocation of a compound command, one per line, quote-aware so
# a ; & or | inside message text does not truncate a segment. Extracted from
# the heredoc-less body view, so a commit example inside the message text of
# a heredoc-fed commit is not read as another invocation. Falls back to the
# whole command when quoting defeats the match (quoted -C paths).
segs=$(printf '%s\n' "$body" | grep -oE "${gitpre}commit((\"[^\"]*\")|('[^']*')|[^;&|\"'])*")
[ -n "$segs" ] || segs=$cmd

# msgline: the pattern occupies the start of a message line — inside a commit
# segment that is an opening quote or a \n escape, in the whole command a
# physical line start (heredoc bodies, real newlines in quotes). The gap
# admits non-alphanumeric prefixes like the robot emoji of the canonical
# Claude Code footer; prose mentions mid-subject and trailer strings aimed at
# other commands (git log --grep=...) stay allowed. trailerflag: git commit
# --trailer attaches a trailer without quotes and accepts = like :, checked
# against the quote-stripped scan so a quoted prose mention of the flag
# cannot match, then against $cmd for the value that quoting may hide. Keys
# match case-insensitively, as git itself treats trailers.
gap="[^[:alnum:]\"']*"
msgline() {
  printf '%s\n' "$segs" | grep -Eiq "([\"']|\\\\n|[[:space:]]-[a-zA-Z]*m[= ])${gap}$1" ||
    printf '%s\n' "$cmd" | grep -Eiq "^${gap}$1"
}
trailerflag() { # $1 key regex, $2 value regex
  printf '%s\n' "$scan" | grep -Eiq -- "--trailer[= ][[:space:]]*$1[[:space:]]*[:=]" &&
    printf '%s\n' "$cmd" | grep -Eiq -- "--trailer[= ][[:space:]\"']*$1[[:space:]]*[:=][\"']?$2"
}
if msgline 'Claude-Session[[:space:]]*[:=]' || trailerflag 'Claude-Session' ''; then
  block "remove the Claude-Session trailer from the commit message."
fi
if msgline 'Co-Authored-By[[:space:]]*[:=].*claude' || trailerflag 'Co-Authored-By' '.*claude'; then
  block "remove the Co-Authored-By Claude trailer from the commit message."
fi
if msgline 'Generated with \[Claude Code\]'; then
  block "remove the Generated with Claude Code line from the commit message."
fi

# Validate the subject of every commit invocation: its first -m/--message
# argument (quoted either way, or a bare word), or the first line of a
# heredoc that feeds the commit. Empty means unparseable for that
# invocation, which fails open.
sq="'"
while IFS= read -r seg; do
  [ -n "$seg" ] || continue
  marg=$(printf '%s\n' "$seg" |
    grep -oE -- "(^|[[:space:]])(-[a-zA-Z]*m|--message)[= ]*(\"[^\"\$]*\"|$sq[^$sq]*$sq|[^\"$sq[:space:]\$-]([^[:space:]]|\\\\ )*)" |
    head -1)
  subject=$(printf '%s\n' "$marg" |
    sed -E "s/^[[:space:]]*(-[a-zA-Z]*m|--message)[= ]*//; s/\\\\ / /g; s/^[\"$sq]//; s/[\"$sq]\$//")
  # Two heredocs opened on one line make the next physical line the first
  # heredoc's body, not the commit message: fail open instead of misreading.
  # The check runs on the scan so << in message text or heredoc bodies (C++
  # streams in a quoted diff) does not count.
  if [ -z "$subject" ] && ! printf '%s\n' "$scan" | grep -Eq '<<.*<<'; then
    subject=$(printf '%s\n' "$cmd" |
      sed -nE "\\#${gitpre}commit[^;&|]*<<-?[[:space:]]*[\"']?[A-Za-z_]#{n;s/^[[:space:]]*//;p;q;}")
  fi
  [ -n "$subject" ] || continue

  case "$subject" in
  Merge\ * | Revert\ * | Reapply\ * | fixup!* | squash!* | amend!*) continue ;;
  esac

  if ! printf '%s\n' "$subject" | grep -Eq '^[a-z][a-z0-9-]*(\([a-zA-Z0-9._/-]+\))?!?: [^[:space:]]'; then
    block "the subject does not follow Conventional Commits.
Expected: <type>[optional scope][!]: <description> with a lowercase type,
for example: feat(auth)!: drop v1 tokens
Got: $subject"
  fi
done <<<"$segs"

exit 0
