# CLAUDE.md

This file provides comprehensive guidance to Claude Code (claude.ai/code) and developers working with this repository.

## Table of Contents

1. [Repository Overview](#repository-overview)
2. [How It Works: chezmoi Init and Apply Flow](#how-it-works-chezmoi-init-and-apply-flow)
3. [Directory Structure](#directory-structure)
4. [Template System](#template-system)
5. [Template Variables Reference](#template-variables-reference)
6. [Shell Functions Reference](#shell-functions-reference)
7. [Aliases Reference](#aliases-reference)
8. [Run Scripts Reference](#run-scripts-reference)
9. [Package Management](#package-management)
10. [Development Workflows](#development-workflows)
11. [Troubleshooting](#troubleshooting)

---

## Repository Overview

This is a macOS dotfiles management system built on [chezmoi](https://chezmoi.io), using a file-copy model to manage shell configuration, development tool setup, and system preferences. chezmoi replaces the previous symlink-based system entirely.

**Key Features:**

- **File-copy model**: chezmoi copies files to `$HOME` rather than symlinking them
- **Template-driven**: sensitive and machine-specific values injected via Go templates at apply time
- **Run scripts**: idempotent scripts handle package installation, SSH/GPG key setup, and system configuration
- **Secrets via macOS Keychain**: `.npmrc` tokens and other credentials fetched from the macOS login keychain via chezmoi's built-in `keyring` function at apply time
- **Layered configuration**: ordered loading of exports → functions → paths → aliases → completions
- **Automatic context switching**: Node versions, proxy detection, SSH agent management
- **Enterprise-ready**: VPN/proxy auto-detection, multi-environment support

**Repository Location:** `$HOME/Developer/Git/GitHub/Dotfiles`

**Primary Commands:**

```zsh
chezmoi init --source ~/Developer/Git/GitHub/Dotfiles --apply   # First-time setup
chezmoi apply                                                    # Apply changes
chezmoi diff                                                     # Preview changes
chezmoi edit ~/.zshrc                                            # Edit a managed file
```

---

## How It Works: chezmoi Init and Apply Flow

### Phase 1: Initial Setup (One-Time)

```zsh
git clone <repo-url> ~/Developer/Git/GitHub/Dotfiles
chezmoi init --source ~/Developer/Git/GitHub/Dotfiles --apply
```

**What `chezmoi init` does:**

1. Reads `.chezmoi.toml.tmpl` and prompts for:
   - `email` - git/GPG email address
   - `name` - full name for git config
   - `gpg_key` - GPG key ID for commit signing
   - `machine_type` - `personal` or `work`
2. Writes `~/.config/chezmoi/chezmoi.toml` with your answers
3. Runs `chezmoi apply` (when `--apply` is passed)

**What `chezmoi apply` does:**

1. Reads all `dot_*` files and `.tmpl` templates from the source directory
2. Renders templates using data from `chezmoi.toml` and chezmoi built-ins
3. Copies rendered files to `$HOME` (replacing the `dot_` prefix with `.`)
4. Runs `run_once_*` and `run_onchange_*` scripts in lexicographic order
5. Fetches `.npmrc` tokens from the macOS login keychain via chezmoi's built-in `keyring` function

**File name mapping examples:**

| Source file                              | Target file                                              |
| ---------------------------------------- | -------------------------------------------------------- |
| `dot_zshrc`                              | `~/.zshrc`                                               |
| `dot_zshenv.tmpl`                        | `~/.zshenv`                                              |
| `dot_gitconfig.tmpl`                     | `~/.gitconfig`                                           |
| `dot_gitignore_global`                   | `~/.gitignore_global`                                    |
| `Library/Application Support/Code/User/settings.json` | `~/Library/Application Support/Code/User/settings.json` |

### Phase 2: Every Shell Session

When you open a new terminal, here is the exact sequence:

#### Step 1: Kiro CLI Pre-Hook (.zshrc)

```zsh
[[ -f "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.pre.zsh" ]] && source ...
```

#### Step 2: Define Load Order (.zshrc)

```zsh
files=(.exports .functions .paths .aliases .completions)
```

**Critical ordering**: exports → functions → paths → aliases → completions

#### Step 3: Load Configuration Files (.zshrc)

For each file in the order above, sources from `$HOME`. If a file is missing, an error message is printed:

```
[dotfiles] Missing: ~/.exports — Run: chezmoi apply
```

There is no self-healing fallback. The fix is always: `chezmoi apply`.

#### Step 4: Load `.exports` (Environment Variables)

Sets critical environment variables from `.shell/.exports` (managed by chezmoi):

- **Proxy configuration**: `PROXY_PROTOCOL`, `PROXY_HOST`, `PROXY_PORT`, `NO_PROXY`
- **Authentication**: `NTLM_CREDENTIALS`
- **Node.js**: `NODE_TLS_REJECT_UNAUTHORIZED`, `NODE_REPL_HISTORY`, `NODE_REPL_HISTORY_SIZE`
- **Python**: `PYTHONIOENCODING`
- **Locale**: `LANG`, `LC_ALL` (UTF-8)
- **History**: `HISTSIZE`, `HISTFILESIZE`, `HISTCONTROL`
- **GPG**: `GPG_TTY`
- **Paths**: `PATH_ADD` for system-specific additions

#### Step 5: Load `.functions`, `.paths`, `.aliases`, `.completions`

Same content as before, loaded from `$HOME` (files placed there by `chezmoi apply`).

#### Step 6: Runtime Initialization (.zshrc)

**Directory change hook:**

```zsh
add-zsh-hook chpwd nvmrc:load  # Auto-switch Node on cd
```

**Conditional updates:**

```zsh
network:check bun:update https://registry.npmjs.org
network:check nvm:update https://raw.githubusercontent.com
```

**Initial Node version:**

```zsh
nvmrc:load
```

**Proxy auto-detection:**

```zsh
[[ "${ALWAYS_PROXY_PROBE}" == "true" ]] && proxy:probe
```

**SSH agent:**

```zsh
[[ "${AUTOSTART_SSH_AGENT}" == "true" ]] && ssh:agent
```

**SDKMAN:**

```zsh
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
```

**Kiro CLI post-hook:**

```zsh
[[ -f "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.post.zsh" ]] && source ...
```

**Note:** `env:replace` is no longer called at shell startup. chezmoi handles `.npmrc` token substitution at apply time using the built-in `keyring` function (reads from the macOS login keychain).

---

## Directory Structure

```
Dotfiles/
├── dot_zshrc                          # ~/.zshrc (orchestrator)
├── dot_zshenv.tmpl                    # ~/.zshenv (env vars, templated)
├── dot_zprofile                       # ~/.zprofile (login shell)
├── dot_gitconfig.tmpl                 # ~/.gitconfig (templated: name/email/gpg)
├── dot_gitignore_global               # ~/.gitignore_global
├── dot_exports                        # ~/.exports (environment variables)
├── dot_functions                      # ~/.functions (shell utility functions)
├── dot_paths                          # ~/.paths (PATH configuration)
├── dot_aliases                        # ~/.aliases (command shortcuts)
├── dot_completions                    # ~/.completions (auto-completion rules)
├── dot_npmrc.tmpl                     # ~/.npmrc (templated via keyring)
├── dot_npm.globals                    # ~/.npm.globals (global npm packages list)
│
├── Library/
│   └── Application Support/
│       └── Code/
│           └── User/
│               ├── settings.json      # VS Code settings
│               └── keybindings.json   # VS Code keybindings
│
├── .chezmoi.toml.tmpl                 # chezmoi config template (prompts on init)
├── .chezmoiignore                     # Files chezmoi ignores
├── .chezmoitemplates/                 # (empty — apw template removed)
│
├── run_once_before_install-homebrew.sh       # Install Homebrew if missing
├── run_once_before_import-keychain.sh.tmpl   # Import tokens from iCloud into login keychain
├── run_once_after_install-brew-packages.sh.tmpl  # Install Homebrew packages
├── run_once_after_install-ssh-keys.sh.tmpl   # Restore SSH keys from iCloud
├── run_once_after_install-gpg-keys.sh.tmpl   # Restore GPG keys from iCloud
├── run_once_after_install-ssl-bundle.sh.tmpl # Restore SSL bundle from iCloud (work only)
├── run_onchange_install-npm-globals.sh.tmpl  # Install global npm packages
├── run_once_after_fix-permissions.sh         # Fix zsh completion permissions
│
├── Brewfile.personal                  # Personal Homebrew packages
├── Brewfile.swisscom                  # Enterprise/work Homebrew packages
├── .env.example                       # Template for private configuration
├── CLAUDE.md                          # This file
└── README.md                          # Repository README
```

### What is Gone (compared to old system)

The following directories no longer exist:

- `.home/` - replaced by root-level `dot_*` files
- `.shell/` - replaced by root-level `dot_*` files
- `.vscode/` - replaced by `Library/Application Support/Code/User/`

The following functions no longer exist:

- `dotfiles:symlink`, `dotfiles:remove`, `dotfiles:iterate`, `dotfiles:process`
- `dotfiles:link`, `dotfiles:unlink`, `dotfiles:cleanup`
- `env:replace` (chezmoi handles `.npmrc` substitution at apply time)

### `.chezmoiignore`

The following files are present in the repo but ignored by chezmoi (not copied to `$HOME`):

```
README.md
CLAUDE.md
SECRETS.md
LICENSE
Brewfile.personal
Brewfile.swisscom
.env.example
.gitignore
.git
.claude
.home
.shell
.vscode
```

---

## Template System

### Go Template Syntax

chezmoi templates use Go's `text/template` syntax. Template files have a `.tmpl` extension in the source directory (the extension is stripped from the target filename).

**Basic variable substitution:**

```
{{ .name }}
{{ .email }}
{{ .chezmoi.homeDir }}
```

**Conditional blocks:**

```
{{ if eq .machine_type "work" }}
[work-specific config]
{{ end }}
```

**Using the built-in `keyring` function:**

```
{{ keyring "service-name" "account-name" }}
```

### `.chezmoi.toml.tmpl`

This file is evaluated once during `chezmoi init` to produce `~/.config/chezmoi/chezmoi.toml`. It interactively prompts for values:

```toml
{{- $email := promptStringOnce . "email" "Email address" -}}
{{- $name := promptStringOnce . "name" "Full name" -}}
{{- $gpg_key := promptStringOnce . "gpg_key" "GPG key ID" -}}
{{- $machine_type := promptStringOnce . "machine_type" "Machine type (personal/work)" -}}

[data]
  email = {{ $email | quote }}
  name = {{ $name | quote }}
  gpg_key = {{ $gpg_key | quote }}
  machine_type = {{ $machine_type | quote }}
```

### Built-in `keyring` Function

chezmoi's built-in `keyring` template function reads secrets from the macOS login keychain at apply time. No daemon, no external binary — it calls `/usr/bin/security` directly.

```
{{ keyring "service-name" "account-name" }}
```

Secrets are stored in the macOS login keychain (via `security add-generic-password`) and backed up to iCloud Drive for new machine setup.

---

## Template Variables Reference

### User-Defined Variables (from `chezmoi.toml`)

| Variable       | Set During     | Example Value          | Purpose                              |
| -------------- | -------------- | ---------------------- | ------------------------------------ |
| `.email`       | `chezmoi init` | `user@example.com`     | Git commit email, GPG identity       |
| `.name`        | `chezmoi init` | `Jane Smith`           | Git commit author name               |
| `.gpg_key`     | `chezmoi init` | `ABC123DEF456`         | GPG key ID for commit signing        |
| `.machine_type`| `chezmoi init` | `personal` or `work`   | Drives conditional config blocks     |

### chezmoi Built-in Variables

| Variable               | Example Value                          | Purpose                                |
| ---------------------- | -------------------------------------- | -------------------------------------- |
| `.chezmoi.homeDir`     | `/Users/jane`                          | Absolute path to `$HOME`               |
| `.chezmoi.sourceDir`   | `/Users/jane/Developer/Git/GitHub/Dotfiles` | Absolute path to this repo        |
| `.chezmoi.os`          | `darwin`                               | Operating system                       |
| `.chezmoi.arch`        | `arm64`                                | CPU architecture                       |
| `.chezmoi.hostname`    | `MacBook-Pro`                          | Machine hostname                       |
| `.chezmoi.username`    | `jane`                                 | Current username                       |

### Usage in Templates

**`dot_gitconfig.tmpl`:**

```toml
[user]
  name = {{ .name }}
  email = {{ .email }}
  signingkey = {{ .gpg_key }}
```

**`dot_zshenv.tmpl`:**

```zsh
export DOTFILES_REPO_PATH="{{ .chezmoi.sourceDir }}"
export VSCODE_CONFIG_PATH="{{ .chezmoi.homeDir }}/Library/Application Support/Code/User"
```

**`dot_npmrc.tmpl` (using keyring):**

```
//registry.npmjs.org/:_authToken={{ keyring "registry.npmjs.org" "npm" }}
```

---

## Shell Functions Reference

All functions live in `~/.functions` (source: `dot_functions`).

### Logging & Utilities

#### `log <level> <message>`

Colored logging with levels.

**Levels:** `error`/`red`, `success`/`green`, `warning`/`yellow`, `info`/`blue`

```zsh
log error "Configuration file not found"
log success "Build completed"
```

#### `cmd:exists <command>`

Check if command exists in PATH. Returns 0 if exists, 1 if not.

```zsh
cmd:exists docker && echo "Docker installed"
```

#### `path:add <directory>`

Prepend directory to PATH if it exists and is not already present.

```zsh
path:add "/usr/local/custom/bin"
```

#### `path:append <directory>`

Append directory to PATH if it exists and is not already present.

```zsh
path:append "$HOME/scripts"
```

#### `mkd <directory>`

Create directory and cd into it.

```zsh
mkd ~/projects/new-app
```

#### `cdf`

Change to the current Finder window location (macOS only).

### File Operations

#### `targz <file-or-directory>`

Create optimized `.tar.gz` archive (uses zopfli for <50MB, pigz otherwise).

```zsh
targz my-project/
# Creates: my-project.tar.gz
```

#### `fs [path]`

Show file or directory size.

```zsh
fs .
fs ~/Downloads
```

#### `dataurl <file>`

Create base64 data URL from file.

```zsh
dataurl image.png
# Returns: data:image/png;base64,iVBOR...
```

#### `server [port]`

Start HTTP server in current directory. Default port: 8000.

```zsh
server 3000
```

#### `gz <file>`

Compare original vs gzipped file size.

#### `trec [directory]`

Tree view with colors, ignoring git/node_modules, piped to less.

#### `tre [directory]`

Tree view without paging.

#### `o [location]`

Open file/directory (current directory if no argument).

### Network & DNS

#### `digga <domain>`

Run dig with useful output format.

#### `getcertnames <domain>`

Show SSL certificate CNs and SANs.

#### `dns:change <network-service> <dns-ips>`

Change DNS servers for network service.

```zsh
dns:change "Wi-Fi" "8.8.8.8,8.8.4.4"
```

#### `proxy:set [protocol] [host] [port] [no_proxy]`

Set proxy environment variables. Uses env vars if args omitted.

**Sets:** `http_proxy`, `https_proxy`, `ftp_proxy`, `all_proxy`, uppercase variants, `PIP_PROXY`, `no_proxy`, `MAVEN_OPTS`

```zsh
proxy:set http proxy.company.com 8080
proxy:set  # Uses $PROXY_PROTOCOL/$PROXY_HOST/$PROXY_PORT/$NO_PROXY
```

#### `proxy:unset`

Remove all proxy environment variables.

#### `proxy:probe [dns]`

Auto-detect VPN by checking if `$PROXY_HOST:$PROXY_PORT` is reachable.

- If reachable: sets proxy (VPN active)
- If not reachable: unsets proxy (normal network)
- With `dns` argument: also changes DNS servers

#### `network:check <command> <url>`

Run command only if URL is reachable.

```zsh
network:check bun:update https://registry.npmjs.org
```

### SSH

#### `ssh:reagent`

Find and reconnect to existing SSH agent.

#### `ssh:agent`

Start SSH agent or reconnect to existing one.

### macOS System

#### `system:setup`

Run initial system setup (reset hostname, enable Touch ID for sudo).

#### `system:shutdown`, `system:restart`, `system:sleep`

Power management shortcuts.

#### `sudo:touch-id`

Enable Touch ID for sudo authentication.

#### `hostname:get`

Get current hostname.

#### `hostname:set <name>`

Set system hostname (ComputerName, HostName, LocalHostName).

#### `hostname:reset`

Reset hostname to default (`void(0)`).

#### `dock:reset`

Reset Dock to defaults and add preferred apps.

**Apps added:** Zen, Notion, Visual Studio Code, Microsoft Teams, Discord, GitKraken

### Docker

#### `docker:cleanup [keywords]`

Remove all containers and images, or keep those matching keywords.

```zsh
docker:cleanup                    # Remove everything
docker:cleanup postgres redis     # Keep postgres and redis
```

### JavaScript Ecosystem

#### `nvm:update`

Install latest Node.js version via NVM and verify it works. If newest version fails, reverts to LTS. Installs global npm packages from `.npm.globals`.

#### `node:verify`

Verify Node installation and install global packages if needed. Falls back to LTS if current version is broken. Checks globals lock file and installs if missing or `.npm.globals` changed.

#### `bun:update`

Update Bun to latest version (silent).

#### `nvmrc:load`

Auto-switch Node version based on `.nvmrc` file. Finds `.nvmrc` in current or parent directories, installs version if not present, reverts to default when leaving project directory. Runs automatically on every `cd` via zsh hook.

#### `globals:install`

Install global npm packages from `.npm.globals` file. Reads `.npm.globals`, ignores comments and empty lines, installs all packages globally with `--force`. Creates lock file: `~/.npm/_locks/.npm.globals.<node-version>.lock`.

#### `ncu:update`

Update all package.json dependencies to latest versions. Runs `ncu -u`, removes `node_modules` and all lock files, runs `ni` (auto-detects package manager and installs).

### Environment Management

#### `env:load [file]`

Load `.env` file variables into shell environment. Default file: `$HOME/.env`. Skips comments and empty lines, exports all `KEY=VALUE` pairs.

```zsh
env:load                    # Load ~/.env
env:load .env.production    # Load specific file
```

**Note:** `env:replace` has been removed. chezmoi handles `.npmrc` token substitution at `chezmoi apply` time using the built-in `keyring` function.

### Secrets Management

Shell functions that keep the macOS login keychain and iCloud Drive backup in sync. The keychain is the source of truth.

#### `secret:set <service> <account>`

Add or update a secret. Prompts for the password interactively (never in shell history). Writes to the keychain, then auto-exports to iCloud Drive.

```zsh
secret:set registry.npmjs.org npm
```

#### `secret:get <service> <account>`

Read a secret from the login keychain.

```zsh
secret:get registry.npmjs.org npm
```

#### `secret:remove <service> <account>`

Remove a secret from the keychain and iCloud Drive backup.

```zsh
secret:remove api.example.com key
```

#### `secret:list`

List all managed secrets (service/account pairs, no passwords shown).

#### `secret:export`

Re-export all managed secrets from the keychain to the iCloud Drive tokens file. Called automatically by `secret:set` and `secret:remove`. Use manually if you edited the keychain directly.

### Git

#### `diff <file1> <file2>`

Git-powered colored diff (overrides system `diff`).

#### `git:diff <source-branch> <target-branch> [exclude-pattern]`

Show diff between branches and copy to clipboard. Lists changed files, shows full content of each file in target branch, copies output to clipboard (macOS). Optionally excludes files matching pattern.

```zsh
git:diff main feature/new-ui
git:diff main develop "*.lock"
```

#### `git:history [--editor <editor>] [-- <editor-args>]`

**WARNING: Destructive operation.** Interactively rewrite entire Git history. Requires typing "Yes" to confirm. Opens git log in editor, allows editing commit messages/authors/emails/dates, rewrites history using `git filter-branch`. Requires force push afterward.

```zsh
git:history                  # Edit with VS Code
git:history --editor nvim    # Edit with nvim
```

---

## Aliases Reference

All aliases live in `~/.aliases` (source: `dot_aliases`).

### Filesystem Navigation

| Alias   | Command                              | Description                            |
| ------- | ------------------------------------ | -------------------------------------- |
| `dirs`  | `dirs -v`                            | Show directory stack with line numbers |
| `..`    | `cd ..`                              | Go up one directory                    |
| `...`   | `cd ../..`                           | Go up two directories                  |
| `....`  | `cd ../../..`                        | Go up three directories                |
| `.....` | `cd ../../../..`                     | Go up four directories                 |
| `~`     | `cd ~`                               | Go to home directory                   |
| `-`     | `cd -`                               | Go to previous directory               |
| `ls`    | `lsd` (if available) or `ls --color` | Colorized ls                           |
| `l`     | `ls -lF`                             | Long format with file type indicators  |
| `la`    | `ls -lAF`                            | Long format including hidden files     |
| `lsd`   | `ls -lF \| grep '^d'`                | List only directories                  |
| `path`  | `echo -e ${PATH//:/\\n}`             | Print PATH entries on separate lines   |

### System Tools

| Alias    | Command                             | Description                         |
| -------- | ----------------------------------- | ----------------------------------- |
| `python` | `python3`                           | Use Python 3 by default             |
| `top`    | `btop` (if available)               | Better top utility                  |
| `cat`    | `bat --paging=never` (if available) | Better cat with syntax highlighting |
| `rm`     | `trash-put` (if available)          | Safe delete (moves to trash)        |
| `ssh`    | `ssh -o AddKeysToAgent=yes`         | Auto-add SSH keys to agent          |
| `reload` | `exec ${SHELL} -l`                  | Reload shell                        |
| `afk`    | `CGSession -suspend`                | Lock screen                         |

### macOS Tweaks

| Alias         | Command                                                 | Description                       |
| ------------- | ------------------------------------------------------- | --------------------------------- |
| `show`        | `defaults write ... && killall Finder`                  | Show hidden files in Finder       |
| `hide`        | `defaults write ... && killall Finder`                  | Hide hidden files in Finder       |
| `hidedesktop` | `defaults write ... && killall Finder`                  | Hide desktop icons                |
| `showdesktop` | `defaults write ... && killall Finder`                  | Show desktop icons                |
| `flush`       | `dscacheutil -flushcache && killall -HUP mDNSResponder` | Flush DNS cache                   |
| `lscleanup`   | `lsregister -kill ...`                                  | Clean "Open With" menu duplicates |
| `spotoff`     | `sudo mdutil -a -i off`                                 | Disable Spotlight indexing        |
| `spoton`      | `sudo mdutil -a -i on`                                  | Enable Spotlight indexing         |
| `emptytrash`  | `sudo rm -rfv ~/.Trash ...`                             | Empty all trash and clear logs    |

### Networking

| Alias      | Command                                              | Description                    |
| ---------- | ---------------------------------------------------- | ------------------------------ |
| `ip`       | `dig +short myip.opendns.com @resolver1.opendns.com` | Get public IP address          |
| `localip`  | `ipconfig getifaddr en0`                             | Get local IP address           |
| `ips`      | `ifconfig -a \| grep ...`                            | List all IP addresses          |
| `ifactive` | `ifconfig \| pcregrep ...`                           | Show active network interfaces |
| `airport`  | `/System/Library/.../airport`                        | macOS Airport CLI utility      |

### Kubernetes

| Alias | Command                  | Description                 |
| ----- | ------------------------ | --------------------------- |
| `k`   | `kubectl`                | Kubernetes CLI shortcut     |
| `kn`  | `kubens` (if available)  | Switch Kubernetes namespace |
| `kx`  | `kubectx` (if available) | Switch Kubernetes context   |

### Utilities

| Alias               | Command                                         | Description                               |
| ------------------- | ----------------------------------------------- | ----------------------------------------- |
| `grep`              | `grep --color=auto`                             | Colorized grep                            |
| `fgrep`             | `fgrep --color=auto`                            | Colorized fgrep                           |
| `egrep`             | `egrep --color=auto`                            | Colorized egrep                           |
| `sudo`              | `sudo `                                         | Enable aliases with sudo (trailing space) |
| `week`              | `date +%V`                                      | Get current week number                   |
| `update`            | `sudo softwareupdate ... brew update ...`       | Update everything                         |
| `hd`                | `hexdump -C`                                    | Canonical hex dump                        |
| `md5sum`            | `md5` (macOS)                                   | MD5 checksum                              |
| `sha1sum`           | `shasum` (macOS)                                | SHA1 checksum                             |
| `c`                 | `tr -d '\n' \| pbcopy`                          | Trim newlines and copy to clipboard       |
| `cleanup`           | `find . -type f -name '*.DS_Store' -ls -delete` | Delete .DS_Store files recursively        |
| `urlencode`         | `python -c "import urllib ..."`                 | URL-encode strings                        |
| `plistbuddy`        | `/usr/libexec/PlistBuddy`                       | Property list editor                      |
| `map`               | `xargs -n1`                                     | Map function for pipes                    |
| `GET`, `POST`, etc. | `lwp-request -m 'METHOD'`                       | HTTP request shortcuts                    |
| `stfu`              | `osascript -e 'set volume ...'`                 | Mute volume                               |
| `pumpitup`          | `osascript -e 'set volume ...'`                 | Max volume                                |

### Editors

| Alias             | Command                                                  | Description                              |
| ----------------- | -------------------------------------------------------- | ---------------------------------------- |
| `vi`/`vim`/`nvim` | `nvim.appimage` or `nvim`                                | Prefer Neovim if available               |
| `es`              | `chezmoi edit ~/.zshrc`                                  | Edit shell config via chezmoi            |
| `ev`              | `chezmoi edit ~/.exports`                                | Edit environment variables via chezmoi   |
| `e`               | `$EDITOR .`                                              | Open editor in current directory         |

**Note:** `es` and `ev` now invoke `chezmoi edit` so that changes are tracked in the source directory and can be applied with `chezmoi apply`.

### Git

| Alias   | Command                                    | Description                |
| ------- | ------------------------------------------ | -------------------------- |
| `g`     | `git`                                      | Git shortcut               |
| `gs`    | `git status`                               | Show status                |
| `gca`   | `git commit -a -m`                         | Commit all with message    |
| `gau`   | `git remote add upstream`                  | Add upstream remote        |
| `gaa`   | `git add --all`                            | Stage all changes          |
| `gpl`   | `git pull`                                 | Pull from remote           |
| `gpu`   | `git push`                                 | Push to remote             |
| `gps`   | `git push && say You are awesome!`         | Push and celebrate (macOS) |
| `yolo`  | `git push --force`                         | Force push                 |
| `yolos` | `git push --force && say That was sneaky!` | Force push and celebrate   |
| `gcl`   | `git clone`                                | Clone repository           |
| `glg`   | `git log`                                  | Show log                   |
| `gst`   | `git shortlog -sn`                         | Show contributors          |
| `gch`   | `git checkout`                             | Checkout branch            |
| `gba`   | `git branch -av`                           | Show all branches          |
| `gsl`   | `git stash list`                           | List stashes               |
| `gsc`   | `git stash clear`                          | Clear all stashes          |

#### Git Function Aliases

**`gdb <branch>`** - Delete local and remote branch

```zsh
gdb feature/old-feature
```

**`gas <stash-index>`** - Apply specific stash

```zsh
gas 0  # Apply stash@{0}
```

**`grb <commit-count>`** - Interactive rebase last N commits

```zsh
grb 3  # Rebase last 3 commits
```

### Suffix Aliases (Zsh Only)

Auto-open files with `$EDITOR` based on extension:

| Extension       | Opens with |
| --------------- | ---------- |
| `.go`           | `$EDITOR`  |
| `.md`           | `$EDITOR`  |
| `.yaml`, `.yml` | `$EDITOR`  |
| `.js`, `.ts`    | `$EDITOR`  |
| `.json`         | `$EDITOR`  |

```zsh
README.md  # Just type filename - opens in $EDITOR
```

---

## Run Scripts Reference

Run scripts live at the root of the repo and are executed by `chezmoi apply`. Scripts prefixed with `run_once_` run only once (tracked by content hash). Scripts prefixed with `run_onchange_` run whenever the script content changes.

All scripts are numbered for deterministic execution order.

### `run_once_01_install_homebrew.sh.tmpl`

Installs Homebrew if not already present. Only runs once (idempotent by content hash).

```zsh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### `run_onchange_02_brew_packages.sh.tmpl`

Installs Homebrew packages from the appropriate Brewfile. Re-runs when the Brewfile content changes.

- Uses `Brewfile.personal` when `.machine_type == "personal"`
- Uses `Brewfile.swisscom` when `.machine_type == "work"`

```zsh
brew bundle --file={{ .chezmoi.sourceDir }}/Brewfile.{{ .machine_type }}
```

### `run_onchange_03_ssh_keys.sh.tmpl`

Restores SSH keys from iCloud Drive to `~/.ssh/`. Re-runs when the script changes.

### `run_onchange_04_gpg_keys.sh.tmpl`

Imports GPG keys from iCloud Drive. Re-runs when the script changes.

### `run_onchange_05_env_from_icloud.sh.tmpl`

Copies `.env` from iCloud Drive to `$HOME/.env`. Re-runs when the script changes.

### `run_onchange_06_npm_globals.sh.tmpl`

Installs global npm packages listed in `~/.npm.globals`. Re-runs when `.npm.globals` content changes (the script embeds its hash).

### `run_once_07_zsh_permissions.sh`

Fixes zsh completion directory permissions by removing group-write bits. Prevents `compaudit` warnings. Only runs once.

```zsh
compaudit | xargs chmod g-w
```

### `run_once_before_import-keychain.sh.tmpl`

Imports tokens from the iCloud Drive backup file (`Secrets/keychain/tokens`) into the macOS login keychain. Runs once before templates are rendered, ensuring `keyring` calls succeed on a fresh machine.

---

## Package Management

### Homebrew

**Personal packages:** `Brewfile.personal`
**Enterprise/work packages:** `Brewfile.swisscom`

chezmoi automatically runs the correct Brewfile via `run_onchange_02_brew_packages.sh.tmpl` based on `machine_type`.

**Manual install:**

```zsh
brew bundle --file=~/Developer/Git/GitHub/Dotfiles/Brewfile.personal
brew bundle --file=~/Developer/Git/GitHub/Dotfiles/Brewfile.swisscom
```

**Update everything:**

```zsh
brew update && brew upgrade && brew cleanup
```

### npm Global Packages

**Package list:** `~/.npm.globals` (source: `dot_npm.globals`)

**Format:**

```
# Comments allowed
package-name
@scope/package-name
package@version
```

**Auto-installation:**

- `run_onchange_06_npm_globals.sh.tmpl` runs on every `chezmoi apply` when `.npm.globals` changes
- Also runs when switching Node versions via `nvmrc:load` (per-version lock files in `~/.npm/_locks/`)

**Manual installation:**

```zsh
globals:install
```

### `.npmrc` Token Management

`.npmrc` is managed via `dot_npmrc.tmpl`. Tokens are fetched at apply time from the macOS login keychain using chezmoi's built-in `keyring` function. There is no runtime token replacement (`env:replace` has been removed).

**To update a token:**

1. `secret:set registry.npmjs.org npm` — updates keychain + auto-exports to iCloud Drive
2. `chezmoi apply` — re-renders the template with the fresh token

### Node Version Manager (NVM)

**Auto-switching on `cd`:** Detects `.nvmrc` files, installs version if missing, switches automatically, reverts to default when leaving directory.

**Manual commands:**

```zsh
nvm install node        # Install latest
nvm install --lts       # Install LTS
nvm use 18              # Switch to version 18
nvm alias default 20    # Set default version
```

**Update Node:**

```zsh
nvm:update
```

### Bun

```zsh
bun:update
```

### SDKMAN (Java)

Initialized automatically from `.zshrc` if `~/.sdkman/bin/sdkman-init.sh` exists.

---

## Development Workflows

### Initial Setup (New Machine)

```zsh
# 1. Clone repository
git clone <repo-url> ~/Developer/Git/GitHub/Dotfiles

# 2. Initialize chezmoi (prompts for email/name/gpg_key/machine_type)
chezmoi init --source ~/Developer/Git/GitHub/Dotfiles --apply
```

`chezmoi init --apply` will:
- Write `~/.config/chezmoi/chezmoi.toml` with your answers
- Copy all `dot_*` files to `$HOME`
- Render `.tmpl` templates with your data
- Run all `run_once_*` and `run_onchange_*` scripts (keychain import, Homebrew, packages, SSH/GPG keys, npm globals, zsh permissions)

### Editing Configuration Files

**Always edit via chezmoi to keep source and target in sync:**

```zsh
chezmoi edit ~/.zshrc        # Opens source dot_zshrc in $EDITOR
chezmoi edit ~/.exports      # Opens source dot_exports in $EDITOR
chezmoi edit ~/.gitconfig    # Opens source dot_gitconfig.tmpl in $EDITOR
```

**Or use the aliases:**

```zsh
es     # chezmoi edit ~/.zshrc
ev     # chezmoi edit ~/.exports
```

**After editing:**

```zsh
chezmoi diff    # Preview what will change in $HOME
chezmoi apply   # Apply changes to $HOME
```

### Previewing Changes Before Applying

```zsh
chezmoi diff
```

This shows a diff between the current state of files in `$HOME` and what `chezmoi apply` would write.

### Applying Changes

```zsh
chezmoi apply
```

Renders all templates, copies files to `$HOME`, and runs any changed/new run scripts.

### Updating chezmoi Config (email, name, etc.)

```zsh
chezmoi edit-config
# Edit ~/.config/chezmoi/chezmoi.toml directly
chezmoi apply   # Re-render templates with new values
```

### Working with Templates

**Test template rendering:**

```zsh
chezmoi cat ~/.gitconfig    # Print rendered output of a template
chezmoi cat ~/.npmrc        # See rendered .npmrc with tokens substituted
```

**Edit a template:**

```zsh
chezmoi edit ~/.gitconfig   # Opens dot_gitconfig.tmpl
chezmoi apply
```

### Adding a New File to chezmoi

```zsh
chezmoi add ~/.new-config-file
# Creates dot_new-config-file in the source directory
```

### Node Version Management

**Project with `.nvmrc`:**

```zsh
cd ~/projects/my-app  # Auto-switches to .nvmrc version
# Work on project
cd ..                 # Auto-reverts to default version
```

**Manual switch:**

```zsh
nvm use 18
```

**Update Node:**

```zsh
nvm:update
```

### Managing Global npm Packages

```zsh
# 1. Edit package list via chezmoi
chezmoi edit ~/.npm.globals

# 2. Apply change (triggers run_onchange_06_npm_globals.sh.tmpl)
chezmoi apply

# 3. Or install immediately without applying full chezmoi
globals:install
```

### Proxy Management

**Automatic detection:**

```zsh
# Set in ~/.exports
export ALWAYS_PROXY_PROBE=true
export PROXY_HOST=proxy.company.com
export PROXY_PORT=8080
# Proxy auto-detected on every shell start
```

**Manual control:**

```zsh
proxy:set                      # Set using env vars
proxy:set http proxy.com 8080  # Set with custom values
proxy:unset                    # Remove proxy
proxy:probe                    # Auto-detect now
```

### Git Workflows

**Quick status and commit:**

```zsh
gs              # git status
gaa             # git add --all
gca "Fix bug"   # git commit -a -m "Fix bug"
gpu             # git push
```

**Branch management:**

```zsh
gch -b feature/new-thing    # Create and checkout branch
gpu                          # Push
gdb feature/new-thing        # Delete local and remote when done
```

**Stash workflow:**

```zsh
git stash    # Stash changes
gsl          # List stashes
gas 0        # Apply stash@{0}
gsc          # Clear all stashes
```

### Updating Docker Containers

```zsh
docker:cleanup                    # Remove everything
docker:cleanup postgres redis     # Keep specific containers/images
```

### macOS System Management

```zsh
system:setup          # Resets hostname, enables Touch ID for sudo
dock:reset            # Reset Dock and add preferred apps
hostname:set "MacBook"
dns:change "Wi-Fi" "8.8.8.8,8.8.4.4"
```

---

## Troubleshooting

### Shell File Missing

**Symptoms:** On shell start: `[dotfiles] Missing: ~/.exports — Run: chezmoi apply`

**Solution:**

```zsh
chezmoi apply
```

There is no automatic self-healing. The fix is always `chezmoi apply`.

### chezmoi Not Initialized

**Symptoms:** `chezmoi apply` complains about missing config

**Solution:**

```zsh
chezmoi init --source ~/Developer/Git/GitHub/Dotfiles --apply
```

### Template Rendering Fails

**Symptoms:** `chezmoi apply` errors with a template syntax or variable error

**Causes:**

1. Missing variable in `chezmoi.toml`
2. Secret not found in macOS login keychain (run `chezmoi secret keyring set` to add it)
3. Syntax error in a `.tmpl` file

**Debug:**

```zsh
chezmoi cat ~/.gitconfig    # See rendered output
chezmoi diff                # Preview all changes
chezmoi doctor              # Check chezmoi setup
```

**Fix missing variable:**

```zsh
chezmoi edit-config         # Add missing key to chezmoi.toml
chezmoi apply
```

### `.npmrc` Token Wrong or Missing

**Symptoms:** npm registry authentication fails

**Cause:** Secret not found in the macOS login keychain

**Solution:**

```zsh
# Check if the secret exists
secret:get registry.npmjs.org npm

# If missing, add it (writes to keychain + iCloud Drive)
secret:set registry.npmjs.org npm

# Re-apply to re-render .npmrc
chezmoi apply

# Verify rendered output
chezmoi cat ~/.npmrc
```

### Completions Warnings

**Symptoms:** `zsh compinit: insecure directories` warnings

**Solution:**

```zsh
compaudit | xargs chmod g-w
```

This is also handled automatically by `run_once_07_zsh_permissions.sh` on `chezmoi apply`.

### Node Version Not Switching

**Symptoms:** `nvmrc:load` not working, stuck on old version

**Causes:**

1. NVM not loaded
2. `.nvmrc` file malformed
3. Hook not registered

**Solutions:**

```zsh
# Check if NVM loaded
command -v nvm

# Check .nvmrc format (should contain just version number or lts/name)
cat .nvmrc

# Re-register hook
add-zsh-hook chpwd nvmrc:load

# Manual load
nvmrc:load
```

### Globals Not Installing

**Symptoms:** Global npm packages missing after Node version switch

**Solutions:**

```zsh
# Check file exists
ls -la ~/.npm.globals

# Force reinstall (remove lock file)
rm ~/.npm/_locks/.npm.globals.*.lock
globals:install
```

### Proxy Not Working

**Symptoms:** Network requests fail on VPN, work off VPN

**Solutions:**

```zsh
# Check current proxy settings
env | grep -i proxy

# Set manually
proxy:set http proxy.company.com 8080

# Enable auto-detection
export ALWAYS_PROXY_PROBE=true
proxy:probe

# Debug reachability
nc -z -w 3 $PROXY_HOST $PROXY_PORT
echo $?  # Should be 0 if reachable
```

### GPG Issues

**Symptoms:** GPG warnings about lock files or signing failures

**Solutions:**

```zsh
# Remove stale lock files
rm -f ~/.gnupg/public-keys.d/pubring.db*.lock

# Verify GPG key
gpg --list-secret-keys

# Check GPG_TTY is set
echo $GPG_TTY  # Should print a tty path
```

### VS Code Settings Not Updating

**Symptoms:** Changes to VS Code settings not reflected

**Cause:** chezmoi has not been applied after editing `Library/Application Support/Code/User/settings.json` in the source

**Solution:**

```zsh
chezmoi diff    # Check what is pending
chezmoi apply
```

### Command Not Found After Install

**Solutions:**

```zsh
reload                        # Reload shell

# Check PATH
which <command>
brew list | grep <package>
npm list -g | grep <package>
```

### Shell Loading Slow

**Causes:** NVM initialization slow, network checks timing out

**Solutions:**

```zsh
# Time shell startup
time zsh -i -c exit

# Profile startup
zsh -xv 2>&1 | tee /tmp/zsh-profile.log

# Temporarily disable network checks by commenting out in dot_zshrc:
# network:check bun:update ...
# network:check nvm:update ...
# Then: chezmoi apply
```

---

## Summary

This dotfiles system provides:

1. **chezmoi-managed configuration** — file-copy model with Go template rendering, replacing the previous symlink system
2. **Template-driven secrets** — credentials injected at apply time via macOS login keychain (`keyring`), never stored in the repo
3. **Idempotent run scripts** — Homebrew, packages, SSH/GPG keys, `.env`, npm globals, and system config handled automatically on `chezmoi apply`
4. **Comprehensive shell utilities** — proxy/VPN handling, Node version management, Docker cleanup, git workflow enhancements
5. **Machine-type aware config** — `personal` vs `work` drives Brewfile selection and conditional template blocks
6. **Zsh-only** — bash support has been dropped; all configuration targets zsh

**The three commands you need to know:**

```zsh
chezmoi init --source ~/Developer/Git/GitHub/Dotfiles --apply   # First-time setup
chezmoi apply                                                    # Apply any changes
chezmoi diff                                                     # Preview before applying
```
