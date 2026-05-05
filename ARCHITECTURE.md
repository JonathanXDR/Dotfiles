# Architecture

How this dotfiles system is organized, how data flows through it, and where to start when navigating the codebase.

> [!TIP]
> New here? Start with [Bird's Eye View](#-birds-eye-view) for the big picture, skim [Key Concepts](#-key-concepts) for the mental model, and jump to [Entry Points](#-entry-points) when you know what you want to change.

## 🦅 Bird's Eye View

This is a **macOS dotfiles system built on [chezmoi](https://chezmoi.io)** running in **symlink mode**. chezmoi renders Go-templated configuration files, symlinks them into `$HOME`, and executes idempotent setup scripts, all while injecting secrets from the macOS Keychain at apply time. Sensitive directories (SSH, GPG, SSL, kube, VPN) are symlinked directly to iCloud Drive, making iCloud the single source of truth for both secrets and keys.

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
│     │ ~/.exports                   │     │ ~/.gnupg  → iCloud           │     │ npm globals            │        │
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
├── .chezmoiignore                      # Files excluded from $HOME
├── .chezmoitemplates/
│   ├── keychain                        # Keychain lookup helper (includeTemplate "keychain" (list "svc" "acct"))
│   └── shell-helpers                   # Reusable bash helpers for run scripts
│
│   # Setup scripts (executed by chezmoi apply, numbered for ordering)
│
├── .chezmoiscripts/
│   ├── run_before_00-*                 # Unlock dotfiles keychain (every apply)
│   ├── run_once_before_01-*            # Install Homebrew
│   ├── run_once_before_02-*            # Import keychain tokens from iCloud
│   ├── run_onchange_after_03-*         # Install Brew packages (re-runs on Brewfile change)
│   ├── run_onchange_after_04-*         # Fix iCloud symlink permissions (re-runs on config change)
│   ├── run_onchange_after_05-*         # Bootstrap proxy LaunchAgent (re-runs on plist change, work only)
│   ├── run_onchange_after_06-*         # Install global npm packages (re-runs on list change)
│   ├── run_once_after_07-*             # Fix zsh completion permissions
│   ├── run_after_08-*                  # Export keychain to iCloud (every apply)
│   └── run_onchange_after_09-*         # Symlink /etc/hosts → ~/.config/hosts (re-runs on hosts change)
│
│   # iCloud Drive symlinks (point $HOME dirs to iCloud)
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
├── dot_zshrc                           # Shell orchestrator
├── dot_exports.tmpl                    # Env vars, history, locale, zsh options
├── dot_functions                       # Shell functions
├── dot_aliases                         # Command aliases
├── dot_completions                     # Zsh completions, plugins, Kiro CLI compat
│
│   # Tool configuration
│
├── dot_gitconfig.tmpl                  # Git user, GPG signing, LFS, pull strategy
├── dot_gitignore_global                # Global gitignore (ref'd by dot_gitconfig.tmpl)
├── dot_npmrc.tmpl                      # npm registry tokens (from keychain)
├── dot_npm.globals                     # Global npm packages
├── dot_wakatime.cfg.tmpl               # WakaTime API key (from keychain)
├── dot_config/
│   ├── hosts.tmpl                      # /etc/hosts source (machine-type aware)
│   └── zed/settings.json.tmpl          # Zed editor + MCP server keys (from keychain)
├── private_dot_claude/                 # ~/.claude/* (0700)
│   └── private_settings.json.tmpl      # Claude Code user settings (plugins, hooks, home dir templated)
│
│   # IDE settings
│
├── Library/Application Support/Code/User/
│   ├── settings.json.tmpl              # VS Code settings (home dir templated for Java/Gradle paths)
│   └── keybindings.json                # VS Code keybindings
│
│   # Package lists (consumed by run scripts, not copied to $HOME)
│
├── Brewfile.personal                   # Homebrew packages (personal)
└── Brewfile.swisscom                   # Homebrew packages (work)
```

## 🔑 Key Concepts

### Symlink Mode

chezmoi runs with `mode = "symlink"`, meaning managed files in `$HOME` are symlinks to the chezmoi source directory rather than independent copies.

> [!TIP]
> Because `$HOME` files are symlinks to the source directory, you can edit them directly. `chezmoi edit` is optional, not required, since editing `~/.zshrc` and editing the source file are the same write.

For sensitive directories (SSH, GPG, SSL, kube, VPN), chezmoi creates symlinks that point to **iCloud Drive** via `symlink_*` templates. This makes iCloud the single source of truth:

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

The `run_onchange_after_04-fix-icloud-permissions` script re-runs whenever the iCloud path or machine type changes, ensuring symlink targets have correct permissions (700 for dirs, 600 for private keys, 644 for public keys).

> [!NOTE]
> The `symlink_dot_ssl.tmpl` and `symlink_dot_vpn.tmpl` files exist in the source tree on every machine but are filtered out on personal machines via a conditional block in `.chezmoiignore`. Their presence in the repo doesn't mean they're applied.

### File Naming Convention

chezmoi maps source filenames to target paths by replacing prefixes and stripping suffixes:

| Source                            | Target                              | Notes                             |
| --------------------------------- | ----------------------------------- | --------------------------------- |
| `dot_zshrc`                       | `~/.zshrc`                          | `dot_` becomes `.`, symlinked     |
| `dot_exports.tmpl`                | `~/.exports`                        | `.tmpl` rendered then symlinked   |
| `symlink_dot_ssh.tmpl`            | `~/.ssh`                            | Symlink to rendered path (iCloud) |
| `private_dot_gnupg/`              | `~/.gnupg/`                         | `private_` sets 0700 permissions  |
| `Library/Application Support/...` | `~/Library/Application Support/...` | Literal path                      |

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
│  .chezmoidata.toml                                                                  │
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

1. **iCloud `config.toml`**: Machine-type-specific config (proxy, SSL, enterprise) is read from `~/Documents/General/Developer/.dotfiles/config.toml` under a `[work]` or `[personal]` section matching the selected `machine_type`. This file is synced via iCloud and kept outside the repo to avoid leaking sensitive infrastructure details.
2. **Interactive prompts (fallback)**: If `config.toml` is not found or is missing a key, chezmoi falls back to `promptStringOnce`, which asks once and caches the answer.

Both `dot_*` template files and run scripts in `.chezmoiscripts/` have access to all three layers.

### chezmoi Configuration

The `.chezmoi.toml.tmpl` also configures chezmoi behavior beyond template data:

| Section            | Purpose                                                                                                   |
| ------------------ | --------------------------------------------------------------------------------------------------------- |
| `mode = "symlink"` | Files in `$HOME` are symlinks to the source directory, not copies                                         |
| `[scriptEnv]`      | Sets `HOMEBREW_NO_AUTO_UPDATE=1`, `HOMEBREW_NO_INSTALL_CLEANUP=1`, `NONINTERACTIVE=1` for all run scripts |
| `[[textconv]]`     | Pipes `**/*.json` through `jq .` so `chezmoi diff` shows readable JSON diffs                              |

### Secrets Management

iCloud Drive stores two categories of data: **secrets** (keychain backup) and **non-secret config** (`config.toml`).

Secrets live in a dedicated `dotfiles` keychain (`~/Library/Keychains/dotfiles.keychain-db`), separate from the user's `login` keychain so dotfile-managed entries don't clutter Wi-Fi/Safari/AirDrop entries. The keychain locks on system sleep with no idle timeout (`security set-keychain-settings -l`). A dedicated [`run_before_00-unlock-keychain`](.chezmoiscripts/run_before_00-unlock-keychain.sh.tmpl) script unlocks it once at the start of every `chezmoi apply`, so all secret-reading templates render in a single pass without per-call prompts. Templates read from this keychain at apply time via the `keychain` template helper.

> [!IMPORTANT]
> The dotfiles keychain is the source of truth. The iCloud tokens file is a backup, imported on first-machine bootstrap by [`02-import-keychain`](.chezmoiscripts/run_once_before_02-import-keychain.sh.tmpl) and overwritten after every apply by [`08-export-keychain`](.chezmoiscripts/run_after_08-export-keychain.sh.tmpl). Always use `secret:set` to add or update. Never edit the iCloud tokens file directly.

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
                             │  script 08: secret:export (auto, every apply)
                             v
┌───────────────────────────────────────────────────────────┐
│ iCloud Drive (backup updated)                             │
└───────────────────────────────────────────────────────────┘
```

**How it works:**

1. **The dotfiles keychain is the source of truth for secrets.** Templates read secrets via `includeTemplate "keychain" (list "<id>" "<account>" .keychain_name .keychain_lookup_field)`, which wraps `security find-generic-password` against the configured keychain with a graceful fallback to empty string.
2. **The keychain is unlocked once per apply.** Script `00` (`run_before_00-unlock-keychain`) runs before any template is rendered, calls `security unlock-keychain` with the cached password, and re-applies the lock policy (`-l` only) so the keychain stays unlocked for the rest of the apply. This is what keeps secret-reading templates prompt-free.
3. **iCloud Drive is the backup.** Script `02` creates the dotfiles keychain on a fresh machine and imports tokens from iCloud into it. Script `08` re-exports keychain entries back to iCloud after every apply.
4. **Shell functions** in `dot_functions` cover the full lifecycle:
   - `secret:set <id> <account> <where> <kind> [comment]` to add or update (prompts for password)
   - `secret:get <id> <account>`, `secret:copy <id> <account>` to read (stdout / clipboard with auto-clear)
   - `secret:rename <old_id> <old_a> <new_id> <new_a> [new_where] [new_kind] [new_comment]` to move or update atomically
   - `secret:remove <id> <account>` to delete (and re-sync iCloud)
   - `secret:list` for the sorted Name / Account / Kind / Used by / Where table
   - `secret:check` to verify keychain matches the tokens file
   - `secret:export` rebuilds the tokens file (auto-runs via script `08`)

> [!NOTE]
> **Why a custom `keychain` template instead of chezmoi's built-in `keyring`?**
> The `keyring` function panics when a key is missing. The `keychain` helper wraps `security find-generic-password ... || true` via `includeTemplate`, which degrades gracefully to an empty string. Templates can then render a warning comment instead of failing.

**Naming convention.** Each managed entry uses five native macOS keychain fields:

- **Where** (`-s` / Service): the URL of the provider, stored in keychain only (never in committed templates). macOS enforces `(Service, Account)` uniqueness at the storage layer.
- **Account** (`-a`): the identity at that provider.
- **Name** (`-l` / Label): the friendly identifier passed as `<id>` to all `secret:*` functions and to `includeTemplate "keychain"`. By default this is the **lookup key** templates use (configurable; see below).
- **Kind** (`-D` / `desc` attribute): the secret type, in Apple-style title case.
- **Comments** (`-j` / `icmt` attribute): the consumer (what reads this secret).

All entries are created with the `-A` flag so chezmoi templates can read them at apply time without per-app keychain confirmation prompts.

The iCloud tokens file mirrors all five fields plus the password as tab-separated columns: `id<TAB>account<TAB>where<TAB>kind<TAB>comment<TAB>password`. Tabs (not colons) because Where values contain `://`.

**Keychain configuration** (`.chezmoidata.toml`, defaults shown):

```toml
keychain_name         = "dotfiles"  # ~/Library/Keychains/<name>.keychain-db
keychain_lookup_field = "name"      # name | where | kind | comment
```

`keychain_lookup_field` selects which `security` flag templates use to query (`name` → `-l`, `where` → `-s`, `kind` → `-D`, `comment` → `-j`). Default `name` keeps URLs out of committed `.tmpl` files.

**Master password** is prompted once during `chezmoi init` (`promptStringOnce`) and cached in machine-local `~/.config/chezmoi/chezmoi.toml`. Leaving it empty (the default) ties the keychain to the login session's unlock state, identical UX to `login.keychain`. A non-empty value creates a locked-by-default keychain that needs explicit unlock for each session.

**Templates that read secrets:**

| Template                            | What it reads                           | Condition |
| ----------------------------------- | --------------------------------------- | --------- |
| `dot_npmrc.tmpl`                    | npm registry token                      | Always    |
| `dot_npmrc.tmpl`                    | corporate Artifactory tokens            | Work only |
| `dot_exports.tmpl`                  | NTLM proxy credentials                  | Work only |
| `dot_wakatime.cfg.tmpl`             | WakaTime API key                        | Always    |
| `dot_config/zed/settings.json.tmpl` | Zed editor MCP server tokens (multiple) | Always    |

For the live values (Where / Account / Name / Kind / Used by), run `secret:list`.

### Machine-Type Branching

The `machine_type` variable (`personal` or `work`), set once during `chezmoi init`, drives conditional behavior:

| Layer              | `personal`                              | `work`                                                    |
| ------------------ | --------------------------------------- | --------------------------------------------------------- |
| **Brewfile**       | `Brewfile.personal`                     | `Brewfile.swisscom`                                       |
| **Proxy**          | Disabled (`always_proxy_probe = false`) | Event-driven via LaunchAgent + `proxy:probe` fallback     |
| **SSL**            | No extra CA certs                       | Corporate CA bundle symlinked from iCloud                 |
| **VPN**            | No config                               | Cisco AnyConnect config symlinked from iCloud             |
| **Auth**           | No NTLM                                 | NTLM credentials for Alpaca proxy                         |
| **npm registries** | Public only                             | Public + corporate Artifactory                            |
| **/etc/hosts**     | Standard entries only                   | Work-specific hostnames added via `dot_config/hosts.tmpl` |

### Shell Loading Order

When a new terminal opens, `~/.zshrc` loads files in this exact sequence:

```text
  Kiro CLI pre-hook ────── (if installed)
          │
          v
  ~/.exports ───────────── Env vars, proxy, locale, history, zsh setopt
          │
          v
  ~/.functions ─────────── Utility functions (proxy, VPN, secrets, Node, Git, ...)
          │
          v
  PATH setup ───────────── Homebrew, pyenv, RVM, Bun, tool-specific paths; NVM lazy-loaded on first use
          │
          v
  ~/.aliases ───────────── Command aliases
          │
          v
  ~/.completions ───────── Zsh completions, autosuggestions, syntax highlighting
          │
          v
  Runtime hooks ────────── nvmrc auto-switch, proxy state load, SSH agent
          │
          v
  Daily checks ─────────── bun, nvm, pyenv updates; brew deprecation/outdated (gated to once per 24h)
          │
          v
  SDKMAN ───────────────── Java SDK manager (must be last)
          │
          v
  Kiro CLI post-hook ───── (if installed)
```

### Run Script Execution

Scripts in `.chezmoiscripts/` are numbered for deterministic ordering. The filename prefix determines when and how often they run:

| Prefix                | Behavior                            | Example                                          |
| --------------------- | ----------------------------------- | ------------------------------------------------ |
| `run_before_`         | Every `chezmoi apply`, before files | Unlock dotfiles keychain                         |
| `run_once_before_`    | Once, before files are copied       | Install Homebrew, import keychain                |
| `run_onchange_after_` | Re-runs when script content changes | Brew packages (Brewfile hash embedded in script) |
| `run_once_after_`     | Once, after files are copied        | Fix zsh completion permissions                   |
| `run_after_`          | Every `chezmoi apply`, after files  | Export keychain to iCloud                        |

All scripts include `{{ template "shell-helpers" . }}` which provides shared bash utilities:

| Helper                  | Purpose                                         |
| ----------------------- | ----------------------------------------------- |
| `_log <level> <msg>`    | Colored logging (error, success, warning, info) |
| `_cmd_exists <cmd>`     | Check if a command exists in PATH               |
| `_ensure_brew`          | Load Homebrew shellenv (Apple Silicon + Intel)  |
| `_ensure_icloud <path>` | Trigger iCloud Drive download for a path        |
| `_ensure_nvm`           | Load NVM from `$NVM_DIR` or Homebrew fallback   |

## 🗺️ Entry Points

| What you want to do                  | Start here                                                                              |
| ------------------------------------ | --------------------------------------------------------------------------------------- |
| Understand shell startup             | `dot_zshrc`                                                                             |
| Add an environment variable          | `dot_exports.tmpl`                                                                      |
| Add a shell function                 | `dot_functions`                                                                         |
| Add a command shortcut               | `dot_aliases`                                                                           |
| Change a shared default              | `.chezmoidata.toml`                                                                     |
| Add a user-prompted value            | `.chezmoi.toml.tmpl`                                                                    |
| Add machine-type config (non-secret) | `config.toml` on iCloud Drive                                                           |
| Add a Homebrew package               | `Brewfile.personal` or `Brewfile.swisscom`                                              |
| Add a global npm package             | `dot_npm.globals`                                                                       |
| Add a managed secret                 | `secret:set <id> <account> <where> <kind> [comment]` then `includeTemplate "keychain"`  |
| Rename or update a secret            | `secret:rename <old_id> <old_a> <new_id> <new_a> [new_where] [new_kind] [new_comment]`  |
| Inspect or audit secrets             | `secret:list` (table view), `secret:check` (drift detection), `secret:copy` (clipboard) |
| Change keychain name or lookup field | `.chezmoidata.toml` (`keychain_name`, `keychain_lookup_field`)                          |
| Set a master keychain password       | Re-run `chezmoi init` (the `promptStringOnce` for `keychain_password`)                  |
| Manage `/etc/hosts` entries          | `dot_config/hosts.tmpl`                                                                 |
| Symlink a new dir to iCloud          | Create a `symlink_dot_<name>.tmpl` with the iCloud path                                 |
| Add a new setup step                 | Create a numbered `run_*` script in `.chezmoiscripts/`                                  |
| Modify shared script helpers         | `.chezmoitemplates/shell-helpers`                                                       |
| Debug proxy daemon                   | `proxyd:status`, `proxyd:log`, or `proxyd:log 1h`                                       |
| Reload proxy daemon                  | `proxyd:reload`                                                                         |

## 💡 Design Decisions

| Decision                                                      | Rationale                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| ------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Symlink mode**                                              | Edits to `$HOME` files modify the source directly, so no `chezmoi edit` is needed. Templates still render before symlinking.                                                                                                                                                                                                                                                                                                                                            |
| **iCloud symlinks for SSH/GPG/SSL/kube/VPN**                  | One copy of keys across all machines. No copy scripts needed: chezmoi creates the symlinks, a `run_onchange_after` script fixes permissions.                                                                                                                                                                                                                                                                                                                            |
| **Dedicated dotfiles keychain over login keychain**           | Visual isolation in Keychain Access (own sidebar entry), so managed entries don't mix with Safari/Wi-Fi. Empty unlock password ties it to the login session for identical UX. Secrets never exist in plaintext in the repo; FileVault covers rendered files at rest.                                                                                                                                                                                                    |
| **`-A` flag on every managed entry**                          | Allows any user-process to read without a confirmation prompt, which is required for chezmoi templates to render at apply time without UI. Trade-off: malware running as the user can silently read these credentials, vs. login-keychain's per-app prompt model. Acceptable for personal dev secrets behind FileVault, screen lock, and a strong Apple ID with 2FA.                                                                                                    |
| **Upfront unlock (`run_before_00`) over per-call prompts**    | A custom keychain is not auto-managed by `securityd` the way `login.keychain` is, so each `security find-generic-password` call against a locked keychain triggers its own unlock prompt. A single `unlock-keychain` at the very start of every apply collapses ten-plus prompts into zero. The script also re-applies `set-keychain-settings -l` (lock on sleep, no idle timeout), so existing machines with a misconfigured keychain are healed without manual steps. |
| **Tokens file mode `0600`**                                   | Enforced by `_secrets:ensure-tokens-file` (idempotent `chmod`). Defends against co-resident user reads on multi-user macOS even though the file is also encrypted in iCloud and protected by FileVault at rest.                                                                                                                                                                                                                                                         |
| **Configurable keychain via `.chezmoidata.toml`**             | `keychain_name` and `keychain_lookup_field` let forks change the keychain filename and which field is the lookup key (Label / Service / Kind / Comments) without touching templates. Default `name` (Label) keeps URLs out of committed `.tmpl` files entirely.                                                                                                                                                                                                         |
| **Action-first log convention**                               | Every `log` / `_log` message starts with a verb (`Imported`, `Failed to update`, `Skipped`, `Installing…`) and contains no formatting colons in the body, so the `<Level>:` prefix is the only colon. Lets users grep `^Error:` to extract failures and keeps level + action both readable in one line.                                                                                                                                                                 |
| **iCloud `config.toml` over init prompts**                    | Proxy hosts, SSL cert names, and enterprise domains are sensitive organizational details. A TOML file on iCloud with `[work]`/`[personal]` sections avoids leaking them in the repo.                                                                                                                                                                                                                                                                                    |
| **`keychain` template helper**                                | Wraps `security find-generic-password` in a reusable one-liner. Degrades to empty string on missing keys, unlike chezmoi's `keyring` which panics.                                                                                                                                                                                                                                                                                                                      |
| **Numbered run scripts**                                      | Deterministic ordering prevents race conditions (keychain import in script 02 must complete before templates that read secrets).                                                                                                                                                                                                                                                                                                                                        |
| **`run_once_` for setup, `run_onchange_` for content-driven** | Homebrew and npm globals only reinstall when their source files actually change, via embedded content hashes.                                                                                                                                                                                                                                                                                                                                                           |
| **Separate Brewfiles per machine type**                       | Personal and work machines have very different toolchains. Two focused lists are easier to maintain than one with conditionals.                                                                                                                                                                                                                                                                                                                                         |
| **`scriptEnv` for Homebrew flags**                            | `HOMEBREW_NO_AUTO_UPDATE=1` prevents Homebrew from auto-updating during scripted installs, keeping apply fast and deterministic.                                                                                                                                                                                                                                                                                                                                        |
| **LaunchAgent for proxy detection**                           | Replaces per-shell `nc` probe (~3s) with an event-driven daemon. Watches `/Library/Preferences/SystemConfiguration` + `/var/run/resolv.conf` (covers Wi-Fi and VPN). Shell startup reads a cached state file (~0ms), falling back to `proxy:probe` on first boot.                                                                                                                                                                                                       |
| **NVM lazy-loading**                                          | `nvm.sh` (~550ms) is not sourced at shell startup. Instead, lightweight stubs for `nvm`, `node`, `npm`, and `npx` replace themselves with the real implementations on first invocation. `nvmrc:load` (the `cd` hook) only calls the real loader when a `.nvmrc` or `.node-version` file is present.                                                                                                                                                                     |
| **compinit caching**                                          | `compinit -C` skips the full completion rebuild when `~/.zcompdump` is less than 24 hours old (checked via zsh glob qualifier `(N.mh-24)`). A full rebuild runs once per day to pick up newly installed completions.                                                                                                                                                                                                                                                    |
| **`run:daily` update gating**                                 | `bun:update`, `nvm:update`, `pyenv:update`, and `brew:check` are wrapped with `run:daily`, which gates execution behind a stamp file in `~/.cache/daily/`. The freshness check uses `(N.mh-24)` for zero forks. Prevents slow update commands from running on every shell open.                                                                                                                                                                                         |
| **`/etc/hosts` symlink**                                      | `dot_config/hosts.tmpl` is rendered by chezmoi into `~/.config/hosts` with machine-type-aware entries (work entries omitted on personal). Script 09 symlinks `/etc/hosts` → `~/.config/hosts` and re-runs whenever the template content changes.                                                                                                                                                                                                                        |
