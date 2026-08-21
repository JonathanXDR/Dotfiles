# Architecture

How this dotfiles system is organized, how data flows through it, and where to start when navigating the codebase.

> [!TIP]
> New here? Start with [Bird's Eye View](#-birds-eye-view) for the big picture, skim [Key Concepts](#-key-concepts) for the mental model, and jump to [Entry Points](#-entry-points) when you know what you want to change.

## 🦅 Bird's Eye View

This is a **macOS dotfiles system built on [chezmoi](https://chezmoi.io)** running in **symlink mode**. chezmoi symlinks plain configuration files into `$HOME`, renders the Go-templated ones as real copies, and runs idempotent setup scripts, all while injecting secrets from the macOS Keychain at apply time. Sensitive directories (SSH, GPG, SSL, kube, VPN) are symlinked straight to iCloud Drive, which makes iCloud the single source of truth for those keys.

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
│                            │ email, name, gpg, machine_type,                 │                                  │
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
│     │ dot_* templates              │     │ symlink_*.tmpl               │     │ .chezmoiscripts        │        │
│     │ (rendered)                   │     │ (iCloud paths)               │     │ (run_* scripts)        │        │
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
├── .chezmoi.toml.tmpl                  # User config (iCloud config.toml or prompts)
├── .chezmoidata.toml                   # Shared non-secret defaults
├── .chezmoidata/
│   └── zed.toml                        # Installed Zed extensions (written by zed:dump)
├── .chezmoiignore                      # Files excluded from $HOME
├── .chezmoitemplates/
│   ├── keychain                        # Keychain lookup (list "<id>" "<account>" <keychain> <field>)
│   └── shell-helpers                   # Reusable bash helpers for run scripts
│
│   # Setup scripts (run by chezmoi apply, numbered for ordering)
│
├── .chezmoiscripts/
│   ├── run_before_00-*                 # Unlock dotfiles keychain (every apply)
│   ├── run_once_before_01-*            # Install Homebrew
│   ├── run_once_before_02-*            # Import keychain tokens from iCloud
│   ├── run_onchange_after_03-*         # Install Homebrew packages (re-runs on Brewfile change)
│   ├── run_onchange_after_04-*         # Fix iCloud symlink permissions (re-runs on config change)
│   ├── run_onchange_after_05-*         # Bootstrap proxy LaunchAgent (re-runs on plist change, work only)
│   ├── run_onchange_after_06-*         # Install mise runtimes and global CLIs (re-runs on list change)
│   ├── run_once_after_07-*             # Fix zsh completion permissions
│   ├── run_after_08-*                  # Export keychain to iCloud (every apply)
│   └── run_onchange_after_09-*         # Symlink /etc/hosts → ~/.config/hosts (re-runs on hosts change)
│
│   # iCloud Drive symlinks (point $HOME directories at iCloud)
│
├── symlink_dot_ssh.tmpl                # ~/.ssh → iCloud
├── symlink_dot_ssl.tmpl                # ~/.ssl → iCloud (work only)
├── symlink_dot_vpn.tmpl                # ~/.vpn → iCloud (work only)
├── private_dot_gnupg/                  # ~/.gnupg/* → iCloud (6 symlinks)
│   ├── symlink_common.conf.tmpl
│   ├── symlink_trustdb.gpg.tmpl
│   ├── symlink_sshcontrol.tmpl
│   ├── symlink_private-keys-v1.d.tmpl
│   ├── symlink_public-keys.d.tmpl
│   └── symlink_openpgp-revocs.d.tmpl
├── private_dot_kube/                   # ~/.kube/config → iCloud
│   └── symlink_config.tmpl
│
│   # Proxy daemon (work only, ignored on personal via .chezmoiignore)
│
├── dot_local/bin/
│   └── executable_proxy-watchd.tmpl    # Proxy state script run by LaunchAgent (work only)
├── Library/LaunchAgents/
│   └── local.proxy-watchd.plist.tmpl   # LaunchAgent watching network changes (work only)
│
│   # Shell configuration (sourced on every terminal open)
│
├── dot_zshenv                          # PATH for non-interactive shells (mise shims)
├── dot_zprofile                        # Restores the mise shims after macOS path_helper (login shells)
├── dot_zshrc                           # Shell orchestrator
├── dot_exports.tmpl                    # Env vars, history, locale, zsh options
├── dot_functions                       # Shell functions
├── dot_aliases                         # Command aliases
├── dot_plugins                         # Oh My Zsh plugin list, compiled by antidote
├── dot_completions                     # Zsh completions, plugins, Kiro CLI support
│
│   # Tool configuration
│
├── dot_gitconfig.tmpl                  # Git user, GPG signing, LFS, pull strategy
├── dot_gitignore_global                # Global gitignore (referenced by dot_gitconfig.tmpl)
├── dot_npmrc.tmpl                      # npm registry tokens (from keychain)
├── dot_wakatime.cfg.tmpl               # WakaTime API key (from keychain)
├── dot_config/
│   ├── hosts.tmpl                      # /etc/hosts source (machine-type aware)
│   ├── mise/config.toml                # Language runtimes + global CLI packages
│   └── zed/settings.json.tmpl          # Zed editor + MCP server keys (from keychain)
├── private_dot_claude/                 # ~/.claude/* (0700)
│   ├── private_CLAUDE.md               # Global Claude Code instructions (all projects)
│   ├── private_settings.json.tmpl      # Claude Code user settings (plugins, marketplaces, hooks)
│   ├── private_hooks/                  # ~/.claude/hooks/ (0700)
│   │   └── private_executable_block-git-push.sh  # PreToolUse guard, blocks unrequested git push
│   └── private_plugins/                # ~/.claude/plugins/ (0700)
│       ├── installed_plugins.json.tmpl   # Claude Code plugin install state
│       └── known_marketplaces.json.tmpl  # Claude Code marketplace registry
│
│   # IDE settings
│
├── Library/Application Support/Code/User/
│   ├── settings.json.tmpl              # VS Code settings (home dir templated for Java/Gradle paths)
│   └── keybindings.json                # VS Code keybindings
│
│   # Package lists (read by run scripts, not copied to $HOME)
│
├── Brewfile.personal                   # Homebrew packages (personal)
└── Brewfile.work                       # Homebrew packages (work)
```

## 🔑 Key Concepts

### Symlink Mode

chezmoi runs with `mode = "symlink"`, so plain managed files in `$HOME` are symlinks into the chezmoi source directory rather than independent copies. Anything chezmoi cannot symlink is written as a real **copy**: templates (`.tmpl` files have to be rendered first) and files with a restrictive mode (the `private_` / `0600` attribute). For a file to become a true symlink it must be plain, with no `.tmpl` suffix and no `private_` prefix. A parent `private_dot_*/` directory still keeps the folder itself at `0700`.

> [!TIP]
> Symlinked `$HOME` files point at the source directory, so you can edit them in place. Editing `~/.zshrc` and editing the source file are the same write, which makes `chezmoi edit` optional. Templates and `private_` files are the exception (e.g. `~/.claude/settings.json` or `~/.claude/CLAUDE.md`). They are written as copies, so when a tool such as Claude Code rewrites the target, nothing reaches the source. Run `chezmoi add` to capture those changes, or `chezmoi apply` to restore the tracked version.

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

The `run_onchange_after_04-fix-icloud-permissions` script re-runs whenever the iCloud path or the machine type changes, and fixes the permissions on the symlink targets (broadly `0700` for directories and `0600` for private material, with SSH public keys and client config plus the work VPN profiles left readable at `0644`).

> [!NOTE]
> The `symlink_dot_ssl.tmpl` and `symlink_dot_vpn.tmpl` files sit in the source tree on every machine, but a conditional block in `.chezmoiignore` filters them out on personal machines. Being in the repo does not mean they are applied.

### File Naming Convention

chezmoi maps source filenames to target paths by replacing prefixes and stripping suffixes:

| Source                                           | Target                              | Notes                                                                           |
| ------------------------------------------------ | ----------------------------------- | ------------------------------------------------------------------------------- |
| `dot_zshrc`                                      | `~/.zshrc`                          | `dot_` becomes `.`, symlinked                                                   |
| `dot_exports.tmpl`                               | `~/.exports`                        | Rendered copy, because templates cannot be symlinked                            |
| `private_dot_claude/private_settings.json.tmpl`  | `~/.claude/settings.json`           | Rendered copy, because both `.tmpl` and `private_` rule out a symlink           |
| `private_dot_claude/private_plugins/*.json.tmpl` | `~/.claude/plugins/*.json`          | Claude Code runtime state, rendered copies with the home directory templated in |
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
│    tree_ignore, dock_apps, cisco_vpn_bin                                            │
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
| `[[textconv]]`     | Pipes `**/*.json` through `jq .` so `chezmoi diff` shows readable JSON diffs                              |

### Secrets Management

iCloud Drive stores two categories of data: **secrets** (keychain backup) and **non-secret config** (`config.toml`).

Secrets live in a dedicated `dotfiles` keychain (`~/Library/Keychains/dotfiles.keychain-db`), kept apart from the user's `login` keychain so managed entries do not mix with Wi-Fi, Safari, and AirDrop items. The dotfiles keychain locks on system sleep with no idle timeout (`security set-keychain-settings -l`). The [`run_before_00-unlock-keychain`](.chezmoiscripts/run_before_00-unlock-keychain.sh.tmpl) script unlocks it once at the start of every `chezmoi apply`, so every secret-reading template renders in a single pass without per-call prompts. Templates read entries at apply time through the `keychain` template helper.

> [!IMPORTANT]
> The dotfiles keychain is the source of truth. The iCloud tokens file is a backup, imported on a fresh machine by [`02-import-keychain`](.chezmoiscripts/run_once_before_02-import-keychain.sh.tmpl) and rewritten from the keychain by [`08-export-keychain`](.chezmoiscripts/run_after_08-export-keychain.sh.tmpl) after any apply where the two drift apart. Always use `secret:set` to add a secret, or `secret:rename` to update one. Never edit the iCloud tokens file directly.

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
                             │  script 08: secrets:export (auto, every apply)
                             v
┌───────────────────────────────────────────────────────────┐
│ iCloud Drive (backup updated)                             │
└───────────────────────────────────────────────────────────┘
```

**How it works:**

1. **The dotfiles keychain is the source of truth for secrets.** Templates read secrets with `includeTemplate "keychain" (list "<id>" "<account>" .keychain_name .keychain_lookup_field)`, which wraps `security find-generic-password` against the configured keychain and falls back to an empty string.
2. **The keychain is unlocked once per apply.** Script `00` (`run_before_00-unlock-keychain`) runs before any template is rendered, calls `security unlock-keychain` with the cached password, and re-applies the lock policy (`-l` only), so the keychain stays open for the rest of the apply. That is what keeps secret-reading templates prompt-free.
3. **iCloud Drive is the backup.** Script `02` creates the dotfiles keychain on a fresh machine and imports tokens from iCloud into it. Script `08` re-exports keychain entries back to iCloud after every apply.
4. **Shell functions** in `dot_functions` cover the full lifecycle. The `secret:` functions operate on a single entry, the `secrets:` functions on the whole set:
   - `secret:set <id> <account> <where> <kind> [comment]` to add a new entry (prompts for password)
   - `secret:get <id> <account>`, `secret:copy <id> <account>` to read (stdout / clipboard with auto-clear)
   - `secret:rename <old_id> <old_a> <new_id> <new_a> [new_where] [new_kind] [new_comment]` to move or update atomically
   - `secret:remove <id> <account>` to delete (and re-sync iCloud)
   - `secrets:list` for the sorted ID / Account / Kind / Used by / Where table (enumerates the keychain)
   - `secrets:import` to pull tokens-file entries missing from the keychain and report drift
   - `secrets:export` rebuilds the tokens file from the keychain (auto-runs via script `08`)

> [!NOTE]
> **Why a custom `keychain` template instead of chezmoi's built-in `keyring`?**
> The `keyring` function panics when a key is missing. The `keychain` helper wraps `security find-generic-password ... || true` in `includeTemplate`, so a missing key yields an empty string. Templates can then render a warning comment instead of failing.

**Naming convention.** Each managed entry uses five native macOS keychain fields:

- **Where** (`-s` / Service): the URL of the provider, stored in the keychain only (never in committed templates). macOS enforces `(Service, Account)` uniqueness at the storage layer.
- **Account** (`-a`): the identity at that provider.
- **Name** (`-l` / Label): the friendly identifier passed as `<id>` to every `secret:*` function and to `includeTemplate "keychain"`. By default it is also the **lookup key** templates use (configurable, see below).
- **Kind** (`-D` / `desc` attribute): the secret type, in Apple-style title case.
- **Comments** (`-j` / `icmt` attribute): the consumer (what reads this secret).

All entries are created with the `-A` flag so chezmoi templates can read them at apply time without per-app keychain confirmation prompts.

The iCloud tokens file mirrors all five fields plus the password as tab-separated columns: `id<TAB>account<TAB>where<TAB>kind<TAB>comment<TAB>password`. Tabs rather than colons, because Where values contain `://`.

**Keychain configuration** (`.chezmoidata.toml`, defaults shown):

```toml
keychain_name         = "dotfiles"  # ~/Library/Keychains/<name>.keychain-db
keychain_lookup_field = "name"      # name | where | kind | comment
```

The `keychain_lookup_field` value selects the `security` flag that templates query with (`name` → `-l`, `where` → `-s`, `kind` → `-D`, `comment` → `-j`). The default, `name`, keeps URLs out of committed `.tmpl` files.

The **master password** is prompted once during `chezmoi init` (`promptStringOnce`) and cached in the machine-local `~/.config/chezmoi/chezmoi.toml`. Leaving it empty (the default) ties the keychain to the login session's unlock state, which behaves exactly like `login.keychain`. Setting a value creates a keychain that is locked by default and needs an explicit unlock in each session.

**Templates that read secrets:**

| Template                            | What it reads                           | Condition |
| ----------------------------------- | --------------------------------------- | --------- |
| `dot_npmrc.tmpl`                    | npm registry token                      | Always    |
| `dot_npmrc.tmpl`                    | corporate Artifactory tokens            | Work only |
| `dot_exports.tmpl`                  | NTLM proxy credentials                  | Work only |
| `dot_wakatime.cfg.tmpl`             | WakaTime API key                        | Always    |
| `dot_config/zed/settings.json.tmpl` | Zed editor MCP server tokens (multiple) | Always    |

For the live values (ID / Account / Kind / Used by / Where), run `secrets:list`.

### Machine-Type Branching

The `machine_type` variable (`personal` or `work`), set once during `chezmoi init`, drives conditional behavior:

| Layer              | `personal`                              | `work`                                                    |
| ------------------ | --------------------------------------- | --------------------------------------------------------- |
| **Brewfile**       | `Brewfile.personal`                     | `Brewfile.work`                                           |
| **Proxy**          | Disabled (`always_proxy_probe = false`) | Event-driven via LaunchAgent + `proxy:probe` fallback     |
| **SSL**            | No extra CA certs                       | Corporate CA bundle symlinked from iCloud                 |
| **VPN**            | No config                               | Cisco AnyConnect config symlinked from iCloud             |
| **Auth**           | No NTLM                                 | NTLM credentials for Alpaca proxy                         |
| **npm registries** | Public only                             | Public + corporate Artifactory                            |
| **/etc/hosts**     | Standard entries only                   | Work-specific hostnames added via `dot_config/hosts.tmpl` |

### Shell Loading Order

When a new terminal opens, `~/.zshrc` loads files in this exact sequence:

```text
  ~/.zshenv ────────────── mise shims (every zsh, including non-interactive)
          │
          v
  /etc/zprofile ────────── macOS path_helper rebuilds PATH (login shells only),
          │                demoting the shims that .zshenv prepended
          v
  ~/.zprofile ──────────── restores the mise shims to the front of PATH
          │
          v
  Kiro CLI pre-hook ────── (if installed)
          │
          v
  ~/.exports ───────────── Env vars, proxy, locale, history, zsh setopt
          │
          v
  ~/.functions ─────────── Utility functions (proxy, VPN, secrets, toolchain, Git, ...)
          │
          v
  PATH setup ───────────── Tool paths, Homebrew, conda, then mise activation (must be last)
          │
          v
  plugins:load ─────────── Oh My Zsh bundle, compiled by antidote from ~/.plugins
          │
          v
  ~/.aliases ───────────── Command aliases (overrides the bundle where the two collide)
          │
          v
  ~/.completions ───────── Zsh completions, autosuggestions, syntax highlighting
          │
          v
  Runtime hooks ────────── conda auto-activate, proxy state load, SSH agent
          │
          v
  Daily checks ─────────── mise tool upgrades, brew deprecation/outdated (gated to once per 24h)
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
| `run_after_`          | Every `chezmoi apply`, after files  | Export keychain to iCloud                            |

Every script includes `{{ template "shell-helpers" . }}`, which provides shared bash helpers:

| Helper                  | Purpose                                                |
| ----------------------- | ------------------------------------------------------ |
| `_log <level> <msg>`    | Colored logging (error, success, warning, info, debug) |
| `_cmd_exists <cmd>`     | Check whether a command exists in PATH                 |
| `_ensure_brew`          | Load Homebrew shellenv (Apple Silicon and Intel)       |
| `_ensure_icloud <path>` | Trigger an iCloud Drive download for a path            |

## 🗺️ Entry Points

| What you want to do                  | Start here                                                                              |
| ------------------------------------ | --------------------------------------------------------------------------------------- |
| Understand shell startup             | `dot_zshrc`                                                                             |
| Add an environment variable          | `dot_exports.tmpl`                                                                      |
| Add a shell function                 | `dot_functions`                                                                         |
| Add a command shortcut               | `dot_aliases`                                                                           |
| Add or remove an Oh My Zsh plugin    | `dot_plugins` (the next shell rebuilds the compiled bundle)                             |
| Force a plugin bundle rebuild        | `rm ~/.cache/zsh/plugins.zsh`                                                           |
| Update the Oh My Zsh plugins         | `plugins:update` (runs once a day, alongside mise and brew)                             |
| Load a plugin if its tool exists     | `conditional:have:<tool>` in `dot_plugins`, guard in `dot_functions`                    |
| See which aliases shadow a binary    | `alias:shadows`                                                                         |
| Change a shared default              | `.chezmoidata.toml`                                                                     |
| Add a user-prompted value            | `.chezmoi.toml.tmpl`                                                                    |
| Add machine-type config (non-secret) | `config.toml` on iCloud Drive                                                           |
| Add a Homebrew package               | `Brewfile.personal` or `Brewfile.work`                                                  |
| Refresh this machine's Brewfile      | `brew:dump` (adds `--no-npm` and picks the right Brewfile)                              |
| Keep a formula out of the Brewfile   | `brew tab --no-installed-on-request <formula>`                                          |
| Refresh the Zed extension list       | `zed:dump` (Zed has no CLI for this)                                                    |
| Add a runtime or global CLI package  | `dot_config/mise/config.toml`                                                           |
| Edit global Claude Code instructions | `private_dot_claude/private_CLAUDE.md`                                                  |
| Add a managed secret                 | `secret:set <id> <account> <where> <kind> [comment]` then `includeTemplate "keychain"`  |
| Rename or update a secret            | `secret:rename <old_id> <old_a> <new_id> <new_a> [new_where] [new_kind] [new_comment]`  |
| Inspect or audit secrets             | `secrets:list` (table view), `secrets:import` (sync + drift), `secret:copy` (clipboard) |
| Change keychain name or lookup field | `.chezmoidata.toml` (`keychain_name`, `keychain_lookup_field`)                          |
| Set a master keychain password       | Re-run `chezmoi init` (the `promptStringOnce` for `keychain_password`)                  |
| Manage `/etc/hosts` entries          | `dot_config/hosts.tmpl`                                                                 |
| Symlink a new directory to iCloud    | Create a `symlink_dot_<name>.tmpl` with the iCloud path                                 |
| Add a new setup step                 | Create a numbered `run_*` script in `.chezmoiscripts/`                                  |
| Modify shared script helpers         | `.chezmoitemplates/shell-helpers`                                                       |
| Debug proxy daemon                   | `proxyd:status`, `proxyd:log`, or `proxyd:log 1h`                                       |
| Reload proxy daemon                  | `proxyd:reload`                                                                         |

## 💡 Design Decisions

| Decision                                                      | Rationale                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| ------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Symlink mode**                                              | Editing a symlinked `$HOME` file edits the source directly, so no `chezmoi edit` is needed. Templates and `private_` files are the exception, and chezmoi writes them as real copies, because rendered output and restrictive modes cannot be expressed as a symlink.                                                                                                                                                                                                    |
| **iCloud symlinks for SSH/GPG/SSL/kube/VPN**                  | One copy of every key across all machines, with no copy scripts to maintain. chezmoi creates the symlinks and a `run_onchange_after` script fixes the permissions.                                                                                                                                                                                                                                                                                                       |
| **Dedicated dotfiles keychain over login keychain**           | Managed entries get their own sidebar entry in Keychain Access instead of mixing with Safari and Wi-Fi items. An empty unlock password ties the keychain to the login session, so it feels the same to use. Secrets never sit in plaintext in the repo, and FileVault covers rendered files at rest.                                                                                                                                                                     |
| **`-A` flag on every managed entry**                          | Lets any process running as the user read the entry with no confirmation prompt, which is what allows chezmoi templates to render unattended. The trade-off against the login keychain's per-app prompts is that malware running as the user can silently read these credentials. Acceptable for personal dev secrets behind FileVault, screen lock, and a strong Apple ID with 2FA.                                                                                     |
| **Upfront unlock (`run_before_00`) over per-call prompts**    | The `securityd` daemon does not manage a custom keychain the way it manages `login.keychain`, so every `security find-generic-password` call against a locked keychain raises its own prompt. One `unlock-keychain` at the start of each apply turns ten-plus prompts into none. It also re-applies `set-keychain-settings -l` (lock on sleep, no idle timeout), so a misconfigured keychain on an existing machine repairs itself.                                      |
| **Tokens file mode `0600`**                                   | Enforced by `_secrets:ensure-tokens-file` (an idempotent `chmod`). Defends against reads by other local users on a shared Mac, even though the file is also encrypted in iCloud and covered by FileVault at rest.                                                                                                                                                                                                                                                        |
| **Configurable keychain via `.chezmoidata.toml`**             | The `keychain_name` and `keychain_lookup_field` values let a fork change the keychain filename and the lookup field (Label, Service, Kind, or Comments) without touching any template. The default, `name` (Label), keeps URLs out of committed `.tmpl` files entirely.                                                                                                                                                                                                  |
| **Action-first log convention**                               | Every `log` / `_log` message starts with a verb (`Imported`, `Failed to update`, `Skipped`, `Installing…`) and keeps formatting colons out of the body, so the `<Level>:` prefix carries the only formatting colon. Colons inside data values, such as URLs or a function name like `secret:rename`, are fine. Failures can be found with a `^Error:` grep, and the level and the action both read in one line.                                                          |
| **iCloud `config.toml` over init prompts**                    | Proxy hosts, SSL cert names, and enterprise domains are sensitive organizational details. A TOML file on iCloud with `[work]` and `[personal]` sections keeps them out of the repo.                                                                                                                                                                                                                                                                                      |
| **`keychain` template helper**                                | Wraps `security find-generic-password` in a reusable one-liner. Returns an empty string for a missing key, whereas chezmoi's `keyring` panics.                                                                                                                                                                                                                                                                                                                           |
| **Numbered run scripts**                                      | Deterministic ordering rules out race conditions (the keychain import in script 02 has to finish before any template reads a secret).                                                                                                                                                                                                                                                                                                                                    |
| **`run_once_` for setup, `run_onchange_` for content-driven** | Embedded content hashes mean Homebrew packages and the mise tool list are only reinstalled when their source files actually change.                                                                                                                                                                                                                                                                                                                                      |
| **Separate Brewfiles per machine type**                       | Personal and work machines have very different toolchains. Two focused lists are easier to maintain than one list full of conditionals. Each file is named after the `machine_type` value it serves (`Brewfile.personal`, `Brewfile.work`), which chezmoi constrains to those two, so the run script and `brew:dump` derive the name instead of mapping it.                                                                                                              |
| **`scriptEnv` for Homebrew flags**                            | `HOMEBREW_NO_AUTO_UPDATE=1` stops Homebrew from auto-updating during scripted installs, which keeps apply fast and deterministic.                                                                                                                                                                                                                                                                                                                                        |
| **LaunchAgent for proxy detection**                           | Replaces a per-shell `nc` probe (~3s) with an event-driven daemon that watches `/Library/Preferences/SystemConfiguration` and `/var/run/resolv.conf` (covering Wi-Fi and VPN). Shell startup only reads a cached state file (~0ms), falling back to `proxy:probe` on first boot.                                                                                                                                                                                         |
| **mise activated last in `.zshrc`**                           | mise resolves versions inside a compiled binary, not a sourced shell script, so there is no lazy-loading trick and no `cd` hook of our own to maintain. Ordering is the one hard rule. Activation snapshots `PATH` and re-derives from that snapshot on every prompt, so it must run after `brew shellenv` and every `path:add`. Homebrew keeps its own `node` as a dependency of eslint, prettier, and vercel, and this ordering is what keeps that copy behind mise's. |
| **`.zprofile` restores the mise shims**                       | `.zshenv` puts the shims first, then macOS `/etc/zprofile` runs `path_helper -s`, which rebuilds `PATH` and appends the rest at the end. On a login shell the shims land behind `/opt/homebrew/bin`, so Homebrew's node wins. Interactive shells recover through `mise activate zsh`, but login shells that never read `.zshrc` do not, and those are the shells `.zshenv` exists to cover. Chosen over `setopt no_global_rcs`, which disables `/etc/zprofile` outright. |
| **Every mise command pins itself to `$HOME`**                 | mise resolves `[tools]` from the working directory upward, and trust does not gate that: it asks for trust before running `[env]`, `[tasks]`, and `[hooks]`, never before reading a tool list. An unscoped `mise upgrade` from `run:daily` would therefore install the toolchain of whatever project the first terminal of the day opened in. `install`, `upgrade`, `prune`, and `cache clear` all run with `-C "$HOME"`.                                                |
| **`mise prune` after `mise install`**                         | `mise install` only adds. Dropping a tool from `config.toml` re-fires the script but leaves the old install and its shims in place, and `.zshenv` keeps that shim directory on `PATH` for every zsh. `prune` removes versions no tracked config still asks for, so project toolchains survive, and it rebuilds the shim directory in the same pass.                                                                                                                      |
| **antidote for Oh My Zsh plugins**                            | Plugins are listed in `dot_plugins` and compiled into one flat `~/.cache/zsh/plugins.zsh`. A normal startup sources that single file and does no plugin resolution, because antidote itself loads only when the list is newer than the compiled bundle. Same shape as `mise/config.toml`: a plain tracked file, symlinked rather than rendered, so editing `~/.plugins` edits the source and the next shell rebuilds. The compiled output lives under `~/.cache` because it is derived, which keeps `$HOME` to the one file you edit. Chosen over a full Oh My Zsh install, which brings a framework that sets its own options and prompt, and over a hand-rolled clone, which would mean owning the update logic. A `run_onchange_` script was considered and rejected, because it would only move the one-time build from the first shell to `chezmoi apply`, at the cost of a second code path. |
| **`plugins:update` on the daily stamp**                       | antidote clones a plugin once and never revisits it, so without this the Oh My Zsh checkout would stay at whatever commit it had on the day it was cloned. `run:daily plugins plugins:update` puts it on the same 24-hour stamp as `mise:update` and `brew:check`. It rebuilds the bundle in place rather than deleting it, so a failed rebuild leaves a working older bundle instead of a shell with no plugins. The four Homebrew plugins in `.completions` are unaffected, because `brew upgrade` already covers those. |
| **Completion cache enabled in `plugins:load`**                | `zstyle ':completion:*' use-cache on`, with a `cache-path` under `ZSH_CACHE_DIR`. zsh ships this off, and several plugins call `_retrieve_cache` and `_store_cache` while they load. Without it the composer plugin re-runs `composer global config bin-dir` on every shell to find its vendor path, measured at 236 ms against 6 ms once the cache answers. It has to be set in `plugins:load` rather than `.completions`, because the plugins ask for it before `.completions` runs. |
| **`plugins:load` is a function, not inline `.zshrc`**         | `.zshrc` is an orchestrator that calls named functions (`proxy:set`, `conda:load`, `ssh:agent`), so the plugin loader is one too. Sourcing the bundle inside a function was checked rather than assumed: aliases, functions and `typeset -g` values all survive it, and the only value that stops reaching the shell is the git plugin's `git_version` scratch variable. |
| **`alias:shadows` over a longer correction list**             | The bundle has no equivalent of `alias:safe`, so a plugin update can quietly claim a command name. Rather than trying to predict that once, `alias:shadows` prints the current answer, and the corrections list in `.aliases` records the decisions already taken. It is what caught the nestjs plugin claiming `ng` from the Angular CLI. |
| **`have:tty` gate on fzf**                                    | fzf's setup evaluates `fzf --zsh`, which saves and restores shell options. A shell with no terminal has no ZLE to restore, so `zsh -ic` printed `can't change option: zle` twice. Such a shell has no use for key bindings anyway. |
| **Plugins load before `.aliases`**                            | The bundle claims 808 names and `.aliases` declares 111, of which 21 overlap. Loading plugins first makes `.aliases` the authority on its own names, so every override is a visible line in a tracked file rather than a silent win for whichever file loaded last. Seven names went to the plugins instead (`l`, `la`, `gba`, `gbd`, `gcl`, `glg`, `grep`) and were deleted from `.aliases` rather than redeclared, so no third-party alias text is copied into this repo. |
| **`alias:_taken` instead of `cmd:exists` in the alias guards** | `cmd:exists` is `command -v`, which resolves aliases as well as binaries. With the bundle loading first, every plugin alias looked like an existing command, so `alias:safe` stepped aside for all of them. The guards now test `$commands`, `$functions` and `$builtins` only. Shadowing a real command is still refused and still warned about. Sitting on top of a plugin alias is the intended behavior. |
| **Deferred `compdef` queue**                                  | The git, kubectl, npm and gradle plugins call `compdef` as they load, but the completion system does not start until `.completions`, which has to stay last because zsh-syntax-highlighting only wraps widgets that already exist. `plugins:load` installs a stub that queues those calls, and `.completions` replays them. Running `compinit` early instead does not work, because a second `compinit` discards everything registered against the first. |
| **`conditional:have:<tool>` for plugins with no tool**        | `terraform`, `sbt`, `multipass`, `mongocli`, `pre-commit` and `rails` are listed but wrapped in a guard, so each activates the day its tool is installed and costs a single test until then. `have:rails` is hand-written rather than generated, because macOS ships `/usr/bin/rails`, a stub that only prints "Rails is not currently installed", so a plain `cmd:exists` would load 70 aliases on a machine with no Rails. |
| **Conventional Commit aliases in `dot_gitconfig.tmpl`**       | The `git-commit` plugin creates them by running `git config --global`, which rewrites `~/.gitconfig` behind chezmoi's back and drifts from the source on every apply. The same twelve types live in the template instead, sharing one `cc` implementation so each alias only binds its type. Verified to behave identically to the plugin across a 16-case matrix. |
| **compinit caching**                                          | Running `compinit -C` skips the full completion rebuild while `~/.zcompdump` is less than 24 hours old (checked with the zsh glob qualifier `(N.mh-24)`). A full rebuild runs once a day to pick up newly installed completions.                                                                                                                                                                                                                                         |
| **`run:daily` update gating**                                 | The `run:daily` wrapper puts `mise:update` and `brew:check` behind a stamp file in `~/.cache/daily/`, with a `(N.mh-24)` freshness check that costs zero forks. Keeps slow update commands off every shell startup.                                                                                                                                                                                                                                                      |
| **`/etc/hosts` symlink**                                      | chezmoi renders `dot_config/hosts.tmpl` into `~/.config/hosts` with machine-type-aware entries (work entries are dropped on personal). Script 09 symlinks `/etc/hosts` → `~/.config/hosts` and re-runs whenever the template content changes.                                                                                                                                                                                                                            |
| **Global Claude instructions as `private_CLAUDE.md`**         | Claude Code loads `~/.claude/CLAUDE.md` at the start of every session in every project, before any repository `CLAUDE.md`, so the file carries only cross-project rules and lets repository conventions win. The `private_` prefix keeps the rendered file at `0600` like the rest of `~/.claude`, and it also keeps the source name clear of the global gitignore's `**/CLAUDE.md` rule, which would otherwise ignore the source file in this very repo. Like the settings template, the file is written as a copy, so edits made directly to the target need `chezmoi add` to reach the source. |
| **A PreToolUse hook guards `git push`**                       | "Never push unless explicitly asked" needs mechanical enforcement, because CLAUDE.md instructions are advisory and the `claude` alias runs with `--dangerously-skip-permissions`, which skips `ask` permission rules. A `deny` rule would block requested pushes too. The settings filter narrows the hook to git commands as a fast path, and the script itself inspects the actual command, blocks any `git push` invocation (including flagged forms such as `git -C <path> push`) with exit code 2, and tells Claude to re-run the command with `CLAUDE_PUSH_OK=1` once the user has explicitly asked for the push. The `private_executable_` prefix renders the script at `0700`. |
