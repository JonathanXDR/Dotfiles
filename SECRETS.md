# Secrets Management with chezmoi

This document describes the secrets management architecture for this dotfiles system. It covers how secrets are stored, synced, and injected into dotfiles across machines.

---

## Architecture

Secrets are split across two storage layers based on their type. Neither layer stores anything in the dotfiles repository itself — the repo contains only template references.

```
dotfiles repo (GitHub)
│
│   Templates reference secrets but never contain them:
│   {{ keyring "registry.npmjs.org" "npm" }}
│
├── macOS Login Keychain ──────────────────────────────────┐
│   Small text secrets: tokens, passwords, API keys         │
│   Accessed via chezmoi's built-in keyring function         │
│   Backed up to iCloud Drive for new machine setup          │
│                                                            │
├── iCloud Drive (Advanced Data Protection) ────────────────┤
│   Secret files: SSH keys, GPG keys, certificates           │
│   Keychain backup: tokens file for new machine import       │
│   Syncs automatically across Macs via iCloud Drive          │
│   E2E encrypted (requires Advanced Data Protection)         │
│   Accessed via chezmoi run_ scripts                         │
└────────────────────────────────────────────────────────────┘
```

### Why this split?

| Type | Example | Best stored as |
|---|---|---|
| Short text values | `npm_XXXX`, `ghp_abc123` | macOS login keychain entry (retrieved at apply-time via `keyring`) |
| Files with structure and permissions | `id_ed25519`, `private.pem` | File on iCloud Drive (preserves format, permissions, paths) |

---

## Layer 1: macOS Login Keychain via chezmoi `keyring` (Tokens and Passwords)

### How it works

chezmoi's built-in `keyring` template function reads secrets from the macOS login keychain. Under the hood, it calls `/usr/bin/security find-generic-password` — no daemon, no external binary, no JSON parsing.

```
{{ keyring "service-name" "account-name" }}
```

Maps to the macOS Keychain's **service** and **account** fields (generic password items).

### CLI reference

**Add or update a secret:**

```bash
chezmoi secret keyring set --service=registry.npmjs.org --user=npm
# Prompts for the password interactively
```

**Read a secret:**

```bash
chezmoi secret keyring get --service=registry.npmjs.org --user=npm
```

**Delete a secret:**

```bash
chezmoi secret keyring delete --service=registry.npmjs.org --user=npm
```

**Or use macOS `security` directly:**

```bash
# Add/update
security add-generic-password -U -s "registry.npmjs.org" -a "npm" -w "npm_XXXX"

# Read
security find-generic-password -s "registry.npmjs.org" -a "npm" -w

# Delete
security delete-generic-password -s "registry.npmjs.org" -a "npm"
```

### chezmoi integration

In templates, use `keyring` directly:

```
{{- /* dot_npmrc.tmpl */ -}}
//registry.npmjs.org/:_authToken={{ keyring "registry.npmjs.org" "npm" }}
```

No named template wrapper needed — `keyring` is a built-in chezmoi function.

### Required keychain entries

These entries must exist in the macOS login keychain for `chezmoi apply` to succeed:

| Service | Account | Template that uses it |
|---|---|---|
| `registry.npmjs.org` | `npm` | `dot_npmrc.tmpl` |
| `bin.swisscom.com` | `swisscom-npm` | `dot_npmrc.tmpl` (work only) |
| `bin.swisscom.com` | `apps-team-npm` | `dot_npmrc.tmpl` (work only) |
| `ntlm` | `credentials` | `dot_exports.tmpl` (work only) |

### What belongs here

- npm / Yarn / pnpm registry tokens
- GitHub / GitLab personal access tokens
- API keys for cloud services
- Docker registry credentials
- NTLM or proxy credentials
- Any short text secret referenced in config file templates

---

## Layer 2: iCloud Drive (Keys, Certificates, and Keychain Backup)

### How it works

Secret files are stored in a dedicated folder on iCloud Drive. With Advanced Data Protection enabled, all iCloud Drive contents are end-to-end encrypted — Apple cannot access them.

chezmoi `run_` scripts copy these files to their target locations and set correct permissions during `chezmoi apply`.

