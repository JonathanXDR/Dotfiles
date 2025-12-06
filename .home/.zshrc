# Kiro CLI pre block. Keep at the top of this file.
[[ -f "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.pre.zsh"

# Load custom files (order matters: vars → func → paths → aliases → completions)
DOTFILES_REPO_PATH="$HOME/Developer/Git/GitHub/Dotfiles"

# Define the files here manually because we want to control the load order
files=(.exports .functions .paths .aliases .completions)
backup_dir="${DOTFILES_REPO_PATH}/.shell"

used_backup=0

for f in "${files[@]}"; do
  sourced=0
  
  source "${DOTFILES_REPO_PATH}/.home/.zshenv"
  for dir in "$HOME" "$backup_dir"; do
    candidate="${dir}/${f}"
    if [[ -r "$candidate" ]]; then
      if [[ "$dir" == "$backup_dir" ]]; then
        used_backup=1
        printf "\033[0;33mWarning:\033[0m %s\n" "File \"${f}\" not found in \"${HOME}\""
        printf "\033[0;32mSuccess:\033[0m %s\n" "Using backup from \"${candidate}\""
      fi
      source "$candidate"
      sourced=1
      break
    fi
  done
  if (( ! sourced )); then
    printf "\033[0;31mError:\033[0m   %s\n" "Could not find \"${f}\" in either \"${HOME}\" or \"${backup_dir}\""
  fi
done

# If any backup was used, try to run the link step once.
if (( used_backup )); then
  if command -v dotfiles:link >/dev/null 2>&1; then
    source "${DOTFILES_REPO_PATH}/.home/.zshenv"
    dotfiles:link
  fi
fi

# Setting PATH for Python
# The original version is saved in .zprofile.pysave
autoload -U add-zsh-hook

env:replace
add-zsh-hook chpwd nvmrc:load

# Only run update commands if network endpoints are reachable
network:check bun:update https://registry.npmjs.org
network:check nvm:update https://raw.githubusercontent.com

nvmrc:load

# Set up proxy if in VPN or not
[[ "${ALWAYS_PROXY_PROBE}" == "true" ]] && proxy:probe

# Start sshAgent automatically
[[ "${AUTOSTART_SSH_AGENT}" == "true" ]] && ssh:agent

# THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

# Kiro CLI post block. Keep at the bottom of this file.
[[ -f "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.post.zsh"
