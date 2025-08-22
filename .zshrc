# Amazon Q pre block. Keep at the top of this file.
[[ -f "${HOME}/Library/Application Support/amazon-q/shell/zshrc.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/zshrc.pre.zsh"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                   # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion

# Setting PATH for Python
# The original version is saved in .zprofile.pysave

eval "$(pyenv init --path)"
autoload -U add-zsh-hook

# bun completions
[ -s "/Users/$USER/.bun/_bun" ] && source "/Users/$USER/.bun/_bun"

# Load custom files
DOTFILES_REPO_PATH="$HOME/Developer/Git/GitHub/Dotfiles"

files=(vars func aliases)
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

# TODO: add auto detection for setup (if certain files are not present try linking them)
env:replace
# proxy:probe
add-zsh-hook chpwd nvmrc:load

# Only run update commands if network endpoints are reachable
network:check bun:update https://registry.npmjs.org
network:check nvm:update https://raw.githubusercontent.com

nvmrc:load

# Load Angular CLI autocompletion.
source <(ng completion script)

# Set up proxy if in VPN or not
[[ "${ALWAYS_PROXY_PROBE}" == "true" ]]

[[ -f "$HOME/.fig/export/dotfiles/dotfile.zsh" ]] && builtin source "$HOME/.fig/export/dotfiles/dotfile.zsh"

# THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
if [[ $(arch) == "i386" ]]; then eval "$(/usr/local/bin/brew shellenv)"; fi

# Amazon Q post block. Keep at the bottom of this file.
[[ -f "${HOME}/Library/Application Support/amazon-q/shell/zshrc.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/zshrc.post.zsh"
