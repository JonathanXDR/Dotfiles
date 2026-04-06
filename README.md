# Dotfiles

> Opinionated macOS dotfiles managed by [chezmoi](https://chezmoi.io) in symlink mode: template-driven, keychain-backed, iCloud-synced, and idempotent from a clean install.

## Features

- **Symlink mode**: chezmoi symlinks rendered templates into `$HOME`, edits go straight to the source
- **Secrets via macOS Keychain**: credentials injected at apply time via `keychain` template helper, never stored in the repo
- **iCloud Drive as single source**: SSH keys, GPG keys, SSL certs, kubeconfig, and VPN config symlinked directly to iCloud; machine-type config via `config.toml`; keychain tokens backed up for bootstrap
- **Machine-type aware**: `personal` vs `work` drives Brewfiles, proxy config, SSL bundles, and npm registries
- **Auto-switching Node**: `.nvmrc` detection on every `cd` via zsh hook
- **Proxy auto-detection**: event-driven LaunchAgent watches for network changes (Wi-Fi, VPN) and toggles proxy automatically
- **Fast shell startup**: NVM lazy-loaded on first use, compinit cached for 24h, daily update gating for bun/nvm (~0.3s cold start)
- **Machine-type-aware /etc/hosts**: chezmoi-rendered hosts template symlinked from `/etc/hosts`; work-only entries gated by machine type
- **Shell functions**: proxy, VPN, Docker, secrets, Node, Git, system utilities
- **Aliases**: navigation, git, kubernetes, macOS tweaks, editor shortcuts
- **Idempotent setup scripts**: Homebrew, keychain import/export, npm globals, permissions

## Prerequisites

- macOS with Xcode Command Line Tools (`xcode-select --install`)
- [chezmoi](https://chezmoi.io/install/) (`sh -c "$(curl -fsLS get.chezmoi.io)"`)
- iCloud Drive signed in (for keys, config, and token backup)

## Quick Start

```bash
git clone git@github.com:JonathanXDR/Dotfiles.git ~/Developer/Git/GitHub/Dotfiles

chezmoi init --source ~/Developer/Git/GitHub/Dotfiles --apply
```

`chezmoi init` prompts for your name, email, GPG key, and machine type. Machine-specific config (proxy, SSL, enterprise) is read automatically from `config.toml` on iCloud Drive. If the file is not found, chezmoi falls back to interactive prompts. After init, chezmoi automatically:

1. Imports tokens from iCloud Drive into the macOS Keychain
2. Installs Homebrew and all packages from the appropriate Brewfile
3. Symlinks SSH, GPG, SSL, kube, and VPN directories to iCloud Drive
4. Installs global npm packages
5. Symlinks all shell config files into `$HOME`

## Usage

```bash
chezmoi apply          # Apply changes to $HOME
chezmoi diff           # Preview what would change
chezmoi edit ~/.zshrc  # Edit via chezmoi (or edit directly: symlink mode)
```

Shortcut aliases:

| Alias    | Command                   |
| -------- | ------------------------- |
| `es`     | `chezmoi edit ~/.zshrc`   |
| `ev`     | `chezmoi edit ~/.exports` |
| `reload` | Reload shell              |

## Managing Secrets

Secrets are stored in the macOS login keychain and backed up to iCloud Drive.

```bash
secret:set <service> <account>    # Add/update (prompts for password)
secret:get <service> <account>    # Read from keychain
secret:remove <service> <account> # Remove from keychain + iCloud
secret:list                       # List all managed secrets
```

After updating a secret, run `chezmoi apply` to re-render templates with the new value.

## Shell Loading Order

```text
~/.exports ─────────── env vars, proxy, locale, history, zsh options
        │
~/.functions ───────── utility functions
        │
PATH setup ─────────── Homebrew, pyenv, RVM, Bun, ...; NVM lazy-loaded on first use
        │
~/.aliases ─────────── command aliases
        │
~/.completions ─────── zsh plugins, autosuggestions, syntax highlighting
        │
Runtime hooks ──────── nvmrc auto-switch, proxy state load, SSH agent, SDKMAN
```

## Project Structure

```text
.chezmoidata.toml             Shared non-secret defaults
.chezmoi.toml.tmpl            User config (iCloud config.toml or prompts)
.chezmoitemplates/            keychain helper + bash helpers for scripts
.chezmoiscripts/              Numbered setup scripts

symlink_dot_ssh.tmpl          ~/.ssh → iCloud
symlink_dot_ssl.tmpl          ~/.ssl → iCloud (work only, via .chezmoiignore)
symlink_dot_vpn.tmpl          ~/.vpn → iCloud (work only, via .chezmoiignore)
private_dot_gnupg/            ~/.gnupg files → iCloud (6 symlinks)
private_dot_kube/             ~/.kube/config → iCloud

dot_local/bin/                ~/.local/bin/ scripts
  executable_proxy-watchd.tmpl  Proxy state daemon (work only)
Library/LaunchAgents/         ~/Library/LaunchAgents/
  local.proxy-watchd.plist.tmpl  Network-change watcher (work only)

dot_zshrc                     Shell orchestrator
dot_exports.tmpl              Env vars, history, zsh options (templated)
dot_functions                 Shell functions
dot_aliases                   Command aliases
dot_completions               Zsh completions & plugins

dot_gitconfig.tmpl            Git user, GPG signing, LFS
dot_gitignore_global          Global gitignore
dot_npmrc.tmpl                npm registry tokens (from keychain)
dot_npm.globals               Global npm packages list
dot_wakatime.cfg.tmpl         WakaTime API key (from keychain)
dot_config/zed/               Zed editor settings (from keychain)
dot_config/hosts.tmpl         Machine-type-aware /etc/hosts (rendered, symlinked from /etc/hosts)
Library/.../Code/User/        VS Code settings & keybindings

Brewfile.personal             Homebrew packages (personal)
Brewfile.swisscom             Homebrew packages (work)
```

## Architecture

See **[ARCHITECTURE.md](./ARCHITECTURE.md)** for a detailed walkthrough of how the system is organized, how data flows, design decisions, and where to start when navigating the codebase.

## Contributing

This is a personal dotfiles repo. Feel free to fork and adapt for your own setup.

If you spot a bug or have a suggestion, [open an issue](https://github.com/JonathanXDR/Dotfiles/issues).

## License

[MIT](./LICENSE) &copy; Jonathan Russ
