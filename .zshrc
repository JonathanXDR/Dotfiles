# Kiro CLI pre block. Keep at the top of this file.
[[ -f "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.pre.zsh"
# Load custom files (order matters: vars → func → paths → aliases)
DOTFILES_REPO_PATH="$HOME/Developer/Git/GitHub/Dotfiles"

# Define the files here manually because we want to control the load order
files=(.exports .functions .paths .aliases)
primary_dir="${HOME}/.shell"
backup_dir="${DOTFILES_REPO_PATH}/.shell"

used_backup=0

for f in "${files[@]}"; do
  sourced=0
  for dir in "$primary_dir" "$backup_dir"; do
    candidate="${dir}/${f}"
    if [[ -r "$candidate" ]]; then
      if [[ "$dir" == "$backup_dir" ]]; then
        used_backup=1
        print "Root shell file missing for '${f}', sourcing backup: $candidate"
      fi
      source "$candidate"
      sourced=1
      break
    fi
  done
  if (( ! sourced )); then
    print "Warning: could not find '${f}' in either ${primary_dir} or ${backup_dir}"
  fi
done

# If any backup was used, try to run the link step once.
if (( used_backup )); then
  if command -v dotfiles:link >/dev/null 2>&1; then
    source "${DOTFILES_REPO_PATH}/.zshenv"
    dotfiles:link
  fi
fi

# Setting PATH for Python
# The original version is saved in .zprofile.pysave
autoload -U add-zsh-hook

# bun completions
[ -s "/Users/$USER/.bun/_bun" ] && source "/Users/$USER/.bun/_bun"

env:replace
add-zsh-hook chpwd nvmrc:load

# Only run update commands if network endpoints are reachable
network:check bun:update https://registry.npmjs.org
network:check nvm:update https://raw.githubusercontent.com

nvmrc:load

# Load Angular CLI autocompletion.
source <(ng completion script)

# Set up proxy if in VPN or not
[[ "${ALWAYS_PROXY_PROBE}" == "true" ]] && proxy:probe

# Start sshAgent automatically
[[ "${AUTOSTART_SSH_AGENT}" == "true" ]] && ssh:agent

# THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

if cmd:exists brew; then
  FPATH=$(brew --prefix)/share/zsh-completions:$FPATH

  autoload -Uz compinit
  compinit
fi

source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /opt/homebrew/share/zsh-autocomplete/zsh-autocomplete.plugin.zsh
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /opt/homebrew/share/zsh-history-substring-search/zsh-history-substring-search.zsh

# Kiro CLI post block. Keep at the bottom of this file.
[[ -f "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.post.zsh"
