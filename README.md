# Dotfiles

Keychain-backed, iCloud-synced, machine-aware macOS dotfiles.

> [!IMPORTANT]
> This is a personal setup. Fork it freely, but expect macOS-only assumptions and opinionated defaults.

## Features

- 🪨 **Foundation:** [chezmoi](https://chezmoi.io) in symlink mode, Go templates for per-machine configs
- 🔐 **Secrets:** macOS Keychain source of truth, iCloud-backed, zero plaintext in the repo
- ☁️ **iCloud-synced:** SSH, GPG, SSL, kubeconfig, VPN, and machine `config.toml`
- 💻 **Machine-type aware:** `personal` vs `work` drives Brewfile, proxy, SSL, VPN, npm, `/etc/hosts`
- 🌱 **Auto-activating runtimes:** `.nvmrc`, `.node-version`, `.python-version`, and `environment.yml` detected on every `cd`
- 🚦 **Event-driven proxy:** LaunchAgent watches network changes (Wi-Fi, VPN), toggles automatically
- ⚡ **Performance:** Compiled-binary version resolution, daily-gated mise/brew checks, cached completions
- 🛠️ **Shell toolkit:** 70+ functions for proxy, VPN, Docker, secrets, toolchains, Git, plus curated aliases
- ♻️ **Idempotent bootstrap:** Homebrew install, keychain import/export, mise tools, permission fixups

## 📋 Prerequisites

> [!WARNING]
> Turn on [Advanced Data Protection](https://support.apple.com/en-us/108756) before you bootstrap. Without it, everything this setup keeps on iCloud Drive (SSH, GPG, SSL, kube, VPN, the token backup, and `config.toml`) is encrypted under keys Apple also holds, rather than keys only your trusted devices hold.

- macOS with Xcode Command Line Tools (`xcode-select --install`)
- [chezmoi](https://chezmoi.io/install/) (`sh -c "$(curl -fsLS get.chezmoi.io)"`)
- iCloud Drive signed in (for keys, config, and the token backup)

## 🚀 Quick Start

```bash
git clone git@github.com:JonathanXDR/Dotfiles.git ~/Developer/Git/GitHub/Dotfiles

chezmoi init --source ~/Developer/Git/GitHub/Dotfiles --apply
```

During `chezmoi init`, chezmoi asks for your machine type first, then for your email, name, and GPG key, then for a keychain password. Work machines are also asked for proxy, SSL, and enterprise settings. Everything after the machine type is resolved key by key, taken from `config.toml` on iCloud Drive when that file supplies it and prompted for when it does not. Your answers are cached, so later runs stay quiet.

From there, chezmoi does the rest:

1. Installs Homebrew if it is missing
2. Imports your tokens from iCloud Drive into the `dotfiles` keychain
3. Symlinks `~/.ssh` to its iCloud Drive copy (plus `~/.ssl` and `~/.vpn` on work machines), creates `~/.gnupg` and `~/.kube` as real directories whose entries are symlinks into iCloud Drive, and links the shell config files into `$HOME`
4. Installs everything in the Brewfile for your machine type
5. Installs language runtimes and global CLI packages with mise

## 🧪 Usage

```bash
chezmoi apply          # Apply changes to $HOME
chezmoi diff           # Preview what would change
chezmoi edit ~/.zshrc  # Edit through chezmoi (or open the file directly)
```

> [!TIP]
> In symlink mode, `~/.zshrc` and the other dotfiles point straight at this repo, so editing them in `$HOME` edits the source. The `chezmoi edit` command is there out of habit, not because you need it.

Shortcut aliases:

| Alias    | Command                   |
| -------- | ------------------------- |
| `es`     | `chezmoi edit ~/.zshrc`   |
| `ev`     | `chezmoi edit ~/.exports` |
| `reload` | Reload shell              |

## 🔐 Managing Secrets

Secrets live in a dedicated **`dotfiles` keychain**, separate from `login` and with its own entry in the Keychain Access sidebar. The keychain is the source of truth, and the tokens file on iCloud Drive mirrors it so a fresh machine has something to import from.

The first `chezmoi apply` creates the keychain, and `run_before_00-unlock-keychain` unlocks it once per run, so every template that reads a secret renders in one pass without prompting you again. The keychain locks on system sleep and has no idle timeout (`security set-keychain-settings -l`).

```bash
secret:set <id> <account> <where> <kind> [comment]   # Add a new entry (prompts for password)
secret:get <id> <account>                            # Read raw value to stdout
secret:copy <id> <account>                           # Copy to clipboard, auto-clears in 30s
secret:rename <old_id> <old_account> <new_id> <new_account> [new_where] [new_kind] [new_comment]
                                                     # Move/relabel atomically
secret:remove <id> <account>                         # Remove from keychain + iCloud
secrets:list                                         # Sorted table of all keychain entries
secrets:import                                       # Import tokens-file entries missing from the keychain, report drift
secrets:export                                       # Rewrite the tokens file from the keychain (auto-runs on apply)
```

The `secret:` functions act on a single entry, while the `secrets:` functions act on the whole set.

Each entry uses five native Keychain Access fields, and the `(id, account)` pair is its unique lookup key. The `id` argument fills the Label (Name) field and the URL goes into Service (Where), which keeps URLs out of committed templates:

| Field        | Holds                                                    |
| ------------ | -------------------------------------------------------- |
| **Where**    | URL of the provider (Service, stored in keychain only)   |
| **Account**  | Identity at that provider                                |
| **Name**     | Friendly identifier (the `<id>` arg, default lookup key) |
| **Kind**     | Secret type (e.g. Personal Access Token)                 |
| **Comments** | Consumer (what reads this secret)                        |

Run `secrets:list` to see what the keychain currently holds. It prints the metadata for every entry and never the secrets themselves.

**Configuration** (`.chezmoidata.toml`):

| Key                     | Default      | Purpose                                                                |
| ----------------------- | ------------ | ---------------------------------------------------------------------- |
| `keychain_name`         | `"dotfiles"` | Name of the keychain file (`~/Library/Keychains/<name>.keychain-db`)   |
| `keychain_lookup_field` | `"name"`     | Which field templates query by (`name` / `where` / `kind` / `comment`) |

You can also give the keychain a **master password** during `chezmoi init`. It is cached in the machine-local `~/.config/chezmoi/chezmoi.toml` and never committed. Leave it empty (the default) and the keychain follows your login session's unlock state instead.

> [!CAUTION]
> Managed entries are created with the `-A` flag, so any process running as your user can read them without a confirmation prompt. The chezmoi templates need this to render at apply time. The usual protections still matter here: FileVault, screen auto-lock, a strong account password, and two-factor authentication on your Apple ID.

## 🐚 Shell Loading Order

```text
~/.zshenv ───────── mise shims (every zsh, including non-interactive)
        │
/etc/zprofile ───── macOS path_helper rebuilds PATH (login shells only)
        │
~/.zprofile ─────── restores the mise shims to the front of PATH
        │
~/.exports ──────── env vars, proxy, locale, history, zsh options
        │
~/.functions ────── utility functions
        │
PATH setup ──────── tool paths, Homebrew, conda, then mise activation (last)
        │
~/.aliases ──────── command aliases
        │
~/.completions ──── completions, zsh plugins, autosuggestions, syntax highlighting
        │
Runtime hooks ───── conda auto-activate, proxy state, SSH agent, daily mise & brew checks
```

## 📦 Project Structure

```text
├── .chezmoi.toml.tmpl                       # User config (iCloud config.toml or prompts)
├── .chezmoidata.toml                        # Shared non-secret defaults
├── .chezmoidata/                            # Generated data files (Zed extensions)
├── .chezmoiignore                           # Files excluded from $HOME
├── .chezmoitemplates/                       # Reusable templates: keychain lookup + shell helpers
├── .chezmoiscripts/                         # Numbered setup scripts (run_before_*, run_once_*, run_onchange_*, run_after_*)
│
├── symlink_dot_ssh.tmpl                     # ~/.ssh → iCloud
├── symlink_dot_ssl.tmpl                     # ~/.ssl → iCloud (work only)
├── symlink_dot_vpn.tmpl                     # ~/.vpn → iCloud (work only)
├── private_dot_gnupg/                       # ~/.gnupg/* → iCloud (6 symlinks)
├── private_dot_kube/                        # ~/.kube/config → iCloud
│
├── dot_local/bin/
│   └── executable_proxy-watchd.tmpl         # Proxy probe on network change, exports proxy vars for GUI apps (work only)
├── Library/LaunchAgents/
│   └── local.proxy-watchd.plist.tmpl        # LaunchAgent watching network changes (work only)
│
├── dot_zshenv                               # PATH for non-interactive shells (mise shims)
├── dot_zprofile                             # Restores the mise shims after macOS path_helper (login shells)
├── dot_zshrc                                # Interactive shell entry point
├── dot_exports.tmpl                         # Env vars, history, zsh options
├── dot_functions                            # Shell functions
├── dot_aliases                              # Command aliases
├── dot_completions                          # Completions & zsh plugins
│
├── dot_gitconfig.tmpl                       # Git user, GPG signing, LFS
├── dot_gitignore_global                     # Global gitignore
├── dot_npmrc.tmpl                           # npm registry tokens (from keychain)
├── dot_wakatime.cfg.tmpl                    # WakaTime API key (from keychain)
├── dot_config/
│   ├── hosts.tmpl                           # /etc/hosts source (machine-type aware)
│   ├── mise/config.toml                     # Language runtimes + global CLI packages
│   └── zed/settings.json.tmpl               # Zed editor settings (from keychain)
├── private_dot_claude/                      # ~/.claude/* (0700)
│   └── private_settings.json.tmpl           # Claude Code user settings (plugins, hooks)
├── Library/Application Support/Code/User/   # VS Code settings & keybindings
│
├── Brewfile.personal                        # Homebrew packages (personal)
└── Brewfile.work                            # Homebrew packages (work)
```

## ⛰️ Next Steps

1. 📖 Read [ARCHITECTURE.md](./ARCHITECTURE.md) for a walkthrough of how the pieces fit together.
2. 🔀 Fork this repo and adapt `config.toml`, the Brewfiles, and the machine types to your setup.
3. 🔐 Move your secrets into the macOS Keychain with `secret:set`.
4. 🐛 Hit a bug or have an idea? [Open an issue](https://github.com/JonathanXDR/Dotfiles/issues).

## ⚖️ License

Licensed under the [MIT license](./LICENSE) &copy; Jonathan Russ.
