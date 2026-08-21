# Global Instructions

Personal rules for every project. MUST and MUST NOT are hard rules, SHOULD and unqualified instructions are strong defaults, MAY is optional.

## Precedence

1. Explicit instructions for the current task.
2. Repository instructions and conventions (CLAUDE.md, rules, documented conventions and requirements).
3. This file.
4. General defaults.

A higher layer overrides a lower one, including the MUST rules in this file, when it intentionally requires something different. Exception: the Git Push rules and the shared history rule in Git Commits apply everywhere as written, are not overridable by a repository, and are relaxed further only by an explicit instruction from me for the current task.

## Decisions and Questions

Resolve uncertainty independently when repository context, existing conventions, authoritative documentation, tests or other evidence, or a clearly safe and reversible default settles it. Do not ask confirmation questions when one option is clearly superior and low risk.

Ask me before deciding when a choice is materially ambiguous, consequential, subjective, destructive, or hard to reverse, or when it meaningfully changes architecture, behavior, compatibility, security, UX, or maintainability beyond what the task itself requires.

When asking:

- Present the meaningful options with concrete advantages, disadvantages, and tradeoffs.
- Mark exactly one option as **Recommended**: the best fit given the evidence, the requirements, the existing codebase, and my established preferences.
- Do not assume I already know the low-level implementation details.

## Language and Terminology

- MUST write all development content in English: code, identifiers where applicable, comments, documentation, examples, tests, configuration, error and log messages, commit messages.
- MUST NOT translate externally defined content: third-party identifiers, protocol and API values, quoted material, generated output, or anything else whose spelling is externally constrained.
- SHOULD prefer inclusive, precise terminology where technically appropriate: allowlist and blocklist, primary and replica, placeholder or example, main branch, conflict-free, concurrent or parallel.
- MUST NOT rename standardized APIs, third-party identifiers, protocol terminology, compatibility-sensitive values, historical names, or existing public interfaces to enforce that preference.

## Before Implementing

Scale investigation to the task: enough to act correctly, no repository-wide exploration for a narrow change. For a non-trivial feature, architectural change, refactor, or bug fix:

- Read the relevant project instructions and documentation.
- Understand the relevant implementation, surrounding architecture, conventions, abstractions, tests, dependencies, and related functionality first.
- Find the root cause before fixing a bug.
- Look for analogous implementations, existing utilities, and existing abstractions before writing new ones. Prefer extending established patterns over introducing new ones.

## Engineering

- Prefer the simplest solution that fits. No speculative abstraction, no premature optimization.
- Deduplicate only when the duplication represents the same knowledge or behavior and the abstraction stays easier to understand than the copies.
- Minimize the change surface. MUST NOT bundle unrelated changes.
- Preserve the existing architecture unless there is a concrete reason to change it. Preserve backwards compatibility unless breaking behavior is explicitly required.
- Use existing dependencies and utilities before adding new ones.
- Keep implementations maintainable, readable, testable, and idiomatic for the language, framework, libraries, tooling, and repository.
- MUST NOT touch generated files, vendored or third-party content, snapshots, fixtures, test expectations, external quotations, or equivalent content except when an intentional source change or correctness requires it. Style preferences alone never justify it.
- Apply these principles with judgment, not mechanically. When following one would make the result harder to understand or maintain, deviate and keep the code clear.

## Comments

- Prefer self-documenting code. Comment only what the code cannot express: non-obvious intent, reasoning, constraints, tradeoffs, edge cases, compatibility requirements, important external behavior.
- Remove comments that restate the code, describe obvious mechanics, or add noise without helping future maintainers.
- Keep comments concise, accurate, and synchronized with the code.

## Writing

Applies to every piece of human-readable text: documentation, UI text, comments, error messages, labels, descriptions, commit messages.

- Use the `unslop` skill when writing or editing prose.
- Write clearly, concisely, naturally, and specifically. Prefer simple wording that carries the same meaning accurately. Cut filler, repetition, ambiguity, verbosity, and needless jargon. Keep technical precision and established terminology.
- Keep terminology, capitalization, spelling, grammar, and tone consistent, and match them to the content's audience and purpose.
- UI text MUST be concise and actionable. Error messages MUST state what went wrong and, when useful, what to do next.
- Structure documentation for scanning and comprehension: meaningful headings, short focused sections, precise wording.
- Write accessibly: meaningful link text, alt text for images, no meaning carried by color or formatting alone.
- MUST NOT use em dashes, en dashes, dash-based sentence punctuation, or semicolons in prose. Rewrite with periods, commas, parentheses, colons, or another grammatically appropriate structure.
- The punctuation rule does not cover externally constrained content: code, syntax, identifiers, API values, commands, flags, URLs, file paths, package names, version numbers, generated values, quotations, and other compatibility-sensitive content.

## Git Commits

Follow the latest stable Conventional Commits specification, currently 1.0.0. When unsure about a spec detail, consult https://www.conventionalcommits.org instead of guessing. Before committing, read the complete staged diff, understand its purpose, and check the repository's own commit conventions.

- Format: `<type>[optional scope]: <description>`. The description MUST be concise, specific, and accurate. Default to lowercase imperative wording.
- `feat` for new functionality, `fix` for bug fixes, other types by the actual purpose of the change and the repository's conventions.
- MUST NOT invent a scope that adds no information.
- MUST NOT add a body or footers by default. Use a body only when essential context cannot fit the subject, and footers only when required (`BREAKING CHANGE`, repository-mandated references or trailers).
- Mark breaking changes with `!` before the colon or an uppercase `BREAKING CHANGE:` footer.
- MUST NOT add Claude attribution trailers such as `Co-Authored-By` or `Claude-Session` unless the repository requires them.
- Keep commits atomic: one coherent change per commit, independently understandable changes separated where practical, dependencies between commits respected, and each commit leaving the repository in a sensible state where reasonably possible. Do not split so far that commits become artificial.
- MAY split, combine, or reorder the commits created during the current task. Optimize history for review, maintainability, debugging, and future reverts.
- MUST NOT rewrite shared history unless I explicitly request it or the rewrite is clearly safe and necessary for the current task.

## Git Push

- MAY create local commits when the task requires or requests them.
- MUST NOT push commits, branches, or tags unless I explicitly request the push in the current conversation. "Commit this", "finish the implementation", or "prepare the branch" is not push authorization.
- This applies to every tool that writes to a remote, including `gh` and platform APIs.
- A PreToolUse hook blocks `git push` mechanically. Once I have explicitly asked for a push, follow the hook's instructions to confirm and proceed.
