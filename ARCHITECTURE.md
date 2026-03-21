# Architecture

> How this dotfiles system is organized, how data flows through it, and where to start when navigating the codebase.

## Bird's Eye View

This is a **macOS dotfiles system built on [chezmoi](https://chezmoi.io)**. chezmoi renders Go-templated configuration files, copies them to `$HOME`, and executes idempotent setup scripts — all while injecting secrets from the macOS Keychain at apply time.

```text
                     chezmoi init                     chezmoi apply
                          |                                 |
                          v                                 v
                   +----------------+                +-------------+
                   | .chezmoi.toml  |                | dot_* files |
                   | .tmpl          |                | & *.tmpl    |
                   | (prompts for   |                +------+------+
                   |  user values)  |                       |
                   +-------+--------+           +-----------+-----------+
                           |                    |                       |
                           v                    v                       v
                   +----------------+    +-------------+   +-------------------+
                   | chezmoi.toml   |    | Rendered to |   | .chezmoiscripts/  |
                   | + .chezmoidata |--->| $HOME/*     |   | run_* (Homebrew,  |
                   | (merged data)  |--+ +-------------+   | SSH, GPG, npm...) |
                   +----------------+  |                   +---------+---------+
                                       |                             |
                                       +-------- template data ------+
                                                       |
                                              +--------+--------+
                                              |                 |
                                       +------+------+   +--------------+
                                       |   macOS     |   | iCloud Drive |
                                       |   Keychain  |<->| (backup for  |
                                       | (secrets)   |   |  new machine)|
                                       +-------------+   +--------------+
```

## Source Directory Layout

```text
Dotfiles/
│
│  chezmoi configuration
├── .chezmoi.toml.tmpl              # Config template — prompts on first init
├── .chezmoidata.toml               # Shared non-secret defaults
├── .chezmoiignore                  # Files excluded from $HOME
├── .chezmoitemplates/
│   └── shell-helpers               # Reusable bash helpers for run scripts
│
│  Setup scripts (executed by chezmoi apply, numbered for ordering)
├── .chezmoiscripts/
│   ├── run_once_before_01-*        # Install Homebrew
│   ├── run_once_before_02-*        # Import keychain tokens from iCloud
│   ├── run_onchange_after_03-*     # Install Brew packages (re-runs on Brewfile change)
│   ├── run_once_after_04-*         # Restore SSH keys from iCloud
│   ├── run_once_after_05-*         # Restore GPG keys from iCloud
│   ├── run_once_after_06-*         # Restore SSL bundle (work only)
│   ├── run_onchange_after_07-*     # Install global npm packages (re-runs on list change)
│   ├── run_once_after_08-*         # Fix zsh completion permissions
│   ├── run_after_09-*              # Export keychain to iCloud (every apply)
│   ├── run_once_after_10-*         # Restore kubeconfig from iCloud
│   └── run_once_after_11-*         # Restore VPN config (work only)
│
│  Shell configuration (sourced on every terminal open)
├── dot_zshrc                       # Shell orchestrator — sources everything below
├── dot_exports.tmpl                # Env vars, history, locale, zsh options (templated)
├── dot_functions                   # ~65 shell functions
├── dot_aliases                     # ~70 command aliases + 3 git helper functions
├── dot_completions                 # Zsh completions, plugins, Kiro CLI compat
│
│  Tool configuration
├── dot_gitconfig.tmpl              # Git user, GPG signing, LFS, pull strategy
├── dot_gitignore_global            # Global gitignore (ref'd by dot_gitconfig.tmpl)
├── dot_npmrc.tmpl                  # npm registry tokens (from keychain)
├── dot_npm.globals                 # Global npm packages list (6 packages)
├── dot_wakatime.cfg.tmpl           # WakaTime API key (from keychain)
├── dot_config/zed/settings.json.tmpl   # Zed editor + MCP server keys (from keychain)
│
│  IDE settings
├── Library/Application Support/Code/User/
│   ├── settings.json.tmpl          # VS Code settings (home dir templated for Java/Gradle paths)
│   └── keybindings.json            # VS Code keybindings (Cmd+H → inline chat, etc.)
│
│  Package lists (consumed by run scripts, not copied to $HOME)
├── Brewfile.personal               # 136 brew + 80 cask + 34 mas + 278 vscode
└── Brewfile.swisscom               # 141 brew + 62 cask + 21 mas + 279 vscode
```

## Key Concepts

### File Naming Convention

chezmoi maps source filenames to target paths by replacing prefixes and stripping suffixes:

| Source | Target | Notes |
| ------ | ------ | ----- |
| `dot_zshrc` | `~/.zshrc` | `dot_` becomes `.` |
| `dot_exports.tmpl` | `~/.exports` | `.tmpl` stripped after rendering |
| `dot_config/zed/settings.json.tmpl` | `~/.config/zed/settings.json` | Nested directories preserved |
| `Library/Application Support/Code/User/...` | `~/Library/Application Support/Code/User/...` | Literal path, no prefix |

### Data Layers

chezmoi merges template data from multiple sources (later layers override earlier ones):

```text
Layer 1: Built-in variables          .chezmoi.os, .chezmoi.homeDir, .chezmoi.hostname, ...
    |
Layer 2: .chezmoidata.toml           editor, history_size, autostart_ssh_agent,
    |                                default_hostname, tree_ignore, dock_apps, cisco_vpn_bin
    |
Layer 3: chezmoi.toml [data]         email, name, gpg_key, machine_type, icloud_secrets,
                                     proxy_*, no_proxy_*, ssl_bundle_*, forgeops_path, ...
                                     (prompted interactively on first chezmoi init)
```

Both `dot_*` template files and run scripts in `.chezmoiscripts/` have access to all three layers. For example, run scripts use `{{ .icloud_secrets }}` and `{{ .machine_type }}` to locate iCloud paths and conditionally skip work-only steps.

### chezmoi Configuration

The `.chezmoi.toml.tmpl` also configures chezmoi behavior beyond template data:

| Section | Purpose |
| ------- | ------- |
| `[scriptEnv]` | Sets `HOMEBREW_NO_AUTO_UPDATE=1`, `HOMEBREW_NO_INSTALL_CLEANUP=1`, `NONINTERACTIVE=1` for all run scripts |
| `[[textconv]]` | Pipes `**/*.json` through `jq .` so `chezmoi diff` shows readable JSON diffs |

### Secrets Management

Secrets are read from the macOS Login Keychain at apply time and rendered into target files. iCloud Drive serves as a backup for bootstrapping new machines.

```text
                         Source of truth
                               |
  +--------------+      +------+------+      +------------------+
  | iCloud Drive |----->|    macOS    |----->| chezmoi templates |
  | (backup for  |  02  |   Login    |      | (read at apply   |
  |  bootstrap)  |      |  Keychain  |  09  |  time via output)|
  +--------------+      +------+------+      +------------------+
         ^                     |
         |                     v
         +--- secret:export    Rendered target files:
              (auto, every       ~/.npmrc           (npm auth tokens)
               apply)            ~/.wakatime.cfg    (WakaTime API key)
                                 ~/.exports         (NTLM credentials, work only)
                                 ~/.config/zed/settings.json
                                   (Context7 API key, GitHub PAT)
```

**How it works:**

1. **Keychain is the source of truth.** Templates read secrets via `output "sh" "-c" "security find-generic-password -s '<service>' -a '<account>' -w 2>/dev/null || true"`.
2. **iCloud Drive is the backup.** Script `02` imports tokens from iCloud into the keychain on a fresh machine. Script `09` exports keychain entries back to iCloud after every apply.
3. **Shell functions** (`secret:set`, `secret:get`, `secret:remove`, `secret:list`, `secret:export`) manage the keychain/iCloud lifecycle interactively.

> **Why `output` instead of chezmoi's built-in `keyring`?** The `keyring` function panics when a key is missing. The `output ... || true` pattern degrades gracefully to an empty string, allowing templates to render a warning comment instead of failing.

**All managed secrets:**

| Template | Keychain service | Keychain account | Condition |
| -------- | ---------------- | ---------------- | --------- |
| `dot_npmrc.tmpl` | `registry.npmjs.org` | `npm` | Always |
| `dot_npmrc.tmpl` | `bin.swisscom.com` | `swisscom-npm` | Work only |
| `dot_npmrc.tmpl` | `bin.swisscom.com` | `apps-team-npm` | Work only |
| `dot_exports.tmpl` | `ntlm` | `credentials` | Work only |
| `dot_wakatime.cfg.tmpl` | `wakatime` | `api-key` | Always |
| `dot_config/zed/settings.json.tmpl` | `context7` | `api-key` | Always |
| `dot_config/zed/settings.json.tmpl` | `github.com` | `zed-pat` | Always |

### Machine-Type Branching

The `machine_type` variable (`personal` or `work`), set once during `chezmoi init`, drives conditional behavior:

| Layer | `personal` | `work` |
| ----- | ---------- | ------ |
| **Brewfile** | `Brewfile.personal` | `Brewfile.swisscom` |
| **Proxy** | Disabled | Auto-detection via `proxy:probe` |
| **SSL** | No extra CA certs | Corporate CA bundle from iCloud |
| **VPN** | No config | Cisco AnyConnect config from iCloud |
| **Auth** | No NTLM | NTLM credentials for Alpaca proxy |
| **npm registries** | Public only | Public + corporate Artifactory |

### Shell Loading Order

When a new terminal opens, `~/.zshrc` loads files in this exact sequence:

```text
 1. Kiro CLI pre-hook       (if installed)
 2. ~/.exports              Env vars, proxy config, locale, history, zsh setopt, defaults
 3. ~/.functions            ~65 utility functions
 4. PATH setup              Tool paths, Homebrew, pyenv, NVM, RVM, system-specific PATH_ADD
 5. ~/.aliases              ~70 command aliases
 6. ~/.completions          Zsh completions, autosuggestions, autocomplete, syntax highlighting
 7. Runtime hooks           nvmrc auto-switch on cd, bun + nvm network checks, proxy probe, SSH agent
 8. SDKMAN                  Java SDK manager (must be at end of file)
 9. Kiro CLI post-hook      (if installed)
```

Notable detail: `~/.completions` includes a Kiro CLI compatibility workaround that disables zsh-autocomplete's async completion to prevent it from overwriting Kiro's inline suggestions.

### Run Script Execution

Scripts in `.chezmoiscripts/` are numbered for deterministic ordering. The filename prefix determines when and how often they run:

| Prefix | Behavior | Example |
| ------ | -------- | ------- |
| `run_once_before_` | Once, before files are copied | Install Homebrew, import keychain |
| `run_once_after_` | Once, after files are copied | Restore SSH/GPG keys |
| `run_onchange_after_` | Re-runs when script content changes | Brew packages (Brewfile hash embedded in script) |
| `run_after_` | Every `chezmoi apply` | Export keychain to iCloud |

All scripts include `{{ template "shell-helpers" . }}` which provides shared bash utilities:

| Helper | Purpose |
| ------ | ------- |
| `_log <level> <msg>` | Colored logging (error, success, warning, info) |
| `_cmd_exists <cmd>` | Check if a command exists in PATH |
| `_ensure_brew` | Load Homebrew shellenv (Apple Silicon + Intel) |
| `_ensure_icloud <path>` | Trigger iCloud Drive download for a path |
| `_require_icloud_dir <dir> <label>` | Validate + download an iCloud directory, return 1 if missing |
| `_ensure_nvm` | Load NVM from `$NVM_DIR` or Homebrew fallback |

## Entry Points

| What you want to do | Start here |
| ------------------- | ---------- |
| Understand shell startup | `dot_zshrc` |
| Add an environment variable | `dot_exports.tmpl` |
| Add a shell function | `dot_functions` |
| Add a command shortcut | `dot_aliases` |
| Change a shared default | `.chezmoidata.toml` |
| Add a user-prompted value | `.chezmoi.toml.tmpl` |
| Add a Homebrew package | `Brewfile.personal` or `Brewfile.swisscom` |
| Add a global npm package | `dot_npm.globals` |
| Add a managed secret | `secret:set <service> <account>`, then reference in a `.tmpl` file |
| Add a new setup step | Create a numbered `run_*` script in `.chezmoiscripts/` |
| Modify shared script helpers | `.chezmoitemplates/shell-helpers` |

## Design Decisions

| Decision | Rationale |
| -------- | --------- |
| **chezmoi file-copy over symlinks** | Templates can inject machine-specific values and secrets at apply time. Symlinks can't. |
| **macOS Keychain over `.env` files** | Secrets never exist in plaintext inside the repo. FileVault protects rendered files at rest on disk. |
| **iCloud Drive as backup, not source** | The keychain is authoritative. iCloud only serves to bootstrap a fresh machine. |
| **`output` over `keyring`** | chezmoi's built-in `keyring` panics on missing keys. `output ... \|\| true` degrades to empty strings. |
| **Numbered run scripts** | Deterministic ordering prevents race conditions (keychain import in script 02 must complete before templates that read secrets). |
| **`run_once_` for setup, `run_onchange_` for content-driven** | Homebrew and npm globals only reinstall when their source files actually change, via embedded content hashes. |
| **Separate Brewfiles per machine type** | Personal and work machines have very different toolchains. A single Brewfile with conditionals would be harder to maintain than two focused lists. |
| **`scriptEnv` for Homebrew flags** | `HOMEBREW_NO_AUTO_UPDATE=1` prevents Homebrew from auto-updating during scripted installs, keeping apply fast and deterministic. |
