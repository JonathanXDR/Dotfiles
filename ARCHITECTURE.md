# Architecture

> How this dotfiles system is organized, how data flows through it, and where to start when navigating the codebase.

## Bird's Eye View

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

## Source Directory Layout

```text
Dotfiles/
│
│  chezmoi configuration
├── .chezmoi.toml.tmpl              # Config template: reads iCloud config.toml, prompts as fallback
├── .chezmoidata.toml               # Shared non-secret defaults
├── .chezmoiignore                  # Files excluded from $HOME
├── .chezmoitemplates/
│   ├── keychain                    # Keychain lookup helper (includeTemplate "keychain" (list "svc" "acct"))
│   └── shell-helpers               # Reusable bash helpers for run scripts
│
│  Setup scripts (executed by chezmoi apply, numbered for ordering)
├── .chezmoiscripts/
│   ├── run_once_before_01-*        # Install Homebrew
│   ├── run_once_before_02-*        # Import keychain tokens from iCloud
│   ├── run_onchange_after_03-*     # Install Brew packages (re-runs on Brewfile change)
│   ├── run_onchange_after_04-*     # Fix iCloud symlink permissions (re-runs on config change)
│   ├── run_onchange_after_05-*     # Bootstrap proxy LaunchAgent (re-runs on plist change, work only)
│   ├── run_onchange_after_06-*     # Install global npm packages (re-runs on list change)
│   ├── run_once_after_07-*         # Fix zsh completion permissions
│   ├── run_after_08-*              # Export keychain to iCloud (every apply)
│   └── run_onchange_after_09-*     # Symlink /etc/hosts → ~/.config/hosts (re-runs on hosts change)
│
│  iCloud Drive symlinks (point $HOME dirs to iCloud)
├── symlink_dot_ssh.tmpl            # ~/.ssh → iCloud/.ssh
├── symlink_dot_ssl.tmpl            # ~/.ssl → iCloud/.ssl (ignored on personal via .chezmoiignore)
├── symlink_dot_vpn.tmpl            # ~/.vpn → iCloud/.vpn (ignored on personal via .chezmoiignore)
├── private_dot_gnupg/              # ~/.gnupg: individual files symlinked to iCloud
│   ├── symlink_common.conf.tmpl
│   ├── symlink_trustdb.gpg.tmpl
│   ├── symlink_sshcontrol.tmpl
│   ├── symlink_private-keys-v1.d.tmpl
│   ├── symlink_public-keys.d.tmpl
│   └── symlink_openpgp-revocs.d.tmpl
├── private_dot_kube/               # ~/.kube: kubeconfig symlinked to iCloud
│   └── symlink_config.tmpl
│
│  Proxy daemon (work only, ignored on personal via .chezmoiignore)
├── dot_local/bin/
│   └── executable_proxy-watchd.tmpl   # Event-driven proxy state script (called by LaunchAgent)
├── Library/LaunchAgents/
│   └── local.proxy-watchd.plist.tmpl  # Watches network changes, triggers proxy-watchd
│
│  Shell configuration (sourced on every terminal open)
├── dot_zshrc                       # Shell orchestrator: sources everything below
├── dot_exports.tmpl                # Env vars, history, locale, zsh options (templated)
├── dot_functions                   # Shell functions
├── dot_aliases                     # Command aliases
├── dot_completions                 # Zsh completions, plugins, Kiro CLI compat
│
│  Tool configuration
├── dot_gitconfig.tmpl              # Git user, GPG signing, LFS, pull strategy
├── dot_gitignore_global            # Global gitignore (ref'd by dot_gitconfig.tmpl)
├── dot_npmrc.tmpl                  # npm registry tokens (from keychain)
├── dot_npm.globals                 # Global npm packages list
├── dot_wakatime.cfg.tmpl           # WakaTime API key (from keychain)
├── dot_config/zed/settings.json.tmpl   # Zed editor + MCP server keys (from keychain)
├── dot_config/hosts.tmpl               # Machine-type-aware /etc/hosts (rendered, symlinked from /etc/hosts)
│
│  IDE settings
├── Library/Application Support/Code/User/
│   ├── settings.json.tmpl          # VS Code settings (home dir templated for Java/Gradle paths)
│   └── keybindings.json            # VS Code keybindings
│
│  Package lists (consumed by run scripts, not copied to $HOME)
├── Brewfile.personal               # Homebrew packages for personal machine
└── Brewfile.swisscom               # Homebrew packages for work machine
```

