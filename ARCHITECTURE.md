# Architecture

How this dotfiles system is organized, how data flows through it, and where to start when navigating the codebase.

> [!TIP]
> New here? Start with [Bird's Eye View](#-birds-eye-view) for the big picture, skim [Key Concepts](#-key-concepts) for the mental model, and jump to [Entry Points](#-entry-points) when you know what you want to change.

## 🦅 Bird's Eye View

This is a **macOS dotfiles system built on [chezmoi](https://chezmoi.io)** running in **symlink mode**. chezmoi symlinks plain configuration files into `$HOME`, renders the Go-templated ones as real copies, downloads the declared Agent Skills, and runs idempotent setup scripts. Secrets come from the macOS Keychain at apply time. Sensitive directories (SSH, GPG, SSL, kube, VPN) point straight at iCloud Drive, which makes iCloud the single source of truth for those keys.

```text
┌─── chezmoi init ────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                                                 │
│     ┌──────────────────────────────────────┐                 ┌──────────────────────────────────────┐           │
│     │ iCloud Drive                         │                 │ Interactive prompts                  │           │
│     │ config.toml                          │                 │                                      │           │
│     │ [work] / [personal]                  │                 │ (fallback if no config.toml found)   │           │
│     └───────────────────┬──────────────────┘                 └───────────────────┬──────────────────┘           │
│                         └───────────────────────────┬────────────────────────────┘                              │
│                                                     v                                                           │
│                            ┌─────────────────────────────────────────────────┐                                  │
│                            │ chezmoi.toml [data]                             │                                  │
│                            │ email, name, gpg_key, machine_type,             │                                  │
│                            │ proxy, icloud_secrets, ...                      │                                  │
│                            └─────────────────────────────────────────────────┘                                  │
│                                                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

┌─── chezmoi apply ───────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                                                 │
│     ┌──────────────────────────────┐           ┌──────────────────────────────┐                                 │
│     │ chezmoi.toml                 │           │ .chezmoidata.toml            │                                 │
│     │ [data]                       │  ──────>  │ (defaults)                   │                                 │
│     └──────────────────────────────┘           └───────────────┬──────────────┘                                 │
│                                                          merged data                                            │
│                     ┌────────────────────────────────────┼─────────────────────────────────┐                    │
│                     v                                    v                                 v                    │
│     ┌──────────────────────────────┐     ┌──────────────────────────────┐     ┌────────────────────────┐        │
│     │ dot_* files                  │     │ symlink_*.tmpl               │     │ .chezmoiscripts        │        │
│     │ (symlinked or rendered)      │     │ (iCloud paths)               │     │ (run_* scripts)        │        │
│     └───────────────┬──────────────┘     └───────────────┬──────────────┘     └────────────┬───────────┘        │
│                     v                                    v                                 v                    │
│     ┌──────────────────────────────┐     ┌──────────────────────────────┐     ┌────────────────────────┐        │
│     │ ~/.zshrc                     │     │ ~/.ssh    → iCloud           │     │ Homebrew               │        │
│     │ ~/.exports                   │     │ ~/.gnupg  → iCloud           │     │ mise toolchain         │        │
│     │ ~/.npmrc                     │     │ ~/.kube   → iCloud           │     │ permissions            │        │
│     │ ~/.gitconfig                 │     │ ~/.ssl    → iCloud           │     │ keychain sync          │        │
│     │ ...                          │     │ ~/.vpn    → iCloud           │     └────────────────────────┘        │
│     └───────────────┬──────────────┘     └──────────────────────────────┘                                       │
│                     │                                     ^                                                     │
│                     │ secrets                             │ symlink targets                                     │
│                     v                                     │                                                     │
│     ┌──────────────────────────────┐       ┌──────────────────────────────┐                                     │
│     │ macOS Keychain               │       │ iCloud Drive                 │                                     │
│     │ (source of truth)            │  <->  │ SSH, GPG, SSL,               │                                     │
│     │                              │       │ kube, VPN, tokens            │                                     │
│     └──────────────────────────────┘       └──────────────────────────────┘                                     │
│                                                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

## 🌳 Source Directory Layout

```text
Dotfiles/
│
│   # chezmoi configuration
│
├── .chezmoi.toml.tmpl                                   # User config (iCloud config.toml or prompts)
├── .chezmoidata.toml                                    # Shared non-secret defaults
├── .chezmoidata/
│   ├── skills.toml                                      # Agent Skills inventory (name, source, licensing, watched owners)
│   ├── skills-owners.toml                               # Skills of the watched owners (written by skills:sync)
│   └── zed.toml                                         # Installed Zed extensions (written by zed:dump)
├── .chezmoiexternal.toml.tmpl                           # Agent Skills as chezmoi externals, from skills.toml
├── .chezmoiignore                                       # Files excluded from $HOME
├── skill-unavailable.tar.gz                             # Fallback archive for a skill source that has gone away
├── .chezmoitemplates/
│   ├── keychain                                         # Keychain lookup (list "<id>" "<account>" <keychain> <field>)
│   └── shell-helpers                                    # Reusable bash helpers for run scripts
│
│   # Run scripts (run by chezmoi apply, numbered for ordering)
│
├── .chezmoiscripts/
│   ├── run_before_00-*                                  # Unlock dotfiles keychain (every apply)
│   ├── run_once_before_01-*                             # Install Homebrew
│   ├── run_once_before_02-*                             # Import keychain tokens from iCloud
│   ├── run_onchange_after_03-*                          # Install Homebrew packages (re-runs on Brewfile change)
│   ├── run_onchange_after_04-*                          # Fix iCloud symlink permissions (re-runs on config change)
│   ├── run_onchange_after_05-*                          # Bootstrap the proxy LaunchAgent on work, remove it on personal
│   ├── run_onchange_after_06-*                          # Install language runtimes and global CLI packages (re-runs on list change)
│   ├── run_once_after_07-*                              # Fix zsh completion permissions
│   ├── run_after_08-*                                   # Export keychain to iCloud (every apply)
│   ├── run_after_09-*                                   # Install /etc/hosts from ~/.config/hosts (every apply, self-healing)
│   └── run_after_10-*                                   # Fetch licensed skills, link them per agent, prune dropped ones
│
│   # iCloud Drive symlinks (point $HOME directories at iCloud)
│
├── symlink_dot_ssh.tmpl                                 # ~/.ssh → iCloud
├── symlink_dot_ssl.tmpl                                 # ~/.ssl → iCloud (work only)
├── symlink_dot_vpn.tmpl                                 # ~/.vpn → iCloud (work only)
├── private_dot_gnupg/                                   # ~/.gnupg/* → iCloud (6 symlinks)
│   ├── symlink_common.conf.tmpl
│   ├── symlink_trustdb.gpg.tmpl
│   ├── symlink_sshcontrol.tmpl
│   ├── symlink_private-keys-v1.d.tmpl
│   ├── symlink_public-keys.d.tmpl
│   └── symlink_openpgp-revocs.d.tmpl
├── private_dot_kube/                                    # ~/.kube/config → iCloud
│   └── symlink_config.tmpl
│
│   # Proxy daemon (work only, ignored on personal via .chezmoiignore)
│
├── dot_local/bin/
│   └── executable_proxy-watchd.tmpl                     # Proxy state script run by LaunchAgent (work only)
├── Library/LaunchAgents/
│   └── local.proxy-watchd.plist.tmpl                    # LaunchAgent watching network changes (work only)
│
│   # Shell configuration (sourced on every terminal open)
│
├── dot_zshenv.tmpl                                      # PATH for non-interactive shells (mise shims, npm registry)
├── dot_zprofile                                         # Restores the mise shims after macOS path_helper (login shells)
├── dot_zshrc                                            # Shell orchestrator
├── private_dot_exports.tmpl                             # Env vars, history, locale, zsh options (0600, reads the keychain)
├── dot_functions                                        # Shell functions
├── dot_aliases                                          # Command aliases
├── dot_plugins                                          # Oh My Zsh plugin list, compiled by antidote
├── dot_completions                                      # zsh completions, plugins, Kiro CLI support
│
│   # Tool configuration
│
├── dot_gitconfig.tmpl                                   # Git user, GPG signing, LFS, pull strategy
├── dot_gitignore_global                                 # Global gitignore (referenced by dot_gitconfig.tmpl)
├── private_dot_npmrc.tmpl                               # npm registry tokens (0600, from keychain)
├── private_dot_wakatime.cfg.tmpl                        # WakaTime API key (0600, from keychain)
├── dot_config/
│   ├── hosts.tmpl                                       # /etc/hosts source (machine-type aware)
│   ├── mise/config.toml                                 # Language runtimes + global CLI packages
│   └── zed/private_settings.json.tmpl                   # Zed editor + MCP server keys (0600, from keychain)
├── private_dot_claude/                                  # ~/.claude/ (0700)
│   ├── private_CLAUDE.md                                # Global Claude Code instructions (all projects)
│   ├── private_settings.json.tmpl                       # Claude Code user settings (plugins, marketplaces, permissions, hooks)
│   ├── private_hooks/                                   # ~/.claude/hooks/ (0700)
│   │   ├── private_executable_block-git-push.sh         # PreToolUse guard, blocks unrequested git push
│   │   ├── private_executable_block-git-destructive.sh  # PreToolUse guard, blocks git commands that discard work
│   │   ├── private_executable_check-commit-message.sh   # PreToolUse guard, validates the commit message
│   │   ├── private_executable_block-path-access.sh.tmpl # PreToolUse guard, blocks configured paths on every tool
│   │   ├── private_executable_scan-written-secrets.sh   # PostToolUse guard, sonar secrets scan of written files
│   │   └── private_executable_warn-denied-tools.sh      # SessionStart notice, project settings that withdraw core tools
│   └── private_plugins/                                 # ~/.claude/plugins/ (0700)
│       ├── create_installed_plugins.json.tmpl           # Claude Code plugin install state
│       └── create_known_marketplaces.json.tmpl          # Claude Code marketplace registry
│
│   # IDE settings
│
├── Library/Application Support/Code/User/
│   ├── settings.json.tmpl                               # VS Code settings (home dir templated for Java/Gradle paths)
│   └── keybindings.json                                 # VS Code keybindings
│
│   # Package lists (read by run scripts, not copied to $HOME)
│
├── Brewfile.personal                                    # Homebrew packages (personal)
└── Brewfile.work                                        # Homebrew packages (work)
```

## 🔑 Key Concepts

### Symlink Mode

chezmoi runs with `mode = "symlink"`, so plain managed files in `$HOME` are symlinks into the chezmoi source directory rather than independent copies. chezmoi writes anything it cannot symlink as a real **copy**: templates (`.tmpl` files have to be rendered first) and files with a restrictive mode (the `private_` / `0600` attribute). For a file to become a true symlink it must be plain, with no `.tmpl` suffix and no `private_` or `executable_` prefix. A parent `private_dot_*/` directory still keeps the folder itself at `0700`.

> [!TIP]
> Symlinked `$HOME` files point at the source directory, so you can edit them in place. Editing `~/.zshrc` and editing the source file are the same write, which makes `chezmoi edit` optional. Templates and `private_` files are the exception (e.g. `~/.claude/settings.json` or `~/.claude/CLAUDE.md`). chezmoi writes them as copies, so when a tool such as Claude Code rewrites the target, nothing reaches the source. Run `chezmoi add` to capture those changes, or `chezmoi apply` to restore the tracked version.

For sensitive directories (SSH, GPG, SSL, kube, VPN), `symlink_*` templates point `$HOME` at **iCloud Drive**. This makes iCloud the single source of truth:

```text
$HOME                                    iCloud Drive (.dotfiles/)
─────────────────────────────────        ─────────────────────────────────────
~/.ssh/                             →    .ssh/
~/.gnupg/common.conf                →    .gnupg/common.conf
~/.gnupg/trustdb.gpg                →    .gnupg/trustdb.gpg
~/.gnupg/sshcontrol                 →    .gnupg/sshcontrol
~/.gnupg/private-keys-v1.d/         →    .gnupg/private-keys-v1.d/
~/.gnupg/public-keys.d/             →    .gnupg/public-keys.d/
~/.gnupg/openpgp-revocs.d/          →    .gnupg/openpgp-revocs.d/
~/.kube/config                      →    .kube/config
~/.ssl/                             →    .ssl/                     (work only)
~/.vpn/                             →    .vpn/                     (work only)
```

The `run_onchange_after_04-fix-icloud-permissions` script fixes the permissions on the symlink targets, broadly `0700` for directories and `0600` for private material, with SSH public keys and client config plus the work VPN profiles left readable at `0644`. It re-runs whenever the iCloud path, the machine type, or the names and modes of the files under the secrets directory change.

> [!NOTE]
> The `symlink_dot_ssl.tmpl` and `symlink_dot_vpn.tmpl` files sit in the source tree on every machine, but a conditional block in `.chezmoiignore` filters them out on personal machines. Being in the repo does not mean they are applied.

### File Naming Convention

chezmoi maps source filenames to target paths by replacing prefixes and stripping suffixes:

| Source                                           | Target                              | Notes                                                                           |
| ------------------------------------------------ | ----------------------------------- | ------------------------------------------------------------------------------- |
| `dot_zshrc`                                      | `~/.zshrc`                          | `dot_` becomes `.`, symlinked                                                   |
| `private_dot_exports.tmpl`                       | `~/.exports`                        | Rendered copy at `0600`, because it inlines keychain secrets                    |
| `private_dot_claude/private_settings.json.tmpl`  | `~/.claude/settings.json`           | Rendered copy, because both `.tmpl` and `private_` rule out a symlink           |
| `private_dot_claude/private_plugins/*.json.tmpl` | `~/.claude/plugins/*.json`          | Claude Code runtime state, `create_` seeds each file once and never rewrites it |
| `private_dot_claude/private_hooks/*`             | `~/.claude/hooks/*.sh`              | Copies at `0700`, rendered where a `.tmpl` suffix bakes in chezmoi data         |
| `private_dot_claude/private_CLAUDE.md`           | `~/.claude/CLAUDE.md`               | Plain copy, and `private_` keeps the source name out of the global gitignore    |
| `symlink_dot_ssh.tmpl`                           | `~/.ssh`                            | Symlink to the rendered iCloud path                                             |
| `private_dot_gnupg/`                             | `~/.gnupg/`                         | `private_` sets the directory to `0700`                                         |
| `Library/Application Support/...`                | `~/Library/Application Support/...` | Literal path                                                                    |

### Data Layers

chezmoi merges template data from multiple sources (later layers override earlier ones):

```text
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                     │
│  Layer 3 (highest priority)                                                         │
│  chezmoi.toml [data]                                                                │
│                                                                                     │
│    email, name, gpg_key, machine_type, icloud_secrets,                              │
│    always_proxy_probe, proxy_*, ssl_bundle_*, forgeops_path, ...                    │
│                                                                                     │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  Layer 2                                                                            │
│  .chezmoidata.toml and .chezmoidata/                                                │
│                                                                                     │
│    editor, history_size, autostart_ssh_agent, default_hostname,                     │
│    tree_ignore, dock_apps, cisco_vpn_bin, keychain_name, zed_extensions,            │
│    claude_blocked_paths, ...                                                        │
│                                                                                     │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                     │
│  Layer 1 (lowest priority)                                                          │
│  Built-in variables                                                                 │
│                                                                                     │
│    .chezmoi.os, .chezmoi.homeDir, .chezmoi.hostname, ...                            │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
  ↑ later layers override earlier ones
```

Layer 3 values come from two sources, resolved at `chezmoi init` time:

1. **iCloud `config.toml`**: chezmoi reads machine-type config (proxy, SSL, enterprise) from `~/Documents/General/Developer/.dotfiles/config.toml`, under the `[work]` or `[personal]` section matching the selected `machine_type`. The file syncs through iCloud and stays outside the repo, so sensitive infrastructure details are never committed.
2. **Interactive prompts (fallback)**: If `config.toml` is not found or is missing a key, chezmoi uses `promptStringOnce`, which asks once and caches the answer.

Both `dot_*` templates and the run scripts in `.chezmoiscripts/` can read all three layers.

### chezmoi Configuration

The `.chezmoi.toml.tmpl` file also configures chezmoi behavior beyond template data:

| Section            | Purpose                                                                                                   |
| ------------------ | --------------------------------------------------------------------------------------------------------- |
| `mode = "symlink"` | Files in `$HOME` are symlinks to the source directory, not copies                                         |
| `[scriptEnv]`      | Sets `HOMEBREW_NO_AUTO_UPDATE=1`, `HOMEBREW_NO_INSTALL_CLEANUP=1`, `NONINTERACTIVE=1` for all run scripts |
| `[[textconv]]`     | Pipes `**/*.json` through `jq .` for readable `chezmoi diff` output, except Zed's JSONC settings          |

### Secrets Management

iCloud Drive stores two categories of data: **secrets** (keychain backup) and **non-secret config** (`config.toml`).

Secrets live in a dedicated `dotfiles` keychain (`~/Library/Keychains/dotfiles.keychain-db`), kept apart from the user's `login` keychain so managed entries do not mix with Wi-Fi, Safari, and AirDrop items. The dotfiles keychain locks on system sleep with no idle timeout (`security set-keychain-settings -l`). The [`run_before_00-unlock-keychain`](.chezmoiscripts/run_before_00-unlock-keychain.sh.tmpl) script unlocks it once at the start of every `chezmoi apply`, so every secret-reading template renders in a single pass without per-call prompts. Templates read entries at apply time through the `keychain` template helper.

> [!IMPORTANT]
> The dotfiles keychain is the source of truth. The iCloud tokens file is a backup, imported on a fresh machine by [`02-import-keychain`](.chezmoiscripts/run_once_before_02-import-keychain.sh.tmpl) and rewritten from the keychain by [`08-export-keychain`](.chezmoiscripts/run_after_08-export-keychain.sh.tmpl) after any apply where the two drift apart. Always use `secret:set` to add a secret, `secret:rename` to change its name or metadata, and `secret:remove` followed by `secret:set` to rotate a value. Never edit the iCloud tokens file directly.

```text
┌───────────────────────────────────────────────────────────┐
│ iCloud Drive                                              │
│ tokens file (backup)                                      │
│                                                           │
└────────────────────────────┬──────────────────────────────┘
                             │
                             │  script 02 (import on fresh mac)
                             v
┌───────────────────────────────────────────────────────────┐
│ macOS dotfiles keychain                                   │
│ (source of truth, separate from login keychain)           │
│                                                           │
└────────────────────────────┬──────────────────────────────┘
                             │
                             │  chezmoi apply (keychain helper reads at apply time)
                             v
┌───────────────────────────────────────────────────────────┐
│ Rendered files                                            │
│                                                           │
│   ~/.npmrc              ~/.exports                        │
│   ~/.wakatime.cfg       ~/.config/zed/settings.json       │
│                                                           │
└────────────────────────────┬──────────────────────────────┘
                             │
                             │  script 08: secrets:export (auto, every apply, reads the keychain)
                             v
┌───────────────────────────────────────────────────────────┐
│ iCloud Drive (backup updated)                             │
└───────────────────────────────────────────────────────────┘
```

**How it works:**

1. **The dotfiles keychain is the source of truth for secrets.** Templates read secrets with `includeTemplate "keychain" (list "<id>" "<account>" .keychain_name .keychain_lookup_field)`, which wraps `security find-generic-password` against the configured keychain and falls back to an empty string.
2. **The keychain is unlocked once per apply.** Script `00` (`run_before_00-unlock-keychain`) runs before chezmoi renders any template, calls `security unlock-keychain` with the cached password, and re-applies the lock policy (`-l` only), so the keychain stays open for the rest of the apply. That is what keeps secret-reading templates prompt-free.
3. **iCloud Drive is the backup.** Script `02` creates the dotfiles keychain on a fresh machine and imports tokens from iCloud into it. Script `08` runs after every apply and rewrites the tokens file when the keychain and the file differ.
4. **Shell functions** in `dot_functions` cover the full lifecycle. The `secret:` functions operate on a single entry, the `secrets:` functions on the whole set:
   - `secret:set <id> <account> <where> <kind> [comment]` to add a new entry (prompts for password)
   - `secret:get <id> <account>`, `secret:copy <id> <account>` to read (stdout / clipboard with auto-clear)
   - `secret:rename <old_id> <old_account> <new_id> <new_account> [new_where] [new_kind] [new_comment]` to move or update atomically
   - `secret:remove <id> <account>` to delete (and re-sync iCloud)
   - `secrets:list` for the sorted ID / Account / Kind / Used by / Where table (enumerates the keychain)
   - `secrets:import` to pull tokens-file entries missing from the keychain and report drift
   - `secrets:export` to rebuild the tokens file from the keychain (auto-runs via script `08`)

> [!NOTE]
> **Why a custom `keychain` template instead of chezmoi's built-in `keyring`?**
> The `keyring` function panics when a key is missing. The `keychain` helper wraps `security find-generic-password ... || true` in `includeTemplate`, so a missing key yields an empty string. Templates can then render a warning comment instead of failing.

**Naming convention.** Each managed entry uses five native Keychain Access fields:

- **Where** (`-s` / Service): the URL of the provider, stored in the keychain only (never in committed templates). macOS enforces `(Service, Account)` uniqueness at the storage layer.
- **Account** (`-a`): the identity at that provider.
- **Name** (`-l` / Label): the friendly identifier passed as `<id>` to every `secret:*` function and to `includeTemplate "keychain"`. By default it is also the **lookup key** templates use (configurable, see below).
- **Kind** (`-D` / `desc` attribute): the secret type, in Apple-style title case.
- **Comments** (`-j` / `icmt` attribute): the consumer (what reads this secret).

`_secrets:install` creates every entry with the `-A` flag, so chezmoi templates can read them at apply time without per-app keychain confirmation prompts.

The iCloud tokens file mirrors all five fields plus the password as tab-separated columns: `id<TAB>account<TAB>where<TAB>kind<TAB>comment<TAB>password`. Tabs rather than colons, because Where values contain `://`.

**Keychain configuration** (`.chezmoidata.toml`, defaults shown):

```toml
keychain_name         = "dotfiles"  # ~/Library/Keychains/<name>.keychain-db
keychain_lookup_field = "name"      # name | where | kind | comment
```

The `keychain_lookup_field` value selects the `security` flag templates match on (`name` → `-l`, `where` → `-s`, `kind` → `-D`, `comment` → `-j`). Only `name` works with the current call sites, because `_secrets:install` always writes the `<id>` into the Label. Keeping that default also keeps URLs out of committed `.tmpl` files.

chezmoi prompts for the **master password** once during `chezmoi init` (`promptStringOnce`) and caches it in the machine-local `~/.config/chezmoi/chezmoi.toml`. Leaving it empty (the default) ties the keychain to the login session's unlock state, so it feels like `login.keychain` in daily use, though `run_before_00` still has to unlock it for each apply. Setting a value creates a keychain that is locked by default and needs an explicit unlock in each session.

**Templates that read secrets:**

| Template                                    | What it reads                           | Condition |
| ------------------------------------------- | --------------------------------------- | --------- |
| `private_dot_npmrc.tmpl`                    | npm registry token                      | Always    |
| `private_dot_npmrc.tmpl`                    | GitHub Packages token                   | Always    |
| `private_dot_npmrc.tmpl`                    | Corporate Artifactory tokens            | Work only |
| `private_dot_exports.tmpl`                  | Infisical machine identity credentials  | Always    |
| `private_dot_exports.tmpl`                  | NTLM proxy credentials                  | Work only |
| `private_dot_wakatime.cfg.tmpl`             | WakaTime API key                        | Always    |
| `dot_config/zed/private_settings.json.tmpl` | Zed editor MCP server tokens (multiple) | Always    |
| `dot_config/zed/private_settings.json.tmpl` | GitLab MCP OAuth client ID and secret   | Work only |
| `.chezmoiscripts/run_after_10-agent-skills.sh.tmpl` | HeroUI Pro license token        | Always    |

For the live values (ID / Account / Kind / Used by / Where), run `secrets:list`.

### Agent Skills

[Agent Skills](https://agentskills.io/specification) are `SKILL.md` directories that AI coding agents load as on-demand instructions. [`.chezmoidata/skills.toml`](.chezmoidata/skills.toml) is the inventory: it names every skill this machine should have and where each one comes from. Nothing else decides. Add an entry and the next apply fetches it, delete an entry and the next apply removes it.

Skills are fetched **once**, into `~/.agents/skills`, and shared from there. That path is the ecosystem's convention for a personal skill directory every agent can read, and OpenAI Codex, GitHub Copilot CLI and Gemini CLI each find it with no configuration at all. Claude Code reads only `~/.claude/skills`, so it gets a symlink per skill, which is the mechanism [its own documentation](https://code.claude.com/docs/en/skills) describes.

```text
.chezmoidata/skills.toml            the inventory (402 skills)
        │
        ├──> .chezmoiexternal.toml.tmpl ──> chezmoi external ──┐
        │      every skill but the licensed ones               │
        │                                                      v
        └──> run_after_10-agent-skills ──> curl + token ──> ~/.agents/skills/<name>
               the licensed ones                               │
                                                               ├──> Codex     reads it natively
               run_after_10-agent-skills ──> symlink ──────────┤     Copilot  reads it natively
                                                               │     Gemini   reads it natively
                                                               └──> ~/.claude/skills/<name>
```

**Four source kinds**, one per entry, and the entry's keys say which:

| Keys              | Fetched as                | Used for                                                            |
| ----------------- | ------------------------- | ------------------------------------------------------------------- |
| `repo` (+ `path`) | `archive` external        | A public GitHub repository, or one directory inside a larger one    |
| `url`             | `archive` external        | A tarball the vendor publishes on its own, smaller than a repo copy |
| `git`             | `git-repo` external       | A private repository, where a tarball would need credentials        |
| none              | plain source files        | A skill this repository owns, in `dot_agents/skills/<name>/`        |

Wanting everything one person publishes is a fifth case, and it does not belong in the table because it is not a source kind. Listing a name in `agent_skill_owners` and running [`skills:sync`](dot_functions) resolves that person's whole catalogue through the [skilld.dev](https://skilld.dev) registry into [`.chezmoidata/skills-owners.toml`](.chezmoidata/skills-owners.toml), which is generated and committed. chezmoi merges every file under `.chezmoidata/`, so the two files together are the inventory.

Resolving owners at apply time was rejected. It would put a registry call in front of every `chezmoi apply`, and since a failed external fails the whole source state, a registry that is slow or down would stop the apply. Committing the resolved list keeps the repository able to answer, on its own, which skills exist. A skill named by hand in `skills.toml` beats the registry's copy of the same name, which is how `slidev` stays on `slidevjs/slidev` rather than `antfu/skills`, and `skills:sync` reports every such override.

Adding `token` to an entry marks it **licensed**. chezmoi externals cannot send an HTTP header, and a licensed tarball needs one, so [`run_after_10-agent-skills`](.chezmoiscripts/run_after_10-agent-skills.sh.tmpl) downloads those with the named keychain secret instead. It writes them to the same shared directory, so nothing downstream knows the difference. The license key never enters the repository, and the download hands it to `curl` on stdin rather than in an argument, which any local account could read from the process table.

Every external carries `agent_skills_refresh` as its `refreshPeriod`, so the first apply after that period re-downloads it. Keeping skills current needs no separate workflow: it is whatever already brings the rest of the configuration up to date, `chezmoi apply` or `chezmoi update`, and `--refresh-externals` forces a download before the period is up. `exact = true` makes each skill converge, so a file upstream deletes is deleted here too.

A `git-repo` external is a real working tree, which is what makes a repository the user owns editable in place. The cost is that an apply refreshing it runs `git pull --ff-only`, so a clone carrying uncommitted work, or one whose history has diverged from the remote, reports the pull failure and is left untouched. That is deliberate: the alternatives are discarding the work or inventing a merge commit. Commit and push, or delete the directory and let the next apply clone it again. The failure is confined to that one skill, and every other external still applies.

A `repo` entry downloads the whole repository to extract one directory, and the inventory tracks 116 of them. Two things follow, and both are handled rather than hoped about.

**One dead source must not break everything.** A failed `archive` download fails chezmoi's source-state read, not just that entry, so a single deleted repository would stop `chezmoi apply` from applying anything at all, on this machine and on a new one. Every archive therefore lists a second URL, [`skill-unavailable.tar.gz`](skill-unavailable.tar.gz), and chezmoi takes the first URL that answers. A dead source now unpacks a directory with no `SKILL.md`, which no agent loads, and the apply carries on. A `git-repo` external needs no such thing: its clone runs at write time, so chezmoi reports the failure and keeps going by itself.

**A dead source must not be silent.** `run_after_10-agent-skills` ends by checking every declared skill for a `SKILL.md` and naming the ones that have none, together with the source the inventory claims for them:

```text
Error:   Failed to install the some-skill skill from someone/their-repo (skills/some-skill)
Info:    Check the source of each skill above, then fix or drop its entry in .chezmoidata/skills.toml
```

That covers a repository that was deleted or renamed, a skill the upstream moved so `path` no longer finds it, and a licensed download that has started failing. chezmoi's own message names a URL once, on the apply where the download broke. This one names the skill every apply until it is fixed.

**The listing has a budget too.** 402 skills is about 129 KB of names and descriptions, roughly 33,000 tokens. Claude Code and Gemini CLI list all of them, Codex caps its listing at the smaller of 2% of the context window and 8,000 characters and shortens or drops the rest, and every agent spends that text on every session. Trimming means removing entries here, or disabling per agent: `[[skills.config]]` with `enabled = false` in `~/.codex/config.toml`, `disabledSkills` in `~/.copilot/settings.json`, and `skillListingMaxDescChars` in Claude Code's settings.

**Bandwidth is bounded by `refresh`.** Refreshing every source weekly would move about 1.3 GB a week, because a few of these repositories are enormous next to the skill they carry, one of them 136 MB. Any entry whose tarball is 25 MB or more sets `refresh = "2160h"`, which splits the load into 390 MB weekly and 950 MB quarterly. A first apply on a new machine still fetches everything once, so budget about 1.3 GB for it, and about 2.7 GB of `~/.cache/chezmoi` afterwards, since chezmoi keeps both the download and the unpacked copy. That cache can be deleted at any time.

Removal is the one thing chezmoi cannot do alone. Dropping an external stops the download but leaves the copy already written, so `run_after_10-agent-skills` keeps a ledger of what it installed at `~/.local/state/agent-skills/managed` and deletes what the inventory no longer names. Anything absent from that ledger is somebody else's, and is left alone: a hand-installed skill in the shared directory, a real directory inside an agent's skill directory, and a symlink pointing anywhere other than the shared directory all survive every apply.

> [!NOTE]
> `~/.agents/.skill-lock.json` is left over from `npx skills`, which installed this set before chezmoi did. It is inert, but running `npx skills update` would write over directories chezmoi now owns. Declare skills in `.chezmoidata/skills.toml` instead. `npx skills find` is still the way to discover new ones.

### Machine-Type Branching

The `machine_type` variable (`personal` or `work`), set once during `chezmoi init`, drives conditional behavior:

| Layer              | `personal`                              | `work`                                                    |
| ------------------ | --------------------------------------- | --------------------------------------------------------- |
| **Brewfile**       | `Brewfile.personal`                     | `Brewfile.work`                                           |
| **Proxy**          | Disabled (`always_proxy_probe = false`) | Event-driven via LaunchAgent + `proxy:probe` fallback     |
| **SSL**            | No extra CA certs                       | Corporate CA bundle symlinked from iCloud                 |
| **VPN**            | No config                               | Cisco AnyConnect config symlinked from iCloud             |
| **Auth**           | No NTLM                                 | NTLM credentials for Alpaca proxy                         |
| **npm registries** | Public only                             | Public + Artifactory, host follows the proxy state        |
| **/etc/hosts**     | Standard entries only                   | Work-specific hostnames added via `dot_config/hosts.tmpl` |

### Shell Loading Order

When a new terminal opens, startup runs in this exact order. zsh reads the first three files on its own, then `~/.zshrc` drives the rest:

```text
  ~/.zshenv ────────────── mise shims (every zsh, including non-interactive)
          │
          v
  /etc/zprofile ────────── macOS path_helper rebuilds PATH (login shells only),
          │                demoting the shims that .zshenv prepended
          v
  ~/.zprofile ──────────── Restores the mise shims to the front of PATH
          │
          v
  Kiro CLI pre-hook ────── (if installed)
          │
          v
  ~/.exports ───────────── Env vars, proxy, locale, history, zsh options
          │
          v
  ~/.functions ─────────── Utility functions (proxy, VPN, secrets, toolchain, Git, ...)
          │
          v
  PATH setup ───────────── Homebrew first, then tool paths, then mise (must be last)
          │
          v
  plugins:load ─────────── Oh My Zsh bundle, compiled by antidote from ~/.plugins
          │
          v
  ~/.aliases ───────────── Command aliases (override the bundle where the two collide)
          │
          v
  ~/.completions ───────── zsh completions, autosuggestions, syntax highlighting
          │
          v
  Runtime hooks ────────── proxy state load, SSH agent
          │
          v
  Daily checks ─────────── mise tool upgrades, brew deprecation/outdated, plugin updates (once per 24h)
          │
          v
  Kiro CLI post-hook ───── (if installed)
```

### Run Script Execution

Scripts in `.chezmoiscripts/` are numbered for deterministic ordering. The filename prefix determines when and how often they run:

| Prefix                | Behavior                            | Example                                              |
| --------------------- | ----------------------------------- | ---------------------------------------------------- |
| `run_before_`         | Every `chezmoi apply`, before files | Unlock dotfiles keychain                             |
| `run_once_before_`    | Once, before files are copied       | Install Homebrew, import keychain                    |
| `run_onchange_after_` | Re-runs when script content changes | Homebrew packages (Brewfile hash embedded in script) |
| `run_once_after_`     | Once, after files are copied        | Fix zsh completion permissions                       |
| `run_after_`          | Every `chezmoi apply`, after files  | Export keychain to iCloud, install /etc/hosts, link Agent Skills |

Every script includes `{{ template "shell-helpers" . }}`, which provides shared bash helpers:

| Helper                  | Purpose                                                |
| ----------------------- | ------------------------------------------------------ |
| `_log <level> <msg>`    | Colored logging (error, success, warning, info, debug) |
| `_cmd_exists <cmd>`     | Check whether a command exists in PATH                 |
| `_ensure_brew`          | Load Homebrew shellenv (Apple silicon and Intel)       |
| `_ensure_icloud <path>` | Trigger an iCloud Drive download for a path            |

## 🗺️ Entry Points

| What you want to do                  | Start here                                                                                         |
| ------------------------------------ | -------------------------------------------------------------------------------------------------- |
| Understand shell startup             | `dot_zshrc`                                                                                        |
| Add an environment variable          | `private_dot_exports.tmpl`                                                                         |
| Add a shell function                 | `dot_functions`                                                                                    |
| Add a command shortcut               | `dot_aliases`                                                                                      |
| Add or remove an Oh My Zsh plugin    | `dot_plugins` (the next shell rebuilds the compiled bundle)                                        |
| Force a plugin bundle rebuild        | `rm ~/.cache/zsh/plugins.zsh`                                                                      |
| Update the Oh My Zsh plugins         | `plugins:update` (runs once a day, alongside mise and brew)                                        |
| Load a plugin if its tool exists     | `conditional:have:<tool>` in `dot_plugins`, guard in `dot_functions`                               |
| See which aliases shadow a binary    | `alias:shadows`                                                                                    |
| Change a shared default              | `.chezmoidata.toml`                                                                                |
| Add a user-prompted value            | `.chezmoi.toml.tmpl`                                                                               |
| Add machine-type config (non-secret) | `config.toml` on iCloud Drive                                                                      |
| Add a Homebrew package               | `Brewfile.personal` or `Brewfile.work`                                                             |
| Refresh this machine's Brewfile      | `brew:dump` (adds `--no-npm` and picks the right Brewfile)                                         |
| Keep a formula out of the Brewfile   | `brew tab --no-installed-on-request <formula>`                                                     |
| Refresh the Zed extension list       | `zed:dump` (Zed has no CLI for this)                                                               |
| Add a runtime or global CLI package  | `dot_config/mise/config.toml`                                                                      |
| Edit global Claude Code instructions | `private_dot_claude/private_CLAUDE.md`                                                             |
| Change a Claude Code guard hook      | `private_dot_claude/private_hooks/`                                                                |
| Change the paths Claude cannot touch | `.chezmoidata.toml` (`claude_blocked_paths`)                                                       |
| Add or remove an Agent Skill         | `.chezmoidata/skills.toml`                                                                         |
| Follow everyone one person publishes | `.chezmoidata/skills.toml` (`agent_skill_owners`), then `skills:sync`                              |
| Find out why a skill is missing      | The `Failed to install the <name> skill` errors at the end of `chezmoi apply`                      |
| Refresh the external Agent Skills    | Nothing, any apply does it weekly (`chezmoi apply --refresh-externals` to skip the wait)           |
| Teach another agent about the skills | `.chezmoidata/skills.toml` (`agent_skills_link_dirs`), only if it cannot read `~/.agents/skills`   |
| Edit a repository-owned Agent Skill  | Its directory under `dot_agents/skills/`, which symlinks straight into `~/.agents/skills`          |
| Add a managed secret                 | `secret:set <id> <account> <where> <kind> [comment]` then `includeTemplate "keychain"`             |
| Rename or update a secret            | `secret:rename <old_id> <old_account> <new_id> <new_account> [new_where] [new_kind] [new_comment]` |
| Inspect or audit secrets             | `secrets:list` (table view), `secrets:import` (sync + drift), `secret:copy` (clipboard)            |
| Change keychain name or lookup field | `.chezmoidata.toml` (`keychain_name`, `keychain_lookup_field`)                                     |
| Set a master keychain password       | `chezmoi init --prompt` (forces every `prompt*Once` value to be asked again)                       |
| Manage `/etc/hosts` entries          | `dot_config/hosts.tmpl`                                                                            |
| Symlink a new directory to iCloud    | Create a `symlink_dot_<name>.tmpl` with the iCloud path                                            |
| Add a new setup step                 | Create a numbered `run_*` script in `.chezmoiscripts/`                                             |
| Modify shared script helpers         | `.chezmoitemplates/shell-helpers`                                                                  |
| Debug proxy daemon                   | `proxyd:status`, `proxyd:log`, or `proxyd:log 1h`                                                  |
| Reload proxy daemon                  | `proxyd:reload`                                                                                    |

## 💡 Design Decisions

| Decision                                                       | Rationale                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| -------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Symlink mode**                                               | Editing a symlinked `$HOME` file edits the source directly, so no `chezmoi edit` is needed. Templates and `private_` files are the exception. chezmoi writes them as real copies, because rendered output and restrictive modes cannot be expressed as a symlink.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| **iCloud symlinks for SSH/GPG/SSL/kube/VPN**                   | One copy of every key across all machines, with no copy scripts to maintain. chezmoi creates the symlinks and a `run_onchange_after` script fixes the permissions.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| **Dedicated dotfiles keychain over login keychain**            | Managed entries get their own sidebar entry in Keychain Access instead of mixing with Safari and Wi-Fi items. An empty unlock password ties the keychain to the login session, so it feels the same to use. Secrets never sit in plaintext in the repo, and FileVault covers rendered files at rest.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| **`-A` flag on every managed entry**                           | Lets any process running as the user read the entry with no confirmation prompt, which is what allows chezmoi templates to render unattended. The trade-off against the login keychain's per-app prompts is that malware running as the user can silently read these credentials. Acceptable for personal dev secrets behind FileVault, screen lock, and a strong Apple ID with 2FA.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| **Upfront unlock (`run_before_00`) over per-call prompts**     | The `securityd` daemon does not manage a custom keychain the way it manages `login.keychain`, so every `security find-generic-password` call against a locked keychain raises its own prompt. One `unlock-keychain` at the start of each apply turns ten-plus prompts into none. It also re-applies `set-keychain-settings -l` (lock on sleep, no idle timeout), so a misconfigured keychain on an existing machine repairs itself.                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| **Tokens file mode `0600`**                                    | Enforced by `_secrets:ensure-tokens-file` (an idempotent `chmod`). Defends against reads by other local users on a shared Mac, even though the file is also encrypted in iCloud and covered by FileVault at rest.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| **Configurable keychain via `.chezmoidata.toml`**              | The `keychain_name` value lets a fork change the keychain filename without touching any template. `keychain_lookup_field` selects the `security` flag that lookups use, but only `name` (Label) works with the current call sites, because `_secrets:install` always writes the `<id>` into the Label. Keeping URLs out of committed `.tmpl` files is what `name` buys.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| **Action-first log convention**                                | Every `log` / `_log` message starts with a verb (`Imported`, `Failed to update`, `Skipped`, `Installing…`) and keeps formatting colons out of the body, so the `<Level>:` prefix carries the only formatting colon. Colons inside data values, such as URLs or a function name like `secret:rename`, are fine. Failures can be found with a `^Error:` grep, and the level and the action both read in one line.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| **iCloud `config.toml` over init prompts**                     | Proxy hosts, SSL cert names, and enterprise domains are sensitive organizational details. A TOML file on iCloud with `[work]` and `[personal]` sections keeps them out of the repo.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| **`keychain` template helper**                                 | Wraps `security find-generic-password` in a reusable one-liner. Returns an empty string for a missing key, whereas chezmoi's `keyring` panics.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| **Numbered run scripts**                                       | Deterministic ordering rules out race conditions (the keychain import in script 02 has to finish before any template reads a secret).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| **`run_once_` for setup, `run_onchange_` for content-driven**  | Embedded content hashes reinstall Homebrew packages and the mise tool list only when their source files change. Each script also embeds a presence marker for the tool it drives, so a run skipped because `brew` or `mise` was missing re-fires the day that tool arrives instead of recording the skip as final.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| **Separate Brewfiles per machine type**                        | Personal and work machines have very different toolchains. Two focused lists are easier to maintain than one list full of conditionals. Each file is named after the `machine_type` value it serves (`Brewfile.personal`, `Brewfile.work`), which chezmoi constrains to those two, so the run script and `brew:dump` derive the name instead of mapping it.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| **`scriptEnv` for Homebrew flags**                             | `HOMEBREW_NO_AUTO_UPDATE=1` stops Homebrew from auto-updating during scripted installs, which keeps apply fast and deterministic. `HOMEBREW_NO_INSTALL_CLEANUP=1` keeps `brew cleanup` off the install path for the same reason. `NONINTERACTIVE=1` is read by the Homebrew installer script in `run_once_before_01`, not by `brew` itself.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| **LaunchAgent for proxy detection**                            | Replaces a per-shell `nc` probe (~3s) with an event-driven daemon that watches `/Library/Preferences/SystemConfiguration` and `/var/run/resolv.conf` (covering Wi-Fi and VPN). Shell startup only reads a cached state file (~0ms), falling back to `proxy:probe` on first boot.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| **Proxy-dependent npm registry**                               | Both hosts behind the `@swisscom` scope front the same virtual repo, but only `artifactory.swisscom.com` is reachable through the corporate proxy and only `bin.swisscom.com` without it. npm has no per-proxy registry setting, so `.npmrc` expands `${NPM_SWISSCOM_REGISTRY}` from the environment. `proxy:set`, `proxy:unset`, and `proxy-watchd` swap that value as the network changes. The two URLs live once in `.chezmoidata.toml`. `.zshenv` defaults the variable to the direct host, because it is the one shell file every zsh reads, so `zsh -c`, ssh sessions, and cron resolve the scope too. `.exports` would have covered only interactive shells. The functions set rather than unset it, because an ini file has no fallback and npm would otherwise use the variable name literally.                                                                                           |
| **mise activated last in `.zshrc`**                            | mise resolves versions inside a compiled binary, not a sourced shell script, so there is no lazy-loading trick and no `cd` hook of our own to maintain. Ordering is the one hard rule. Activation snapshots `PATH` and re-derives from that snapshot on every prompt, so it must run after `brew shellenv` and every `path:add`. Homebrew keeps its own `node` as a dependency of eslint, prettier, and vercel, and this ordering keeps that copy behind mise's.                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| **`.zprofile` restores the mise shims**                        | `.zshenv` puts the shims first, then macOS `/etc/zprofile` runs `path_helper -s`, which rebuilds `PATH` and appends the rest at the end. On a login shell the shims land behind `/opt/homebrew/bin`, so Homebrew's node wins. Interactive shells recover through `mise activate zsh`, but login shells that never read `.zshrc` do not, and those are the shells `.zshenv` exists to cover. Chosen over `setopt no_global_rcs`, which disables `/etc/zprofile` outright.                                                                                                                                                                                                                                                                                                                                                                                                                           |
| **Every mise command pins itself to `$HOME`**                  | mise resolves `[tools]` from the working directory upward, and trust does not gate that: it asks for trust before running `[env]`, `[tasks]`, and `[hooks]`, never before reading a tool list. An unscoped `mise upgrade` from `run:daily` would therefore install the toolchain of whatever project the first terminal of the day opened in. `install`, `upgrade`, `prune`, and `cache clear` all run with `-C "$HOME"`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| **`mise prune` after `mise install`**                          | `mise install` only adds. Dropping a tool from `config.toml` re-fires the script but leaves the old install and its shims in place, and `.zshenv` keeps that shim directory on `PATH` for every zsh. `prune` removes versions no tracked config still asks for, so project toolchains survive, and it rebuilds the shim directory in the same pass.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| **`mise doctor` closes the install script**                    | `mise install` reads an existing install directory as proof the tool is there, and the `incomplete` marker that would contradict it lives under the java cache tree the same script clears first. An apply interrupted while java downloaded therefore leaves an empty directory that every later run skips, no shim is generated, and `not_found_system_fallback = false` turns the call into a hard failure instead of a wrong answer. mise 2026.8.12 taught `doctor` to report that case. It runs at the moment the phantom would be cemented rather than on the daily stamp, so it costs no shell startup, and only real problems set a non-zero status, so the standing self-update warning this Homebrew install cannot act on never trips it.                                                                                                                                               |
| **Homebrew owns the mise binary**                              | mise 2026.8.11 added an opt-in `auto_update` that replaces the running binary and re-execs the command. It stays unset. The Homebrew keg ships a `.disable-self-update` marker, so `mise doctor` reports `self_update_available: no` and the setting is skipped even when set. Writing it down would be dead configuration, not a policy. Ownership stays split by layer instead: the `brew autoupdate` LaunchAgent upgrades the binary daily, `brew:check` reports it when that lags, and `mise:update` covers only the managed tools. Revisit this the day mise stops arriving through Homebrew, because `auto_update` becomes live at that point.                                                                                                                                                                                                                                               |
| **antidote for Oh My Zsh plugins**                             | Plugins are listed in `dot_plugins` and compiled into one flat `~/.cache/zsh/plugins.zsh`. A normal startup sources that single file and does no plugin resolution, because antidote itself loads only when the list is newer than the compiled bundle. Same shape as `mise/config.toml`: a plain tracked file, symlinked rather than rendered, so editing `~/.plugins` edits the source and the next shell rebuilds. The compiled output lives under `~/.cache` because it is derived, which keeps `$HOME` to the one file you edit. Chosen over a full Oh My Zsh install, which brings a framework that sets its own options and prompt, and over a hand-rolled clone, which would mean owning the update logic. A `run_onchange_` script was considered and rejected, because it would only move the one-time build from the first shell to `chezmoi apply`, at the cost of a second code path. |
| **`plugins:update` on the daily stamp**                        | antidote clones a plugin once and never revisits it, so without this the Oh My Zsh checkout would stay at whatever commit it had on the day it was cloned. `run:daily plugins plugins:update` puts it on the same 24-hour stamp as `mise:update` and `brew:check`. It rebuilds the bundle in place rather than deleting it, so a failed rebuild leaves a working older bundle instead of a shell with no plugins. The four Homebrew plugins in `.completions` are unaffected, because `brew upgrade` already covers those.                                                                                                                                                                                                                                                                                                                                                                         |
| **Completion cache enabled in `plugins:load`**                 | `zstyle ':completion:*' use-cache on`, with a `cache-path` under `ZSH_CACHE_DIR`. zsh ships this off, and several plugins call `_retrieve_cache` and `_store_cache` while they load. Without it the composer plugin re-runs `composer global config bin-dir` on every shell to find its vendor path, measured at 236 ms against 6 ms once the cache answers. It has to be set in `plugins:load` rather than `.completions`, because the plugins ask for it before `.completions` runs.                                                                                                                                                                                                                                                                                                                                                                                                             |
| **`plugins:load` is a function, not inline `.zshrc`**          | `.zshrc` is an orchestrator that calls named functions (`proxy:set`, `run:daily`, `ssh:agent`), so the plugin loader is one too. Sourcing the bundle inside a function was checked rather than assumed: aliases, functions, and `typeset -g` values all survive it, and the only value that stops reaching the shell is the git plugin's `git_version` scratch variable.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| **`alias:shadows` over a longer correction list**              | The bundle has no equivalent of `alias:safe`, so a plugin update can quietly claim a command name. Rather than trying to predict that once, `alias:shadows` prints the current answer, and the corrections list in `.aliases` records the decisions already taken. It is what caught the nestjs plugin claiming `ng` from the Angular CLI.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| **`have:fzf` gate on fzf**                                     | fzf's setup evaluates `fzf --zsh`, which saves and restores shell options. A shell with no terminal has no ZLE to restore, so `zsh -ic` printed `can't change option: zle` twice. Such a shell has no use for key bindings anyway. The guard tests for the binary too, because the plugin probes eight fixed directories and then tells the reader to set `FZF_BASE`, which is what a machine whose Brewfile omits fzf prints on every prompt.                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| **Plugins load before `.aliases`**                             | The bundle claims over 800 names and `.aliases` declares about 135, of which roughly two dozen overlap. Loading plugins first makes `.aliases` the authority on its own names, so every override is a visible line in a tracked file rather than a silent win for whichever file loaded last. Seven names went to the plugins instead (`l`, `la`, `gba`, `gbd`, `gcl`, `glg`, `grep`) and were deleted from `.aliases` rather than redeclared, so no third-party alias text is copied into this repo.                                                                                                                                                                                                                                                                                                                                                                                              |
| **`alias:_taken` instead of `cmd:exists` in the alias guards** | `cmd:exists` is `command -v`, which resolves aliases as well as binaries. With the bundle loading first, every plugin alias looked like an existing command, so `alias:safe` stepped aside for all of them. The guards now test `$commands`, `$functions` and `$builtins` only. Shadowing a real command is still refused and still warned about. Sitting on top of a plugin alias is the intended behavior.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| **Deferred `compdef` queue**                                   | The git, kubectl, npm, and gradle plugins call `compdef` as they load, but the completion system does not start until `.completions`, which has to stay last because zsh-syntax-highlighting only wraps widgets that already exist. `plugins:load` installs a stub that queues those calls, and `.completions` replays them. Running `compinit` early instead does not work, because a second `compinit` discards everything registered against the first.                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| **`conditional:have:<tool>` for plugins with no tool**         | `terraform`, `sbt`, `multipass`, `mongocli`, `pre-commit`, and `rails` are listed but wrapped in a guard, so each activates the day its tool is installed and costs a single test until then. `have:rails` is hand-written rather than generated, because macOS ships `/usr/bin/rails`, a stub that only prints "Rails is not currently installed", so a plain `cmd:exists` would load 73 aliases on a machine with no Rails.                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| **Conventional Commit aliases in `dot_gitconfig.tmpl`**        | The `git-commit` plugin creates them by running `git config --global`, which rewrites `~/.gitconfig` behind chezmoi's back and drifts from the source on every apply. The same twelve types live in the template instead, sharing one `cc` implementation so each alias only binds its type. Verified to behave identically to the plugin across a 16-case matrix.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| **compinit caching**                                           | compinit's own freshness check globs every completion file on `fpath`, 1216 of them across 47 directories, and costs about 440 ms per shell. `.completions` passes `-C` to skip it and decides staleness itself: it drops `~/.cache/zsh/compdump` when the dump is over 24 hours old, or when the recorded `fpath` list no longer matches. Directory mtimes would catch a new tool the same day but are useless here, because eight Oh My Zsh plugins rewrite `~/.cache/oh-my-zsh/completions` in the background on every shell. The age test is an array assignment rather than a `[[ ]]` conditional: `[[ ]]` never performs filename generation, so a glob qualifier inside one is just text and the test always passes.                                                                                                                                                                        |
| **bun's completion goes on `fpath`, never sourced**            | `~/.bun/_bun` is a `#compdef bun` file, but it ends in `if ! command -v compinit; then autoload -U compinit && compinit; fi`. `command -v` cannot see an autoloadable function that has not been loaded, and `.completions` deliberately leaves `compinit` to zsh-autocomplete, so the probe always failed and bun ran a full uncached `compinit` (460 ms). That also left the completion system owned by something other than zsh-autocomplete, which responds by deleting its dump and rebuilding from scratch at the first prompt, for another 450 ms. Putting `~/.bun` on `fpath` gives the same completion for neither cost.                                                                                                                                                                                                                                                                  |
| **`run:daily` update gating**                                  | The `run:daily` wrapper puts `mise:update`, `brew:check`, and `plugins:update` behind a stamp file in `~/.cache/daily/`, with a `(N.mh-24ms+0)` freshness check that costs zero forks and ignores a future-dated stamp. Keeps slow update commands off every shell startup. Each run is detached and its output kept for the next shell to print, so no prompt waits on it. Detaching also removes the symptom of a hang, so the forked job carries a watchdog that sends TERM and then KILL after `RUN_DAILY_TIMEOUT` seconds (300 by default). `mise:update` runs its upgrade at `MISE_LOG_LEVEL=warn`. Since mise 2026.9.2 a captured upgrade narrates version resolution one line per tool, so an ordinary day arrives as 40 lines of progress at the default level and 2 at `warn`.                                                                                                           |
| **`/etc/hosts` is a root-owned copy**                          | chezmoi renders `dot_config/hosts.tmpl` into `~/.config/hosts` with machine-type-aware entries (work entries are dropped on personal). Script 09 installs that file over `/etc/hosts` as `root:wheel 0644`. It was a symlink into `$HOME` until it turned out to hand every process running as this user the ability to rewrite system name resolution with no sudo, which the system expects to be root-only. The script runs on every apply rather than behind a content hash, because the state it depends on is `/etc/hosts` itself, which a macOS upgrade or an installer can replace. `cmp` follows a symlink and would call the old layout identical, so a symlink is tested for separately, and the new file is written beside the target and renamed, because renaming over a symlink replaces the link rather than writing through it.                                                   |
| **Global Claude instructions as `private_CLAUDE.md`**          | Claude Code loads `~/.claude/CLAUDE.md` at the start of every session in every project, before any repository `CLAUDE.md`, so the file carries only cross-project rules and lets repository conventions win. The `private_` prefix keeps the target file at `0600` like the rest of `~/.claude`, and it also keeps the source name clear of the global gitignore's `**/CLAUDE.md` rule, which would otherwise ignore the source file in this very repo. Like the settings template, the file is written as a copy, so edits made directly to the target need `chezmoi add` to reach the source.                                                                                                                                                                                                                                                                                                    |
| **A PreToolUse hook guards `git push`**                        | "Never push unless explicitly asked" needs mechanical enforcement, because CLAUDE.md instructions are advisory and the `claude` alias runs with `--dangerously-skip-permissions`, which skips `ask` permission rules. A `deny` rule would block requested pushes too. The settings filter narrows the hook to git commands as a fast path, and the script itself inspects the actual command, blocks any `git push` invocation (including flagged forms such as `git -C <path> push`) with exit code 2, and tells Claude to re-run the command with `CLAUDE_PUSH_OK=1` once the user has explicitly asked for the push. The `private_executable_` prefix renders the script at `0700`.                                                                                                                                                                                                             |
| **Write-time secrets scan and destructive git guard**          | The SonarQube integration only scans files Claude reads and user prompts, so a PostToolUse hook runs `sonar analyze secrets` on every file Claude writes and feeds findings back with exit code 2. A second PreToolUse guard blocks `git reset --hard`, forced `git clean`, forced `git checkout`, and worktree-discarding `checkout` and `restore` behind the same explicit-confirmation pattern as the push guard (`CLAUDE_DESTRUCTIVE_OK=1`). The sonar-installed wrappers under `~/.claude/hooks/sonar-secrets/` stay vendor-managed and out of chezmoi, while their settings registration is templated so `chezmoi apply` cannot wipe it.                                                                                                                                                                                                                                                     |
| **Commit style enforced by an agent hook, not a git hook**     | A global `core.hooksPath` was tried and reverted: it hijacks every repo's hook path (git-lfs and local tooling install into `.git/hooks`) and binds the human too, while the rule only needs to steer the agent. A PreToolUse hook now validates the Conventional Commits subject (lowercase type) and rejects Claude attribution trailers in commands it can parse, fails open for editor-based commits and exotic quoting, and accepts `CLAUDE_COMMIT_OK=1` when a repository's documented convention intentionally differs. Bodies and footers stay unrestricted.                                                                                                                                                                                                                                                                                                                               |
| **A path blocklist needs a hook, not just a deny rule**        | One list in `.chezmoidata.toml` (`claude_blocked_paths`) feeds both `permissions.deny` and a PreToolUse guard, since neither alone suffices. Deny rules reach the `@` mentions no hook sees, but validate paths for only about thirty six recognised commands: before this machine's managed policy landed, a deny rule blocked `cat file` while `python3 -c` read it. That policy (`allowManagedPermissionRulesOnly`) drops every non-managed rule, so here the hook is the only enforcement. It registers for every tool, since Monitor, PowerShell and Tmux also run commands, and matches path text rather than command names, since zsh reads through hundreds of aliases and a bare `< file`. Entries are bare names, so a directory stays covered through a symlink or copy. No override: this is a confidentiality boundary. A project's `disableAllHooks` still defeats it.               |
| **chezmoi externals over a skills package manager**            | `npx skills` installed this set first, and its lockfile lives in `~/.agents`, outside the repository, so the repository never held the answer to which skills exist. A chezmoi external per skill puts that answer in `.chezmoidata/skills.toml`, updates on `chezmoi update` like everything else, and needs no second package manager on a fresh machine. The cost is that chezmoi cannot send an auth header, which is why the two licensed skills keep a small script. |
| **One shared skills directory over a copy per agent**          | `~/.agents/skills` is the ecosystem's shared personal location, and Codex, Copilot CLI and Gemini CLI each read it with no configuration. Only Claude Code needs anything, and one symlink per skill is what its documentation describes. Linking into the others as well was tried and rejected: they would list every skill twice against a skills budget capped at a fraction of the context window. |
| **Per-skill symlinks over symlinking the whole directory**     | Claude Code does follow a symlinked `~/.claude/skills`, measured on 2.1.269, but that hands the entire directory to this repository. Codex shows why that is wrong: it keeps its own bundled skills in `~/.codex/skills/.system`. A link per skill leaves every agent's directory theirs. |
| **A ledger over pruning whatever is undeclared**               | Dropping an external stops the download but leaves the copy behind, so removal needs a sweep. Sweeping everything undeclared would also delete a skill installed by hand, which is the one thing the sweep must not do. `run_after_10` records what it installed and deletes only what it stops declaring. |
| **Licensed skills download on every apply**                    | The HeroUI CDN sends `no-store` and no `ETag`, so a conditional request is not possible and a stamp file would be the only way to skip one. The two tarballs are 13 KB together, and the script replaces a skill only when the bytes differ, so an unchanged apply costs one request and prints nothing. Being offline warns and keeps the installed copy. |
| **`mattpocock-skills` plugin disabled**                        | The plugin ships 22 of the skills the inventory already declares. Two copies of a skill both reach the model, and the plugin's copy is pinned to whatever the marketplace last published rather than tracking upstream. |
| **A fallback URL on every skill archive**                      | A failed archive download fails chezmoi's whole source-state read, so with 116 third-party repositories tracked, one deletion would stop `chezmoi apply` from applying anything at all. `--keep-going` does not cover it and neither does `--refresh-externals=never` on a machine with no cache. A second URL pointing at a committed placeholder turns that into one directory with no SKILL.md, which no agent loads and the run script reports. `git-repo` externals need none of this, because their clone runs at write time and chezmoi already carries on past it. |
| **A per-entry `refresh` for heavy sources**                    | A `repo` entry downloads the whole repository to extract one directory, and the spread is extreme: 236 KB for mattpocock/skills against 136 MB for thedotmack/claude-mem, both for one skill. A single weekly period would move about 1.3 GB a week. Marking every source of 25 MB or more as quarterly leaves 390 MB weekly, and the number sits next to the entry that causes it. |