### Directory structure

```
~/Library/Mobile Documents/com~apple~CloudDocs/
└── Secrets/
    ├── keychain/
    │   └── tokens              # Keychain backup for new machine import
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

### Keychain backup: `tokens` file

The login keychain doesn't sync via iCloud, so we store a plain text tokens file on iCloud Drive that a chezmoi run script (`run_once_before_import-keychain.sh.tmpl`) imports into the keychain on new machines.

**Format:**

```
# service:account:password
# Managed by chezmoi — import into macOS login keychain on new machines
registry.npmjs.org:npm:<actual-token>
bin.swisscom.com:swisscom-npm:<actual-token>
bin.swisscom.com:apps-team-npm:<actual-token>
ntlm:credentials:<actual-credentials>
```

**Important:** Keep this file in sync when you update tokens in the keychain. The import script runs once (`run_once_before_`) so it won't overwrite manually-set keychain entries on subsequent `chezmoi apply` runs.

### About brctl

`brctl` (Bird Resource Control) is a built-in macOS command for managing iCloud Drive sync. "Bird" is Apple's internal name for the iCloud Drive daemon.

```bash
brctl download <path>   # Force-download a cloud-only file stub
```

On a new Mac, iCloud Drive may keep files as cloud-only stubs to save disk space. `brctl download` forces macOS to download the actual file contents.

### What belongs here

- SSH key pairs (`id_ed25519`, `id_rsa`, etc.)
- SSH client config (`~/.ssh/config`) and `known_hosts`
- GPG/PGP private keys, revocation certs, and trust database
- SSL/TLS CA bundles for corporate proxy (`.pem`)
- Client certificates (`.p12`, `.pfx`) if needed
- Keychain token backup (`tokens` file)

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
- iCloud Drive enabled
- Advanced Data Protection enabled
- Homebrew installed

### Steps

```bash
# 1. Clone the dotfiles repo
git clone https://github.com/<your-username>/dotfiles.git ~/Developer/Git/GitHub/Dotfiles

# 2. Install chezmoi
brew install chezmoi

# 3. Ensure iCloud Drive secrets folder is downloaded
brctl download ~/Library/Mobile\ Documents/com~apple~CloudDocs/Secrets

# 4. Initialize and apply chezmoi
chezmoi init --source ~/Developer/Git/GitHub/Dotfiles --apply

# chezmoi will:
#   - Prompt for email, name, GPG key, machine type (first time only)
#   - Run run_once_before_import-keychain.sh.tmpl (imports tokens from iCloud → keychain)
#   - Resolve all keyring template calls from the login keychain
#   - Run remaining run_ scripts (SSH keys, GPG keys, Homebrew, etc.)
#   - Write fully resolved config files to their target locations
```

All secrets flow from iCloud Drive → login keychain → config files. No extra tools to install.

---

## Day-to-Day Workflows

Shell functions in `~/.functions` keep the keychain and iCloud Drive backup in sync automatically. The keychain is the source of truth — the iCloud Drive tokens file is a mirror.

### Adding a new token

```bash
# 1. Add to keychain + auto-export to iCloud Drive (prompts for password)
secret:set api.example.com key

# 2. Reference it in a chezmoi template
#    api_key={{ keyring "api.example.com" "key" }}

# 3. Apply
chezmoi apply
```

### Rotating a secret

```bash
# Updates keychain + auto-exports to iCloud Drive
secret:set registry.npmjs.org npm

# Re-render config files with the new value
chezmoi apply
```

### Removing a secret

```bash
# Removes from keychain + auto-exports to iCloud Drive
secret:remove api.example.com key
```

### Listing managed secrets

```bash
secret:list
# Managed secrets (from tokens file):
#   registry.npmjs.org / npm
#   bin.swisscom.com / swisscom-npm
#   ...
```

### Reading a secret

```bash
secret:get registry.npmjs.org npm