## Key Concepts

### Symlink Mode

chezmoi runs with `mode = "symlink"`, meaning managed files in `$HOME` are symlinks to the chezmoi source directory rather than independent copies. This means edits to `~/.zshrc` directly modify the source file, so there's no need to run `chezmoi edit`.

For sensitive directories (SSH, GPG, SSL, kube, VPN), chezmoi creates symlinks that point to **iCloud Drive** via `symlink_*` templates. This makes iCloud the single source of truth:

```text
$HOME                                    iCloud Drive (.dotfiles/)
─────────────────────────────────        ─────────────────────────────────────
~/.ssh/                             →    .ssh/
~/.gnupg/common.conf                →    .gnupg/common.conf
~/.gnupg/trustdb.gpg                →    .gnupg/trustdb.gpg
~/.gnupg/sshcontrol                 →    .gnupg/sshcontrol
~/.gnupg/private-keys-v1.d/        →    .gnupg/private-keys-v1.d/
~/.gnupg/public-keys.d/            →    .gnupg/public-keys.d/
~/.gnupg/openpgp-revocs.d/         →    .gnupg/openpgp-revocs.d/
~/.kube/config                      →    .kube/config
~/.ssl/                             →    .ssl/                      (work only)
~/.vpn/                             →    .vpn/                      (work only)
```

The `run_onchange_after_04-fix-icloud-permissions` script re-runs whenever the iCloud path or machine type changes, ensuring symlink targets have correct permissions (700 for dirs, 600 for private keys, 644 for public keys).

Work-only symlinks (`.ssl`, `.vpn`) are unconditionally defined but excluded on personal machines via a conditional block in `.chezmoiignore`.

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

Secrets are read from the macOS Login Keychain at apply time via the `keychain` template helper and rendered into target files.

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
│ macOS Login Keychain                                      │
│ (source of truth)                                         │
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

1. **Keychain is the source of truth for secrets.** Templates read secrets via `includeTemplate "keychain" (list "<service>" "<account>")`, which wraps `security find-generic-password` with graceful fallback to empty string.
2. **iCloud Drive is the backup.** Script `02` imports tokens from iCloud into the keychain on a fresh machine. Script `08` exports keychain entries back to iCloud after every apply.
3. **Shell functions** (`secret:set`, `secret:get`, `secret:remove`, `secret:list`, `secret:export`) manage the keychain/iCloud lifecycle interactively.

> **Why a custom `keychain` template instead of chezmoi's built-in `keyring`?** The `keyring` function panics when a key is missing. The `keychain` helper wraps `security find-generic-password ... || true` via `includeTemplate`, which degrades gracefully to an empty string. Templates can then render a warning comment instead of failing.

**All managed secrets:**

| Template                            | Keychain service     | Keychain account | Condition |
| ----------------------------------- | -------------------- | ---------------- | --------- |
| `dot_npmrc.tmpl`                    | `registry.npmjs.org` | `npm`            | Always    |
| `dot_npmrc.tmpl`                    | `bin.swisscom.com`   | `swisscom-npm`   | Work only |
| `dot_npmrc.tmpl`                    | `bin.swisscom.com`   | `apps-team-npm`  | Work only |
| `dot_exports.tmpl`                  | `ntlm`               | `credentials`    | Work only |
| `dot_wakatime.cfg.tmpl`             | `wakatime`           | `api-key`        | Always    |
| `dot_config/zed/settings.json.tmpl` | `context7`           | `api-key`        | Always    |
| `dot_config/zed/settings.json.tmpl` | `github.com`         | `zed-pat`        | Always    |

### Machine-Type Branching

The `machine_type` variable (`personal` or `work`), set once during `chezmoi init`, drives conditional behavior:

