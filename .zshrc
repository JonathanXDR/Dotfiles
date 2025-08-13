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
# TODO: load files directly from repo if the users hasn't linked the dotfiles yet
for file in vars func aliases; do
  [[ ! -f "${HOME}/.shell/${file}.sh" ]] || source "${HOME}/.shell/${file}.sh"
done

# TODO: add auto detection for setup (if certain files are not present try linking them)
env:replace
# proxy:probe
add-zsh-hook chpwd nvmrc:load
# TODO: Don't call services if they are not accessible in corpnet
bun:update
nvm:update
nvmrc:load
node:verify

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