# Preview what chezmoi would write
chezmoi cat ~/.npmrc
```

### Manually re-exporting to iCloud Drive

If you edited the keychain directly (e.g., via `chezmoi secret keyring set` or Keychain Access.app):

```bash
secret:export
```

This reads all entries from the tokens file, fetches fresh passwords from the keychain, and rewrites the file.

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

---

## Migration from apw (Apple Passwords CLI)

### What changed

The previous system used `apw` (Apple Passwords CLI) — a Deno-based tool that ran a background daemon to read from iCloud Keychain. This has been replaced with chezmoi's **built-in `keyring` function** which reads from the macOS login keychain via `/usr/bin/security`.

| Before (apw) | After (keyring) |
|---|---|
| `brew install bendews/homebrew-tap/apw` | Nothing to install — built into chezmoi |
| `apw daemon start` / `apw auth` (once per boot) | No daemon needed |
| `{{ template "apw" list "domain" "user" }}` | `{{ keyring "service" "account" }}` |
| Secrets in iCloud Keychain (Passwords app) | Secrets in macOS login keychain |
| Auto-syncs via iCloud Keychain | Manual sync via iCloud Drive tokens file |

### Migration steps

1. For each secret in the Passwords app, add it to the login keychain:

   ```bash
   chezmoi secret keyring set --service=registry.npmjs.org --user=npm
   # Paste the token when prompted
   ```

2. Create the iCloud Drive backup file:

   ```bash
   mkdir -p ~/Library/Mobile\ Documents/com~apple~CloudDocs/Secrets/keychain
   # Create tokens file with all entries
   ```

3. Run `chezmoi apply` — templates now use `keyring` instead of `template "apw"`

### Files removed

- `.chezmoitemplates/apw` — replaced by built-in `keyring`
- `run_once_after_setup-apw.sh` — no daemon needed

### Files added

- `run_once_before_import-keychain.sh.tmpl` — imports tokens from iCloud Drive into login keychain

---

## Security Considerations

### What's in the git repo

The dotfiles repo contains **zero secrets**. It holds only:

- Template files with `keyring` function calls
- `run_` scripts that reference iCloud Drive paths
- Non-sensitive configuration

The repo can safely be public.

### macOS Login Keychain

- Encrypted at rest using the user's login password
- Accessible only when the user is logged in (unlocked on login)
- No iCloud sync — stays local to each Mac
- Backed up to iCloud Drive via plain text tokens file (ADP-encrypted)

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
| Git repo leaked | No secrets in repo — only `keyring` function calls |
| Mac stolen (powered off) | FileVault encrypts the disk; keychain locked |
| Mac stolen (unlocked) | Physical security; auto-lock; Find My Mac remote wipe |
| Apple subpoenaed / breached | Advanced Data Protection = E2E; Apple cannot decrypt iCloud Drive |
| iCloud Drive tokens file accessed | ADP encryption; file only useful with Mac access to import |
| Keychain accessed by malware | macOS prompts for permission when apps access Keychain items |

---

## Quick Reference

```bash
# --- Shell functions (recommended — keeps keychain + iCloud in sync) ---
secret:set <service> <account>         # Add/update (prompts for password, exports to iCloud)
secret:get <service> <account>         # Read from keychain
secret:remove <service> <account>      # Remove from keychain + iCloud
secret:list                            # List managed service/account pairs
secret:export                          # Re-export keychain → iCloud Drive tokens file

# --- chezmoi keyring (low-level, does NOT sync to iCloud) ---
chezmoi secret keyring set --service=<svc> --user=<acct>   # Add/update
chezmoi secret keyring get --service=<svc> --user=<acct>   # Read
chezmoi secret keyring delete --service=<svc> --user=<acct> # Delete

# --- iCloud Drive (secret files + keychain backup) ---
cp <file> ~/Library/Mobile\ Documents/com~apple~CloudDocs/Secrets/<category>/
brctl download ~/Library/Mobile\ Documents/com~apple~CloudDocs/Secrets  # New Mac

# --- chezmoi ---
chezmoi apply                          # Apply all dotfiles (resolves secrets)
chezmoi diff                           # Preview what would change
chezmoi cat <file>                     # Preview rendered output

# --- Template syntax ---
{{ keyring "registry.npmjs.org" "npm" }}
```
