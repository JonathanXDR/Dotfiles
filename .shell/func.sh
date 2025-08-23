#!/usr/bin/env bash

# ---------------------------------- Utils ----------------------------------- #

cmd:exists() {
  [[ $# -eq 1 ]] || {
    echo "Usage: cmd:exists <command>" >&2
    return 1
  }
  command -v "$1" &>/dev/null
}

# PATH utility function (build once, mind order)
# Safely adds a directory to PATH only if it exists and isn't already there
path:add() { 
  [[ -d "$1" ]] && case ":$PATH:" in 
    *":$1:"*) ;; 
    *) export PATH="$1:$PATH" ;; 
  esac 
}

# PATH utility function for appending (less common, but useful)
path:append() { 
  [[ -d "$1" ]] && case ":$PATH:" in 
    *":$1:"*) ;; 
    *) export PATH="$PATH:$1" ;; 
  esac 
}

# --------------------------- Networking & Proxy ----------------------------- #

dns:change() {
  if (($# < 2)); then
    echo "Usage: dns:change <network service name> <DNS IPs separated by commas>" >&2
    return 1
  fi

  local network_service="$1"
  IFS=',' read -ra nameservers <<<"$2"

  sudo networksetup -setdnsservers "${network_service}" "Empty" "${nameservers[@]}"
}

proxy:compose-addr() {
  [[ $# -eq 3 ]] || return 1
  printf "%s://%s:%s" "$1" "$2" "$3"
}

proxy:set() {
  local proxy_protocol="${1:-${PROXY_PROTOCOL}}"
  local proxy_host="${2:-${PROXY_HOST}}"
  local proxy_port="${3:-${PROXY_PORT}}"
  local no_proxy="${4:-${NOPROXY}}"

  if [[ -z "${proxy_protocol}" || -z "${proxy_host}" || -z "${proxy_port}" ]]; then
    echo "Usage: proxy:set <protocol> <host> <port> [no_proxy]" >&2
    echo "Or ensure PROXY_PROTOCOL, PROXY_HOST, and PROXY_PORT are set in ${HOME}/.shell/vars.sh" >&2
    return 1
  fi

  local proxy_addr
  proxy_addr="$(proxy:compose-addr "${proxy_protocol}" "${proxy_host}" "${proxy_port}")"

  export http_proxy="${proxy_addr}"
  export https_proxy="${proxy_addr}"
  export ftp_proxy="${proxy_addr}"
  export all_proxy="${proxy_addr}"
  export HTTP_PROXY="${proxy_addr}"
  export HTTPS_PROXY="${proxy_addr}"
  export FTP_PROXY="${proxy_addr}"
  export ALL_PROXY="${proxy_addr}"
  export PIP_PROXY="${proxy_addr}"
  export no_proxy="${no_proxy}"
  export NO_PROXY="${no_proxy}"
  export MAVEN_OPTS="-Dhttp.proxyHost=${proxy_host} -Dhttp.proxyPort=${proxy_port} -Dhttps.proxyHost=${proxy_host} -Dhttps.proxyPort=${proxy_port}"
}

proxy:unset() {
  unset http_proxy https_proxy ftp_proxy all_proxy HTTP_PROXY HTTPS_PROXY FTP_PROXY ALL_PROXY PIP_PROXY no_proxy NO_PROXY MAVEN_OPTS
}

proxy:probe() {
  local with_dns="${1:-}"
  if nc -z -w 3 "${PROXY_HOST}" "${PROXY_PORT}" &>/dev/null; then
    echo "Detected VPN, turning on proxy."
    proxy:set "${PROXY_PROTOCOL}" "${PROXY_HOST}" "${PROXY_PORT}" "${NOPROXY}"
    [[ "${with_dns}" == "dns" ]] && dns:change "${PROXY_DNS:-},${NO_PROXY_DNS:-}"
  else
    # echo "Detected normal network, turning off proxy."
    proxy:unset
    [[ "${with_dns}" == "dns" ]] && dns:change "${NO_PROXY_DNS:-},${PROXY_DNS:-}"
  fi
}

network:check() {
  local cmd="$1" url="$2"
  if command -v "$cmd" >/dev/null 2>&1; then
    if command -v curl >/dev/null 2>&1 && curl -m3 -sSf "$url" >/dev/null 2>&1; then
      "$cmd"
    else
      print "Skipping $cmd (network unavailable or blocked)"
    fi
  fi
}

# ------------------------------ SSH Utilities ------------------------------- #

ssh:reagent() {
  for agent in /tmp/ssh-*/agent.*; do
    export SSH_AUTH_SOCK="${agent}"
    if ssh-add -l &>/dev/null; then
      echo "Found working SSH Agent:"
      ssh-add -l
      return 0
    fi
  done
  echo "Cannot find ssh agent - maybe you should reconnect and forward it?"
  return 1
}

ssh:agent() {
  pgrep -x ssh-agent &>/dev/null && ssh:reagent &>/dev/null || eval "$(ssh-agent)" &>/dev/null
}

# ---------------------------- macOS System Tweaks --------------------------- #

sudo:touch-id() {
  FILE='/etc/pam.d/sudo'
  BACKUP="$(mktemp /tmp/sudo.pam.backup.XXXXXX)"

  cleanup() {
    rm -f "$BACKUP"
  }
  trap cleanup EXIT

  trap 'echo "Error detected – restoring original file" >&2; sudo cp "$BACKUP" "$FILE"; exit 1' ERR

  echo "Backing up $FILE to $BACKUP…"
  sudo cp "$FILE" "$BACKUP"

  if ! sudo grep -q '^# sudo: auth account password session' "$FILE"; then
    echo "Required marker comment not found in $FILE" >&2
    exit 1
  fi

  if ! sudo grep -qF 'auth       sufficient     pam_tid.so' "$FILE"; then
    echo "Inserting pam_tid line…"
    sudo sed -i '' '/^# sudo: auth account password session/a\
auth       sufficient     pam_tid.so
' "$FILE"
  else
    echo "pam_tid line already present, skipping insertion."
  fi

  trap - ERR
  echo "Done. $FILE has been updated successfully."
}

dock:reset() {
  defaults delete com.apple.dock
  killall Dock
  sleep 5

  local apps=("Zen" "Notion" "Visual Studio Code" "Microsoft Teams" "Discord" "GitKraken")

  for app in "${apps[@]}"; do
    defaults write com.apple.dock persistent-apps -array-add "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>/Applications/${app}.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"
  done

  defaults write com.apple.dock mineffect -string "scale"
  defaults write com.apple.dock minimize-to-application -bool true
  defaults write com.apple.dock launchanim -bool false
  defaults write com.apple.dock show-recents -bool false
  defaults write com.apple.dock expose-group-apps -bool true

  killall Dock
}

# ----------------------------- Docker Utilities ----------------------------- #

docker:cleanup() {
  if [[ $# -eq 0 ]]; then
    docker stop "$(docker ps -aq)" 2>/dev/null || true
    docker rm "$(docker ps -aq)" 2>/dev/null || true
    docker rmi "$(docker images -q)" 2>/dev/null || true
  else
    local keywords="$*"
    docker stop "$(docker ps -a --format '{{.ID}} {{.Names}}' | grep -vE "(${keywords})" | awk '{print $1}')" 2>/dev/null || true
    docker rm "$(docker ps -a --format '{{.ID}} {{.Names}}' | grep -vE "(${keywords})" | awk '{print $1}')" 2>/dev/null || true
    docker rmi "$(docker images --format '{{.ID}} {{.Repository}}' | grep -vE "(${keywords})" | awk '{print $1}')" 2>/dev/null || true
  fi
}

# ------------------------- Node/Bun/NVM Tooling ----------------------------- #

nvm:update() {
  if ! nvm install node --latest-npm 2>&1 | tee /dev/null | grep -q "already installed"; then
    nvm use node
    node:verify
  fi
}

node:verify() {
  # Check if node command works after switching to newest version
  if ! node --version >/dev/null 2>&1; then
    echo "Warning: node command failed with newest version, reverting to LTS..."
    # Fallback to the LTS version
    nvm alias default 'lts/*'
    nvm use --lts
    echo "Reverted to LTS node version."
  fi

  local node_version
  node_version=$(node --version)
  local installed_globals_file="${HOME}/.npm.globals.${node_version}.lock"

  if [ ! -f "${installed_globals_file}" ] || [ -f "${HOME}/.npm.globals" ] && [ "$(wc -l <"${installed_globals_file}" 2>/dev/null || echo 0)" -lt "$(grep -cvE '^#|^$' "${HOME}/.npm.globals" 2>/dev/null || echo 1)" ]; then
    globals:install
  fi
}

bun:update() {
  bun upgrade &>/dev/null
}

nvmrc:load() {
  local nvmrc_path
  nvmrc_path="$(nvm_find_nvmrc)"

  if [[ -n "${nvmrc_path}" ]]; then
    local nvmrc_node_version
    nvmrc_node_version=$(nvm version "$(cat "${nvmrc_path}")")

    if [[ "${nvmrc_node_version}" == "N/A" ]]; then
      nvm install
    elif [[ "${nvmrc_node_version}" != "$(nvm version)" ]]; then
      nvm use
    fi
  elif [[ -n "$(PWD=${OLDPWD} nvm_find_nvmrc)" ]] && [[ "$(nvm version)" != "$(nvm version default)" ]]; then
    echo "Reverting to nvm default version"
    nvm use default
  fi
}

globals:install() {
  if [ -f "$NPM_GLOBALS" ]; then
    grep -vE '^#|^$' "$NPM_GLOBALS" | xargs npm install -g --force

    local node_version
    node_version=$(node --version)
    local lock_file="$NPM_GLOBALS.${node_version}.lock"
    grep -vE '^#|^$' "$NPM_GLOBALS" >"${lock_file}"

    echo "Global packages installed."
  else
    echo ".npm.globals file not found."
  fi
}

ncu:update() {
  ncu -u
  rm -rf node_modules
  rm -f yarn.lock package-lock.json pnpm-lock.yaml bun.lock
  ni
}

# --------------------- Environment Management Functions --------------------- #

# Load .env file into shell environment
env:load() {
  local env_file="${1:-$HOME/.env}"
  if [[ -f "$env_file" ]]; then
    local loaded_count=0
    
    # Process each line
    while IFS= read -r line || [[ -n "$line" ]]; do
      # Skip comments and empty lines
      [[ "$line" =~ ^[[:space:]]*# ]] && continue
      [[ -z "${line// }" ]] && continue
      
      # Validate format (KEY=VALUE) and export
      if [[ "$line" =~ ^[a-zA-Z_][a-zA-Z0-9_]*= ]]; then
        local key="${line%%=*}"
        local value="${line#*=}"
        export "${key}=${value}"
        ((loaded_count++))
      fi
    done < "$env_file"
  fi
}

# Replace environment variables in npmrc and load .env
env:replace() {
  # First load the .env file into the shell environment
  env:load "$HOME/.env"
  
  # Then run the npmrc replacement
  if [[ -f "${HOME}/.env" ]]; then
    CURRENT_DIR=$(pwd)
    cd "$HOME" || exit

    npx npmrc-replace-env -w
    cd "$CURRENT_DIR" || exit
  else
    echo ".env file not found."
  fi
}

# --------------------------- Dotfiles Management ---------------------------- #

dotfiles:link() {
  local target_dir="$HOME"
  local -a skip_files=(".DS_Store" ".git" ".gitignore" "LICENSE" "README.md")
  local -a default_sources=(
    "${DOTFILES_REPO_PATH}"
    "${DOTFILES_CONFIG_PATH}"
  )
  local -a source_dirs=()

  if (( $# > 0 )); then
    source_dirs=("$@")
  else
    source_dirs=("${default_sources[@]}")
  fi

  for source_dir in "${source_dirs[@]}"; do
    if [[ ! -d "$source_dir" ]]; then
      echo "Source dir not found: $source_dir (skipping)" >&2
      continue
    fi

    for file in "$source_dir"/.*; do
      local filename
      filename=$(basename "$file")

      [[ "$filename" == "." || "$filename" == ".." ]] && continue

      if [[ " ${skip_files[*]} " == *" $filename "* ]]; then
        echo "Skipping $filename"
        continue
      fi

      local target="$target_dir/$filename"

      if [[ -e "$target" || -L "$target" ]]; then
        echo "Removing existing $target"
        rm -f "$target"
      fi

      ln -s "$file" "$target"
      echo "Created symlink for $filename (from $source_dir)"
    done
  done

  dotfiles:cleanup
}

dotfiles:cleanup() {
  # Remove stale lock files
  rm -f "$DOTFILES_CONFIG_PATH/.gnupg/public-keys.d/pubring.db.lock"
}

# ------------------------------ Git Utilities ------------------------------- #

git:diff() {
  local source_branch="$1"
  local target_branch="$2"
  local exclude_pattern="$3"

  if [[ -n "$exclude_pattern" ]]; then
    git diff --name-only "$source_branch...$target_branch" -- ":!$exclude_pattern" | while read -r file; do
      echo -e "\n$file:\n"
      git show "$target_branch:$file"
    done | pbcopy
  else
    git diff --name-only "$source_branch...$target_branch" | while read -r file; do
      echo -e "\n$file:\n"
      git show "$target_branch:$file"
    done | pbcopy
  fi

  echo "Diff output copied to clipboard."
}

git:history() {
  editor="code"
  editor_args=""
  while [ $# -gt 0 ]; do
    case "$1" in
    --editor)
      shift
      if [ $# -eq 0 ]; then
        printf 'Error: --editor requires an argument.\n' >&2
        return 1
      fi
      editor="$1"
      shift
      ;;
    --)
      shift
      editor_args="$*"
      break
      ;;
    *)
      printf 'Usage: git:history [--editor <editor>] [-- <editor_args>]\n' >&2
      return 1
      ;;
    esac
  done

  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    printf 'Error: Not a git repository.\n' >&2
    return 1
  fi

  tmpfile=$(mktemp -t git-history-XXXXXX)
  git log --pretty=medium >"$tmpfile"

  if ! command -v "$editor" >/dev/null 2>&1; then
    printf 'Error: Editor "%s" not found.\n' "$editor" >&2
    rm -f "$tmpfile"
    return 1
  fi

  if [ -z "$editor_args" ]; then
    case "$editor" in
    code | idea)
      editor_args="--wait"
      ;;
    esac
  fi

  if [ -n "$editor_args" ]; then
    $editor "$editor_args" "$tmpfile" || {
      printf 'Error: Editor exited with an error.\n' >&2
      rm -f "$tmpfile"
      return 1
    }
  else
    $editor "$tmpfile" || {
      printf 'Error: Editor exited with an error.\n' >&2
      rm -f "$tmpfile"
      return 1
    }
  fi

  printf 'Are you sure you want to rewrite the entire git history? (Yes/No): '
  read confirmation
  case "$confirmation" in
  Yes | yes) ;;
  *)
    printf 'Aborted by user.\n'
    rm -f "$tmpfile"
    return 1
    ;;
  esac

  # Create a temporary mapping directory.
  mapping_dir=$(mktemp -d -t git-history-map-XXXXXX)

  # Process the git log output to build mapping files.
  commit_hash=""
  author=""
  email=""
  date=""
  message=""
  in_message=0
  first_message_line=1

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
    commit\ *)
      if [ -n "$commit_hash" ]; then
        # Write out the mapping for the previous commit.
        {
          printf "%s\n" "$author"
          printf "%s\n" "$email"
          printf "%s\n" "$date"
          printf "\n"
          printf "%s\n" "$message"
        } >"$mapping_dir/$commit_hash"
      fi
      commit_hash=$(printf '%s' "$line" | sed 's/^commit //')
      author=""
      email=""
      date=""
      message=""
      in_message=0
      first_message_line=1
      ;;
    Merge:\ *)
      # Ignore merge header lines.
      ;;
    Author:\ *)
      author_line=$(printf '%s' "$line" | sed 's/^Author: //')
      author=$(printf '%s' "$author_line" | sed 's/ <.*//')
      email=$(printf '%s' "$author_line" | sed 's/^.*<//; s/>$//')
      ;;
    Date:\ *)
      date=$(printf '%s' "$line" | sed 's/^Date: //; s/^ *//; s/ *$//')
      ;;
    "")
      if [ $in_message -eq 1 ]; then
        message="$message
"
      else
        in_message=1
        first_message_line=1
      fi
      ;;
    *)
      if [ $in_message -eq 1 ]; then
        trimmed=$(printf '%s' "$line" | sed 's/^    //')
        if [ $first_message_line -eq 1 ]; then
          message="$message$trimmed"
          first_message_line=0
        else
          message="$message
$trimmed"
        fi
      fi
      ;;
    esac
  done <"$tmpfile"

  # Write mapping for the last commit (if any).
  if [ -n "$commit_hash" ]; then
    {
      printf "%s\n" "$author"
      printf "%s\n" "$email"
      printf "%s\n" "$date"
      printf "\n"
      printf "%s\n" "$message"
    } >"$mapping_dir/$commit_hash"
  fi

  rm -f "$tmpfile"
  export MAPPING_DIR="$mapping_dir"

  # Rewrite history using filter-branch, looking up metadata by commit hash.
  FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch -f \
    --env-filter '
      if [ -f "$MAPPING_DIR/$GIT_COMMIT" ]; then
        a=$(sed -n "1p" "$MAPPING_DIR/$GIT_COMMIT")
        e=$(sed -n "2p" "$MAPPING_DIR/$GIT_COMMIT")
        d=$(sed -n "3p" "$MAPPING_DIR/$GIT_COMMIT")
        if [ -n "$a" ]; then
          GIT_AUTHOR_NAME="$a"
          GIT_AUTHOR_EMAIL="$e"
          GIT_AUTHOR_DATE="$d"
          GIT_COMMITTER_NAME="$a"
          GIT_COMMITTER_EMAIL="$e"
          GIT_COMMITTER_DATE="$d"
          export GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_AUTHOR_DATE
          export GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL GIT_COMMITTER_DATE
        fi
      fi
    ' \
    --msg-filter '
      if [ -f "$MAPPING_DIR/$GIT_COMMIT" ]; then
        # Delete the first 4 lines (author, email, date, blank) and output the remainder as the commit message.
        m=$(sed "1,4d" "$MAPPING_DIR/$GIT_COMMIT")
        if [ -n "$m" ]; then
          printf "%s\n" "$m"
        else
          cat
        fi
      else
        cat
      fi
    ' \
    -- --all || {
    printf 'Error: Failed to rewrite Git history.\n' >&2
    rm -rf "$MAPPING_DIR"
    return 1
  }

  # Clean up the mapping directory.
  rm -rf "$MAPPING_DIR"

  printf 'Git history has been rewritten successfully.\n'
  printf 'Note: If you have already pushed this branch, you will need to force push:\n'
  printf 'git push --force-with-lease\n'
}
