# Global Instructions

Personal rules for every project. MUST and MUST NOT are hard rules, SHOULD and unqualified instructions are strong defaults, MAY is optional.

## Precedence

1. Explicit instructions for the current task.
2. Repository instructions and conventions (CLAUDE.md, rules, documented style).
3. This file.
4. General defaults.

A higher layer overrides a lower one, including the MUST rules in this file, when it intentionally requires something different. Exception: the Git Push rules and the shared history rule in Git Commits stay in force everywhere and are lifted only by an explicit instruction from me for the current task.

## Decisions and Questions

Resolve uncertainty independently when repository context, existing conventions, authoritative documentation, tests or other evidence, or a clearly safe and reversible default settles it. Do not ask confirmation questions when one option is clearly superior and low risk.

Ask me before deciding when a choice is materially ambiguous, consequential, subjective, destructive, or hard to reverse, or when it meaningfully changes architecture, behavior, compatibility, security, UX, or maintainability beyond what the task itself requires.

When asking:

- Present the meaningful options with concrete advantages, disadvantages, and tradeoffs.
- Mark exactly one option as **Recommended**: the best fit given the evidence, the requirements, the existing codebase, and my established preferences.
- Do not assume I already know the low-level implementation details.

## Language and Terminology

- MUST write all development content in English: code, identifiers, comments, documentation, tests, configuration, error and log messages, commit messages.
- MUST NOT translate externally defined content: third-party identifiers, protocol and API values, quoted material, generated output.
- SHOULD prefer inclusive, precise terminology where technically appropriate: allowlist and blocklist, primary and replica, placeholder or example, main branch, conflict-free, concurrent or parallel.
- MUST NOT rename standardized APIs, third-party identifiers, protocol terminology, compatibility-sensitive values, or existing public interfaces to enforce that preference.

## Before Implementing

Scale investigation to the task. For a non-trivial feature, refactor, or bug fix:

- Understand the relevant implementation, surrounding architecture, conventions, tests, and dependencies first.
- Find the root cause before fixing a bug.
- Look for analogous implementations, existing utilities, and existing abstractions before writing new ones. Prefer extending established patterns.

## Engineering

- Prefer the simplest solution that fits. No speculative abstraction, no premature optimization.
- Deduplicate only when the duplication represents the same knowledge and the abstraction stays easier to understand than the copies.
- Minimize the change surface. MUST NOT bundle unrelated changes.
- Preserve the existing architecture and backwards compatibility unless the task explicitly requires breaking them.
- Use existing dependencies and utilities before adding new ones.
- MUST NOT touch generated files, vendored or third-party content, snapshots, fixtures, or test expectations except when an intentional source change or correctness requires it. Style preferences alone never justify it.
- Apply these principles with judgment, not mechanically. When following one would make the result harder to understand or maintain, deviate and keep the code clear.

## Comments

- Prefer self-documenting code. Comment only what the code cannot express: intent, reasoning, constraints, tradeoffs, edge cases, compatibility requirements.
- Remove comments that restate the code or describe obvious mechanics.
- Keep comments concise, accurate, and synchronized with the code.

## Writing

Applies to every piece of human-readable text: documentation, UI text, comments, error messages, labels, commit messages.

- Write clearly, concisely, and specifically. Cut filler, repetition, and needless jargon. Keep technical precision and established terminology.
- Keep terminology, capitalization, spelling, grammar, and tone consistent.
- UI text MUST be concise and actionable. Error messages MUST state what went wrong and, when useful, what to do next.
- MUST NOT use em dashes, en dashes, dash-based sentence punctuation, or semicolons in prose. Rewrite with periods, commas, parentheses, or colons.
- The punctuation rule does not cover externally constrained content: code, syntax, identifiers, commands, flags, URLs, file paths, package names, version numbers, generated values, quotations.

## Git Commits

Follow Conventional Commits 1.0.0. Read the complete staged diff and check the repository's own commit conventions before committing.

- Format: `<type>[optional scope]: <description>`. Default to a lowercase, imperative description.
- `feat` for new functionality, `fix` for bug fixes, other types by the actual purpose of the change.
- MUST NOT invent a scope that adds no information.
- MUST NOT add a body or footers by default. Use a body only when essential context cannot fit the subject, and footers only when required (`BREAKING CHANGE`, repository-mandated references).
- Mark breaking changes with `!` before the colon or an uppercase `BREAKING CHANGE:` footer.
- MUST NOT add Claude attribution trailers such as `Co-Authored-By` or `Claude-Session` unless the repository requires them.
- Keep commits atomic: one coherent change per commit, unrelated changes separated, dependencies respected, and each commit leaving the repository in a sensible state where reasonably possible. Do not split so far that commits become artificial.
- MAY split, combine, or reorder the commits created during the current task for a cleaner history. MUST NOT rewrite shared history unless I explicitly request it.

## Git Push

- MUST NOT push commits, branches, or tags unless I explicitly request the push in the current conversation. "Commit this", "finish the implementation", or "prepare the branch" is not push authorization.
- This applies to every tool that writes to a remote, including `gh` and platform APIs.
- A PreToolUse hook blocks `git push` mechanically. Once I have explicitly asked for a push, follow the hook's instructions to confirm and proceed.
