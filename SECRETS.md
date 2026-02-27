# Secrets Management with chezmoi

This document describes the secrets management architecture for migrating from the current dotfiles system to [chezmoi](https://www.chezmoi.io). It covers how secrets are stored, synced, and injected into dotfiles across machines.

---

## Architecture

Secrets are split across two Apple-native storage layers based on their type. Neither layer stores anything in the dotfiles repository itself — the repo contains only template references.

```
dotfiles repo (GitHub)
│
│   Templates reference secrets but never contain them:
│   {{ template "apw" list "registry.npmjs.org" "npm" }}
│
├── iCloud Keychain (Apple Passwords) ───────────────────────────┐
│   Small text secrets: tokens, passwords, API keys              │
│   Syncs instantly across Macs via iCloud                       │
│   E2E encrypted (Secure Enclave)                               │
│   Accessed via apw CLI                                         │
│                                                                │
├── iCloud Drive (Advanced Data Protection) ─────────────────────┤
│   Secret files: SSH keys, GPG keys, certificates, PEM files    │
│   Syncs automatically across Macs via iCloud Drive             │
│   E2E encrypted (requires Advanced Data Protection enabled)    │
│   Accessed via chezmoi run_ scripts                            │
└────────────────────────────────────────────────────────────────┘
```

### Why this split?

| Type | Example | Best stored as |
|---|---|---|
| Short text values | `ghp_abc123...`, `npm_XXXX` | Apple Passwords entry (retrieved at apply-time) |
| Files with structure and permissions | `id_ed25519`, `private.pem` | File on iCloud Drive (preserves format, permissions, paths) |

Apple Passwords is ideal for values you inject into config files via templates. iCloud Drive is ideal for files that need to exist as-is on the filesystem with specific permissions.

---

## Layer 1: iCloud Keychain via apw (Tokens and Passwords)

### What is apw?

[apw](https://github.com/bendews/apw) (Apple Passwords) is a CLI tool that provides shell access to iCloud Keychain entries stored in the macOS Passwords app. It uses a built-in macOS 14+ helper tool to read credentials and outputs JSON for scripting.

**Requirements:** macOS 14 (Sonoma) or later.

**Key constraint:** apw is **read-only**. Secrets are created and managed through the macOS **Passwords app** (System Settings > Passwords, or the standalone Passwords app on macOS Sequoia+). apw only retrieves them.

### Installation

```bash
brew install bendews/homebrew-tap/apw
brew services start apw
```

### Authentication

apw runs a background daemon that must be authenticated once per boot:

```bash
apw auth
```

This triggers a standard macOS system authentication prompt (Touch ID or system password). After authenticating, all subsequent `apw` commands work without prompts until the next reboot.

### CLI reference

```bash
# Retrieve a password for a domain and username
apw pw get <domain> [username]

# List all passwords for a domain (JSON)
apw pw list <domain>

# Retrieve an OTP code
apw otp get <domain>

# List OTP entries for a domain
apw otp list <domain>
```

All commands return JSON:

```json
{
  "results": [
    {
      "domain": "npmjs.org",
      "username": "token",
      "password": "npm_XXXXXXXXXXXX"
    }
  ],
  "status": 0
}
```

### How to store secrets in Apple Passwords

Since apw is read-only, you create entries through the Passwords app. The trick is to use the **Website** and **Username** fields as a key-pair to identify each secret:

| Website (domain) | Username | Password |
|---|---|---|
| `registry.npmjs.org` | `npm` | `npm_XXXXXXXXXXXX` |
| `bin.swisscom.com` | `swisscom-npm` | `eyJ...` (Artifactory JWT) |
| `bin.swisscom.com` | `apps-team-npm` | `eyJ...` (Artifactory JWT) |
| `ntlm` | `credentials` | `user@domain:hash` (NTLM credentials) |
| `github.com` | `personal-access-token` | `ghp_XXXXXXXXXXXX` |

To add an entry:

1. Open **Passwords** app (or System Settings > Passwords)
2. Click **+** to add a new entry
3. Set **Website** to the domain identifier (e.g., `registry.npmjs.org`)
4. Set **Username** to a descriptive key (e.g., `npm`)
5. Set **Password** to the secret value
6. Save

The entry syncs to all Macs via iCloud Keychain automatically.

### chezmoi integration

chezmoi retrieves secrets from apw using the `output` template function, which runs a command and captures its stdout. Combined with `fromJson`, you can extract specific fields from apw's JSON response.

**Helper template (recommended):** Define a reusable function in your chezmoi config to keep templates clean:

```toml
# ~/.config/chezmoi/chezmoi.toml
# No special secret.command config needed — we use output + fromJson directly
```

**In templates:**

```
{{- /* dot_npmrc.tmpl */ -}}
//registry.npmjs.org/:_authToken={{ (index (output "apw" "pw" "get" "registry.npmjs.org" "npm" | fromJson).results 0).password }}
```

To keep templates readable, extract repeated lookups into a named template:

```
{{- /* .chezmoitemplates/apw */ -}}
{{- (index (output "apw" "pw" "get" (index . 0) (index . 1) | fromJson).results 0).password -}}
```

Then in templates:

```
{{- /* dot_npmrc.tmpl */ -}}
//registry.npmjs.org/:_authToken={{ template "apw" list "registry.npmjs.org" "npm" }}
```

### What belongs here

- npm / Yarn / pnpm registry tokens
- GitHub / GitLab personal access tokens
- API keys for cloud services
- Docker registry credentials
- Any short text secret referenced in config file templates

---

## Layer 2: iCloud Drive (Keys and Certificates)

### How it works

Secret files are stored in a dedicated folder on iCloud Drive. With Advanced Data Protection enabled, all iCloud Drive contents are end-to-end encrypted — Apple cannot access them.

chezmoi `run_` scripts copy these files to their target locations and set correct permissions during `chezmoi apply`.

### Directory structure

```
~/Library/Mobile Documents/com~apple~CloudDocs/
└── Secrets/
    ├── ssh/
    │   ├── id_ed25519
    │   ├── id_ed25519.pub
    │   ├── config
    │   └── known_hosts
    ├── gnupg/
    │   ├── private-keys-v1.d/
    │   ├── openpgp-revocs.d/
    │   ├── trustdb.gpg
    │   ├── common.conf
    │   └── sshcontrol
    └── ssl/
        └── ca-bundle.pem
```

The path `~/Library/Mobile Documents/com~apple~CloudDocs/` is the macOS filesystem location for iCloud Drive. The `Secrets/` subfolder is a convention — name it whatever you prefer.

### chezmoi integration

Define the iCloud Drive path as a chezmoi data variable for reuse across scripts:

```toml
# ~/.config/chezmoi/chezmoi.toml
[data]
    icloud_secrets = "~/Library/Mobile Documents/com~apple~CloudDocs/Secrets"
```

Create `run_` scripts in your chezmoi source directory to install the files:

```bash
# run_once_after_install-ssh-keys.sh.tmpl
#!/bin/bash
set -euo pipefail

SECRETS="{{ .icloud_secrets }}/ssh"

# Ensure iCloud has downloaded the files (not just cloud stubs)
for file in "$SECRETS"/id_ed25519 "$SECRETS"/id_ed25519.pub "$SECRETS"/config; do
    if [[ -f "$file" ]]; then
        brctl download "$file" 2>/dev/null || true
    fi
done

# Brief wait for download to complete if needed
sleep 2

# Install SSH keys
mkdir -p "$HOME/.ssh"
cp "$SECRETS/id_ed25519"     "$HOME/.ssh/id_ed25519"
cp "$SECRETS/id_ed25519.pub" "$HOME/.ssh/id_ed25519.pub"
cp "$SECRETS/config"         "$HOME/.ssh/config"

# Set correct permissions
chmod 700 "$HOME/.ssh"
chmod 600 "$HOME/.ssh/id_ed25519"
chmod 644 "$HOME/.ssh/id_ed25519.pub"
chmod 644 "$HOME/.ssh/config"
```

```bash
# run_once_after_install-gpg-keys.sh.tmpl
#!/bin/bash
set -euo pipefail

SECRETS="{{ .icloud_secrets }}/gnupg"

brctl download "$SECRETS" 2>/dev/null || true
sleep 2

mkdir -p "$HOME/.gnupg"
chmod 700 "$HOME/.gnupg"
cp -R "$SECRETS"/* "$HOME/.gnupg/"
chmod 600 "$HOME/.gnupg/private-keys-v1.d"/*
```

### About brctl

`brctl` (Bird Resource Control) is a built-in macOS command for managing iCloud Drive sync. "Bird" is Apple's internal name for the iCloud Drive daemon.

```bash
brctl download <path>   # Force-download a cloud-only file stub
```

On a new Mac, iCloud Drive may keep files as cloud-only stubs to save disk space. `brctl download` forces macOS to download the actual file contents. Alternatively, right-click the `Secrets/` folder in Finder and choose **Download Now**, or enable **Keep Downloaded** to pin it permanently.

### What belongs here

- SSH key pairs (`id_ed25519`, `id_rsa`, etc.)
- SSH client config (`~/.ssh/config`) and `known_hosts`
- GPG/PGP private keys, revocation certs, and trust database
- SSL/TLS CA bundles for corporate proxy (`.pem`)
- Client certificates (`.p12`, `.pfx`) if needed

---

## Enabling Advanced Data Protection

Advanced Data Protection enables end-to-end encryption for iCloud Drive (among other services). Without it, Apple holds the encryption keys.

1. Open **System Settings** > **Apple ID** > **iCloud** > **Advanced Data Protection**
2. Turn it on and follow the prompts
3. Set up a **recovery contact** or **recovery key** (required — Apple can no longer help you recover data)

> **Important:** If you lose access to all your trusted devices and your recovery method, your data is permanently unrecoverable. Store your recovery key somewhere safe and separate.

---

## New Mac Setup

### Prerequisites

- Signed into the same Apple ID
- iCloud Keychain enabled (System Settings > Apple ID > iCloud > Passwords & Keychain > Sync this Mac)
- iCloud Drive enabled
- Advanced Data Protection enabled
- Homebrew installed

### Steps

```bash
# 1. Clone the dotfiles repo
git clone https://github.com/<your-username>/dotfiles.git ~/Developer/Git/GitHub/Dotfiles

# 2. Install tools
brew install chezmoi
brew install bendews/homebrew-tap/apw

# 3. Start and authenticate the apw daemon
brew services start apw
apw auth    # Touch ID or system password — once per boot

# 4. Verify iCloud Keychain secrets are synced
apw pw list registry.npmjs.org

# 5. Ensure iCloud Drive secrets folder is downloaded
brctl download ~/Library/Mobile\ Documents/com~apple~CloudDocs/Secrets

# 6. Initialize and apply chezmoi
chezmoi init --source ~/Developer/Git/GitHub/Dotfiles --apply

# chezmoi will:
#   - Prompt for email, name, GPG key, machine type (first time only)
#   - Resolve all apw template calls via iCloud Keychain
#   - Run all run_ scripts which copy files from iCloud Drive
#   - Write fully resolved config files to their target locations
```

All secrets flow from iCloud — one Touch ID tap, no keys to transfer, no files to copy manually.

---

## Day-to-Day Workflows

### Adding a new token

1. Open the **Passwords** app
2. Add a new entry with the domain, a descriptive username, and the secret as the password
3. Reference it in a chezmoi template:

   ```
   api_key={{ template "apw" list "api.example.com" "key" }}
   ```

4. Run `chezmoi apply`

The Passwords entry syncs to all your Macs automatically. On the other Mac, just run `chezmoi apply` to pick it up.

### Adding a new key file

```bash
# Copy to iCloud Drive (syncs to all Macs automatically)
cp ~/.ssh/id_new_key ~/Library/Mobile\ Documents/com~apple~CloudDocs/Secrets/ssh/

# Add or update the corresponding run_ script in chezmoi source
chezmoi cd
# Edit the relevant run_once_after_install-ssh-keys.sh.tmpl

# Apply
chezmoi apply
```

### Rotating a secret

1. Open the **Passwords** app
2. Find the entry and update the password field
3. Run `chezmoi apply` on each Mac to regenerate config files with the new value

### Verifying secrets from the command line

```bash
# List all entries for a domain
apw pw list npmjs.org

# Get a specific entry
apw pw get github.com personal-access-token

# Get an OTP code
apw otp get github.com
```

---

## Migration from Current Setup

### What was migrated

The old dotfiles system stored secrets in two places:

- **`$HOME/.env`** — tokens and credentials loaded via `env:load` and injected via `env:replace`
- **`$DOTFILES_CONFIG_PATH_PROTECTED`** (`~/Documents/General/Developer/configs/dotfiles`) — sensitive files (SSH, GPG, etc.) symlinked by `dotfiles:link`

### `.env` is fully superseded

All values from the old `.env` file are now handled by chezmoi:

| Old `.env` variable | Now handled by |
|---|---|
| `ALWAYS_PROXY_PROBE`, `PROXY_*`, `NO_PROXY*` | `dot_exports.tmpl` via `.chezmoi.toml` data (prompted during `chezmoi init`) |
| `SSL_BUNDLE_*`, `NODE_EXTRA_CA_CERTS` | `dot_exports.tmpl` via `.chezmoi.toml` data |
| `NODE_USE_ENV_PROXY` | `dot_exports.tmpl` (hardcoded for work machines) |
| `ENTERPRISE_DOMAIN` | `.chezmoi.toml` data |
| `NTLM_CREDENTIALS` | `dot_exports.tmpl` via `{{ template "apw" }}` (Apple Passwords) |
| `NPM_AUTH_TOKEN` | `dot_npmrc.tmpl` via `{{ template "apw" }}` (Apple Passwords) |
| `SWISSCOM_AUTH_TOKEN` | `dot_npmrc.tmpl` via `{{ template "apw" }}` (Apple Passwords) |
| `APPS_TEAM_AUTH_TOKEN` | `dot_npmrc.tmpl` via `{{ template "apw" }}` (Apple Passwords) |

There is no longer a need for `$HOME/.env`, `env:load` at startup, or `env:replace`. The `env:load` function still exists in `dot_functions` for manual development use if needed.

### Tokens in Apple Passwords

These entries must exist in the Passwords app for `chezmoi apply` to resolve templates:

| Website (domain) | Username | Template that uses it |
|---|---|---|
| `registry.npmjs.org` | `npm` | `dot_npmrc.tmpl` |
| `bin.swisscom.com` | `swisscom-npm` | `dot_npmrc.tmpl` (work only) |
| `bin.swisscom.com` | `apps-team-npm` | `dot_npmrc.tmpl` (work only) |
| `ntlm` | `credentials` | `dot_exports.tmpl` (work only) |

### Files in iCloud Drive

These files were copied to `~/Library/Mobile Documents/com~apple~CloudDocs/Secrets/`:

| Source | iCloud Drive path | chezmoi run script |
|---|---|---|
| `.ssh/id_ed25519`, `.pub`, `config`, `known_hosts` | `Secrets/ssh/` | `run_once_after_install-ssh-keys.sh.tmpl` |
| `.gnupg/private-keys-v1.d/`, `trustdb.gpg`, etc. | `Secrets/gnupg/` | `run_once_after_install-gpg-keys.sh.tmpl` |
| `.ssl/ca-bundle.pem` | `Secrets/ssl/` | `run_once_after_install-ssl-bundle.sh.tmpl` (work only) |

### Cleanup

Once verified working, the old protected configs directory can be removed:

```bash
# rm -rf ~/Documents/General/Developer/configs/dotfiles
```

---

## Security Considerations

### What's in the git repo

The dotfiles repo contains **zero secrets**. It holds only:

- Template files with `output "apw" ...` references
- `run_` scripts that reference iCloud Drive paths
- Non-sensitive configuration

The repo can safely be public.

### iCloud Keychain (Apple Passwords)

- End-to-end encrypted using keys protected by the Secure Enclave
- Requires device authentication (Touch ID or system password) to access
- Syncs only to devices signed into the same Apple ID with Keychain sync enabled
- Apple cannot access the contents

### iCloud Drive with Advanced Data Protection

- End-to-end encrypted when Advanced Data Protection is enabled
- Apple cannot access or recover the contents
- Requires a recovery contact or recovery key as a safety net
- Files are encrypted at rest and in transit

### Local filesystem

- Resolved config files (output of `chezmoi apply`) contain plaintext secrets on disk
- Protected by macOS FileVault (full-disk encryption) — enable it if not already active
- File permissions set by `run_` scripts (e.g., `chmod 600` for SSH keys)

### Threat model

| Threat | Mitigation |
|---|---|
| Git repo leaked | No secrets in repo — only template references |
| Mac stolen (powered off) | FileVault encrypts the disk |
| Mac stolen (unlocked) | Physical security; auto-lock; Find My Mac remote wipe |
| Apple subpoenaed / breached | Advanced Data Protection = E2E; Apple cannot decrypt |
| iCloud account compromised | 2FA required; ADP prevents decryption without trusted device |
| Keychain accessed by malware | macOS prompts for permission when apps access Keychain items |

---

## Quick Reference

```bash
# --- apw (tokens via iCloud Keychain) ---
apw auth                               # Authenticate daemon (once per boot)
apw pw get <domain> [username]         # Retrieve a password
apw pw list <domain>                   # List passwords for a domain
apw otp get <domain>                   # Retrieve an OTP code
apw otp list <domain>                  # List OTP entries for a domain

# --- iCloud Drive (secret files) ---
# Store: copy files to iCloud Drive
cp <file> ~/Library/Mobile\ Documents/com~apple~CloudDocs/Secrets/<category>/

# Force-download on new Mac
brctl download ~/Library/Mobile\ Documents/com~apple~CloudDocs/Secrets

# --- chezmoi ---
chezmoi init <repo-url>                # First-time setup
chezmoi apply                          # Apply all dotfiles (resolves secrets)
chezmoi diff                           # Preview what would change
chezmoi add --template <file>          # Add a file as a template
chezmoi edit <file>                    # Edit a managed file
chezmoi cd                             # Enter the source directory

# --- Template syntax for apw in chezmoi ---
# Single value (verbose):
{{ (index (output "apw" "pw" "get" "registry.npmjs.org" "npm" | fromJson).results 0).password }}

# Using the shared template helper (recommended):
{{ template "apw" list "registry.npmjs.org" "npm" }}
```