| Layer              | `personal`                              | `work`                                                |
| ------------------ | --------------------------------------- | ----------------------------------------------------- |
| **Brewfile**       | `Brewfile.personal`                     | `Brewfile.swisscom`                                   |
| **Proxy**          | Disabled (`always_proxy_probe = false`) | Event-driven via LaunchAgent + `proxy:probe` fallback |
| **SSL**            | No extra CA certs                       | Corporate CA bundle symlinked from iCloud             |
| **VPN**            | No config                               | Cisco AnyConnect config symlinked from iCloud         |
| **Auth**           | No NTLM                                 | NTLM credentials for Alpaca proxy                     |
| **npm registries** | Public only                             | Public + corporate Artifactory                        |
| **/etc/hosts**     | Standard entries only                   | Work-specific hostnames added via `dot_config/hosts.tmpl` |

### Shell Loading Order

When a new terminal opens, `~/.zshrc` loads files in this exact sequence:

```text
  Kiro CLI pre-hook ──────────── (if installed)
          │
          v
  ~/.exports ─────────────────── Env vars, proxy, locale, history, zsh setopt
          │
          v
  ~/.functions ───────────────── Utility functions (proxy, VPN, secrets, Node, Git, ...)
          │
          v
  PATH setup ─────────────────── Homebrew, pyenv, RVM, Bun, tool-specific paths; NVM lazy-loaded on first use
          │
          v
  ~/.aliases ─────────────────── Command aliases
          │
          v
  ~/.completions ─────────────── Zsh completions, autosuggestions, syntax highlighting
          │
          v
  Runtime hooks ──────────────── nvmrc auto-switch, proxy state load, SSH agent
          │
          v
  Daily checks ───────────────── bun, nvm, pyenv updates; brew deprecation/outdated (gated to once per 24h)
          │
          v
  SDKMAN ─────────────────────── Java SDK manager (must be last)
          │
          v
  Kiro CLI post-hook ─────────── (if installed)
```

### Run Script Execution

Scripts in `.chezmoiscripts/` are numbered for deterministic ordering. The filename prefix determines when and how often they run:

| Prefix                | Behavior                            | Example                                          |
| --------------------- | ----------------------------------- | ------------------------------------------------ |
| `run_once_before_`    | Once, before files are copied       | Install Homebrew, import keychain                |
| `run_onchange_after_` | Re-runs when script content changes | Brew packages (Brewfile hash embedded in script) |
| `run_once_after_`     | Once, after files are copied        | Fix zsh completion permissions                   |
| `run_after_`          | Every `chezmoi apply`               | Export keychain to iCloud                        |

All scripts include `{{ template "shell-helpers" . }}` which provides shared bash utilities:

| Helper                  | Purpose                                         |
| ----------------------- | ----------------------------------------------- |
| `_log <level> <msg>`    | Colored logging (error, success, warning, info) |
| `_cmd_exists <cmd>`     | Check if a command exists in PATH               |
| `_ensure_brew`          | Load Homebrew shellenv (Apple Silicon + Intel)  |
| `_ensure_icloud <path>` | Trigger iCloud Drive download for a path        |
| `_ensure_nvm`           | Load NVM from `$NVM_DIR` or Homebrew fallback   |

## Entry Points

| What you want to do                  | Start here                                                                                |
| ------------------------------------ | ----------------------------------------------------------------------------------------- |
| Understand shell startup             | `dot_zshrc`                                                                               |
| Add an environment variable          | `dot_exports.tmpl`                                                                        |
| Add a shell function                 | `dot_functions`                                                                           |
| Add a command shortcut               | `dot_aliases`                                                                             |
| Change a shared default              | `.chezmoidata.toml`                                                                       |
| Add a user-prompted value            | `.chezmoi.toml.tmpl`                                                                      |
| Add machine-type config (non-secret) | `config.toml` on iCloud Drive                                                             |
| Add a Homebrew package               | `Brewfile.personal` or `Brewfile.swisscom`                                                |
| Add a global npm package             | `dot_npm.globals`                                                                         |
| Add a managed secret                 | `secret:set <service> <account>`, then use `includeTemplate "keychain"` in a `.tmpl` file |
| Manage `/etc/hosts` entries          | `dot_config/hosts.tmpl`                                                                   |
| Symlink a new dir to iCloud          | Create a `symlink_dot_<name>.tmpl` with the iCloud path                                   |
| Add a new setup step                 | Create a numbered `run_*` script in `.chezmoiscripts/`                                    |
| Modify shared script helpers         | `.chezmoitemplates/shell-helpers`                                                         |
| Debug proxy daemon                   | `proxyd:status`, `proxyd:log`, or `proxyd:log 1h`                                         |
| Reload proxy daemon                  | `proxyd:reload`                                                                           |

