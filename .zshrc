# Amazon Q pre block. Keep at the top of this file.
[[ -f "${HOME}/Library/Application Support/amazon-q/shell/zshrc.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/zshrc.pre.zsh"

# Load custom files (order matters: vars → func → paths → aliases)
DOTFILES_REPO_PATH="$HOME/Developer/Git/GitHub/Dotfiles"

# Define the files here manually because we want to control the load order
files=(vars func paths aliases)
primary_dir="${HOME}/.shell"
backup_dir="${DOTFILES_REPO_PATH}/.shell"

used_backup=0

for f in "${files[@]}"; do
  sourced=0
  for dir in "$primary_dir" "$backup_dir"; do
    candidate="${dir}/${f}.sh"
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
    print "Warning: could not find '${f}.sh' in either ${primary_dir} or ${backup_dir}"
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

# TODO: add auto detection for setup (if certain files are not present try linking them)
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

[[ -f "$HOME/.fig/export/dotfiles/dotfile.zsh" ]] && builtin source "$HOME/.fig/export/dotfiles/dotfile.zsh"

# THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

# Amazon Q post block. Keep at the bottom of this file.
[[ -f "${HOME}/Library/Application Support/amazon-q/shell/zshrc.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/zshrc.post.zsh"