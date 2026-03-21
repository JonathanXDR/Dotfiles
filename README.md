# Dotfiles

[![License][license-src]][license-href]
[![chezmoi][chezmoi-src]][chezmoi-href]
[![macOS][macos-src]][macos-href]

> Opinionated macOS dotfiles managed by [chezmoi](https://chezmoi.io) — template-driven, keychain-backed, and idempotent from a clean install.

## Features

- **File-copy model** — chezmoi renders Go templates and copies to `$HOME`, no symlinks
- **Secrets via macOS Keychain** — credentials injected at apply time, never stored in the repo
- **iCloud Drive backup** — SSH keys, GPG keys, and keychain tokens synced for new machine bootstrap
- **Machine-type aware** — `personal` vs `work` drives Brewfiles, proxy config, SSL bundles, and npm registries
- **Auto-switching Node** — `.nvmrc` detection on every `cd` via zsh hook
- **Proxy auto-detection** — VPN/corporate network probe with automatic proxy toggle
- **~65 shell functions** — proxy, VPN, Docker, secrets, Node, Git, system utilities
- **~70 aliases** — navigation, git, kubernetes, macOS tweaks, editor shortcuts
- **11 idempotent setup scripts** — Homebrew, SSH/GPG keys, npm globals, all in numbered order

## Prerequisites

- macOS with Xcode Command Line Tools (`xcode-select --install`)
- [chezmoi](https://chezmoi.io/install/) (`sh -c "$(curl -fsLS get.chezmoi.io)"`)
- iCloud Drive signed in (for SSH keys, GPG keys, and token backup)

## Quick Start

```bash
git clone git@github.com:JonathanXDR/Dotfiles.git ~/Developer/Git/GitHub/Dotfiles

chezmoi init --source ~/Developer/Git/GitHub/Dotfiles --apply
```

`chezmoi init` prompts for your name, email, GPG key, and machine type, then automatically:

1. Imports tokens from iCloud Drive into the macOS Keychain
2. Installs Homebrew and all packages from the appropriate Brewfile
3. Restores SSH keys, GPG keys, and SSL bundles from iCloud Drive
4. Installs global npm packages
5. Copies all shell config files to `$HOME`

## Usage

```bash
chezmoi apply          # Apply changes to $HOME
chezmoi diff           # Preview what would change
chezmoi edit ~/.zshrc  # Edit via chezmoi (keeps source in sync)
```

Shortcut aliases:

| Alias | Command |
| ----- | ------- |
| `es` | `chezmoi edit ~/.zshrc` |
| `ev` | `chezmoi edit ~/.exports` |
| `reload` | Reload shell |

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
~/.exports       env vars, proxy, locale, history, zsh options
     ↓
~/.functions     ~65 utility functions
     ↓
PATH setup       Homebrew, NVM, pyenv, RVM, Bun, ...
     ↓
~/.aliases       ~70 command aliases
     ↓
~/.completions   zsh plugins, autosuggestions, syntax highlighting
     ↓
Runtime hooks    nvmrc auto-switch, proxy probe, SSH agent, SDKMAN
```

## Project Structure

```text
.chezmoidata.toml             Shared non-secret defaults
.chezmoi.toml.tmpl            User config (prompted on init)
.chezmoitemplates/            Reusable bash helpers for scripts
.chezmoiscripts/              11 numbered setup scripts

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

<!-- Badges -->
[license-src]: https://img.shields.io/github/license/JonathanXDR/Dotfiles?style=flat&colorA=18181B&colorB=28CF8D
[license-href]: https://github.com/JonathanXDR/Dotfiles/blob/main/LICENSE
[chezmoi-src]: https://img.shields.io/badge/managed%20by-chezmoi-28CF8D?style=flat&colorA=18181B
[chezmoi-href]: https://chezmoi.io
[macos-src]: https://img.shields.io/badge/platform-macOS-28CF8D?style=flat&colorA=18181B
[macos-href]: https://www.apple.com/macos/
