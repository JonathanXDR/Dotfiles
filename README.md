# Dotfiles

Keychain-backed, iCloud-synced and profile-aware macOS dotfiles.

> [!IMPORTANT]
> This is a personal setup. Fork freely, but expect macOS-only assumptions and opinionated defaults.

## ✨ Features

- 🪨 **Foundation:** Built on [chezmoi](https://chezmoi.io) in symlink mode with Go-templated configs
- 🔐 **Secrets:** macOS Keychain source of truth, iCloud-backed, zero plaintext in the repo
- ☁️ **iCloud-synced:** SSH, GPG, SSL, kubeconfig, VPN, and machine `config.toml`
- 💻 **Machine-type aware:** `personal` vs `work` drives Brewfile, proxy, SSL, VPN, npm, `/etc/hosts`
- 🌱 **Auto-activating runtimes:** `.nvmrc` and `environment.yml` detected on every `cd`
- 🚦 **Event-driven proxy:** LaunchAgent watches network changes (Wi-Fi, VPN), toggles automatically
- ⚡ **Performance:** Lazy-loaded NVM, 24h-cached compinit, daily-gated bun/nvm/pyenv/brew checks
- 🛠️ **Shell toolkit:** 75+ functions for proxy, VPN, Docker, secrets, Node, Git, plus curated aliases
- ♻️ **Idempotent bootstrap:** Homebrew install, keychain import/export, npm globals, permission fixups

## 📋 Prerequisites

- macOS with Xcode Command Line Tools (`xcode-select --install`)
- [chezmoi](https://chezmoi.io/install/) (`sh -c "$(curl -fsLS get.chezmoi.io)"`)
- iCloud Drive signed in (for keys, config, and token backup)

## 🚀 Quick Start

```bash
git clone git@github.com:JonathanXDR/Dotfiles.git ~/Developer/Git/GitHub/Dotfiles

chezmoi init --source ~/Developer/Git/GitHub/Dotfiles --apply
```

`chezmoi init` prompts for your name, email, GPG key, and machine type. Machine-specific config (proxy, SSL, enterprise) is read automatically from `config.toml` on iCloud Drive. If the file is not found, chezmoi falls back to interactive prompts.

After init, chezmoi automatically:

1. Imports tokens from iCloud Drive into the macOS Keychain
2. Installs Homebrew and all packages from the appropriate Brewfile
3. Symlinks SSH, GPG, SSL, kube, and VPN directories to iCloud Drive
4. Installs global npm packages
5. Symlinks all shell config files into `$HOME`

## 🧪 Usage

```bash
chezmoi apply          # Apply changes to $HOME
chezmoi diff           # Preview what would change
chezmoi edit ~/.zshrc  # Edit via chezmoi (or edit directly: symlink mode)
```

> [!NOTE]
> Because of symlink mode, you can edit `$HOME` files like `~/.zshrc` directly. `chezmoi edit` is offered for habit's sake, not because it's required.

Shortcut aliases:

| Alias    | Command                   |
| -------- | ------------------------- |
| `es`     | `chezmoi edit ~/.zshrc`   |
| `ev`     | `chezmoi edit ~/.exports` |
| `reload` | Reload shell              |

## 🔐 Managing Secrets

Secrets are stored in the macOS login keychain and backed up to iCloud Drive.

```bash
secret:set <service> <account>    # Add/update (prompts for password)
secret:get <service> <account>    # Read from keychain
secret:remove <service> <account> # Remove from keychain + iCloud
secret:list                       # List all managed secrets
```

> [!TIP]
> After updating a secret, run `chezmoi apply` to re-render templates with the new value.

## 🐚 Shell Loading Order

```text
~/.exports ──────── env vars, proxy, locale, history, zsh options
        │
~/.functions ────── utility functions
        │
PATH setup ──────── Homebrew, pyenv, RVM, Bun, ...; NVM lazy-loaded on first use
        │
~/.aliases ──────── command aliases
        │
~/.completions ──── zsh plugins, autosuggestions, syntax highlighting
        │
Runtime hooks ───── nvmrc auto-switch, proxy state load, SSH agent, SDKMAN
```

## 📦 Project Structure

```text
├── .chezmoi.toml.tmpl                       # User config (iCloud config.toml or prompts)
├── .chezmoidata.toml                        # Shared non-secret defaults
├── .chezmoiignore                           # Files excluded from $HOME
├── .chezmoitemplates/                       # Reusable templates: keychain lookup + shell helpers
├── .chezmoiscripts/                         # Numbered setup scripts (run_once_*, run_onchange_*, run_after_*)
│
├── symlink_dot_ssh.tmpl                     # ~/.ssh → iCloud
├── symlink_dot_ssl.tmpl                     # ~/.ssl → iCloud (work only)
├── symlink_dot_vpn.tmpl                     # ~/.vpn → iCloud (work only)
├── private_dot_gnupg/                       # ~/.gnupg/* → iCloud (6 symlinks)
├── private_dot_kube/                        # ~/.kube/config → iCloud
│
├── dot_local/bin/
│   └── executable_proxy-watchd.tmpl         # Proxy state script (work only)
├── Library/LaunchAgents/
│   └── local.proxy-watchd.plist.tmpl        # LaunchAgent watching network changes (work only)
│
├── dot_zshrc                                # Shell orchestrator
├── dot_exports.tmpl                         # Env vars, history, zsh options
├── dot_functions                            # Shell functions
├── dot_aliases                              # Command aliases
├── dot_completions                          # Zsh completions & plugins
│
├── dot_gitconfig.tmpl                       # Git user, GPG signing, LFS
├── dot_gitignore_global                     # Global gitignore
├── dot_npmrc.tmpl                           # npm registry tokens (from keychain)
├── dot_npm.globals                          # Global npm packages
├── dot_wakatime.cfg.tmpl                    # WakaTime API key (from keychain)
├── dot_config/
│   ├── hosts.tmpl                           # /etc/hosts source (machine-type aware)
│   └── zed/settings.json.tmpl               # Zed editor settings (from keychain)
├── Library/Application Support/Code/User/   # VS Code settings & keybindings
│
├── Brewfile.personal                        # Homebrew packages (personal)
└── Brewfile.swisscom                        # Homebrew packages (work)
```

## ⛰️ Next Steps

1. 📖 Read the [Architecture](./ARCHITECTURE.md) for a walkthrough of how the system is organized.
2. 🔀 Fork this repo and adapt `config.toml`, Brewfiles, and machine types to your setup.
3. 🔐 Move your secrets into the macOS Keychain with `secret:set`.
4. 🐛 Hit a bug or have an idea? [Open an issue](https://github.com/JonathanXDR/Dotfiles/issues).

## ⚖️ License

Licensed under the [MIT license](./LICENSE) &copy; Jonathan Russ.