## Design Decisions

| Decision                                                      | Rationale                                                                                                                                                                                                                                                         |
| ------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Symlink mode**                                              | Edits to `$HOME` files modify the source directly, so no `chezmoi edit` is needed. Templates still render before symlinking.                                                                                                                                      |
| **iCloud symlinks for SSH/GPG/SSL/kube/VPN**                  | One copy of keys across all machines. No copy scripts needed: chezmoi creates the symlinks, a `run_onchange_after` script fixes permissions.                                                                                                                      |
| **macOS Keychain over `.env` files**                          | Secrets never exist in plaintext inside the repo. FileVault protects rendered files at rest.                                                                                                                                                                      |
| **iCloud `config.toml` over init prompts**                    | Proxy hosts, SSL cert names, and enterprise domains are sensitive organizational details. A TOML file on iCloud with `[work]`/`[personal]` sections avoids leaking them in the repo.                                                                              |
| **`keychain` template helper**                                | Wraps `security find-generic-password` in a reusable one-liner. Degrades to empty string on missing keys, unlike chezmoi's `keyring` which panics.                                                                                                                |
| **Numbered run scripts**                                      | Deterministic ordering prevents race conditions (keychain import in script 02 must complete before templates that read secrets).                                                                                                                                  |
| **`run_once_` for setup, `run_onchange_` for content-driven** | Homebrew and npm globals only reinstall when their source files actually change, via embedded content hashes.                                                                                                                                                     |
| **Separate Brewfiles per machine type**                       | Personal and work machines have very different toolchains. Two focused lists are easier to maintain than one with conditionals.                                                                                                                                   |
| **`scriptEnv` for Homebrew flags**                            | `HOMEBREW_NO_AUTO_UPDATE=1` prevents Homebrew from auto-updating during scripted installs, keeping apply fast and deterministic.                                                                                                                                  |
| **LaunchAgent for proxy detection**                           | Replaces per-shell `nc` probe (~3s) with an event-driven daemon. Watches `/Library/Preferences/SystemConfiguration` + `/var/run/resolv.conf` (covers Wi-Fi and VPN). Shell startup reads a cached state file (~0ms), falling back to `proxy:probe` on first boot. |
| **NVM lazy-loading**                                          | `nvm.sh` (~550ms) is not sourced at shell startup. Instead, lightweight stubs for `nvm`, `node`, `npm`, and `npx` replace themselves with the real implementations on first invocation. `nvmrc:load` (the `cd` hook) only calls the real loader when a `.nvmrc` or `.node-version` file is present. |
| **compinit caching**                                          | `compinit -C` skips the full completion rebuild when `~/.zcompdump` is less than 24 hours old (checked via zsh glob qualifier `(N.mh-24)`). A full rebuild runs once per day to pick up newly installed completions. |
| **`run:daily` update gating**                                 | `bun:update`, `nvm:update`, `pyenv:update`, and `brew:check` are wrapped with `run:daily`, which gates execution behind a stamp file in `~/.cache/daily/`. The freshness check uses `(N.mh-24)` — zero forks. Prevents slow update commands from running on every shell open. |
| **`/etc/hosts` symlink**                                      | `dot_config/hosts.tmpl` is rendered by chezmoi into `~/.config/hosts` with machine-type-aware entries (work entries omitted on personal). Script 09 symlinks `/etc/hosts` → `~/.config/hosts` and re-runs whenever the template content changes. |
