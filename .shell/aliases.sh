#!/usr/bin/env bash

# ---------------------------- Filesystem & Navigation ----------------------- #

# Make the dirs command useful
alias dirs='dirs -v'

# Color ls
cmd:exists lsd && alias ls='lsd'

# --------------------------------- Safety ----------------------------------- #

# Safer rm
# This should not interfere with your shell scripts, because IMO most of them
# use either bash or sh. And you should do the same! Make scripts for the
# least common denominator!
if cmd:exists trash-put; then
  alias rm='echo "Please use trash-put"'
fi

# ------------------------------- System Tools ------------------------------- #

# Don't see any reason why we should not use a better top utility if it exists
cmd:exists btop && alias top='btop'

# Use cat on steroids if it exists, and don't page, like cat does
# If you don't like the paging behaviour use bat directly
cmd:exists bat && alias cat='bat --paging=never'

# For enabling lazy loading of ssh keys
alias ssh='ssh -o AddKeysToAgent=yes'

# Use Mosh instead of SSH
# cmd:exists mosh && alias ssh='mosh'

# Make using bash interactively possible
alias bash='PERMIT_BASH=true bash'

# ------------------------------ Editor & Config ----------------------------- #

# Make sure we make an alias from vi & vim to nvim here, because a symlink might
# not be installed automatically for nvim. Usually use update-alternatives for
# debian based systems. If not then we'll set up aliases here:
if [[ ! -L "$(which "${EDITOR}")" ]]; then
  if cmd:exists nvim.appimage; then
    alias vi=nvim.appimage
    alias vim=nvim.appimage
    alias nvim=nvim.appimage
  elif cmd:exists nvim; then
    alias vi=nvim
    alias vim=nvim
  elif cmd:exists vim; then
    alias vi=vim
    alias vim=vim
  fi
fi

# Edit shell config
alias es='$EDITOR ${HOME}/.zshrc'
if [[ -L "${HOME}/.zshrc" ]] && cmd:exists readlink && cmd:exists dirname; then
  alias es='$EDITOR $(dirname $(readlink -f "${HOME}"/.zshrc))'
fi

# Edit variables
alias ev='$EDITOR ${DOTFILES_REPO_PATH}/.shell/vars.sh'

# Open editor in current directory
alias e='$EDITOR .'

# ------------------------------------ Git ----------------------------------- #

alias gs="git status"
alias gca="git commit -a -m"
alias gau="git remote add upstream"
alias gaa="git add --all"
alias gpl="git pull"
alias gpu="git push"
alias gps="git push && say You are awesome!"
alias yolos="git push --force && say That was sneaky!"
alias yolo="git push --force"
alias gcl="git clone"
alias glg="git log"
alias gst="git shortlog -sn"
alias gch="git checkout"
alias gba="git branch -av"
alias gsl="git stash list"
alias gsc="git stash clear"

gdb() {
  if [[ -z "$1" ]]; then
    echo "Usage: gdb <branch>"
    return 1
  fi
  git branch -d -- "$1" && git push origin :"$1"
}

gas() {
  if [[ -z "$1" ]]; then
    echo "Usage: gas <stash_index>"
    return 1
  fi
  git stash apply "stash@{$1}"
}

grb() {
  if [[ -z "$1" ]]; then
    echo "Usage: grb <commit_count>"
    return 1
  fi
  git rebase -i "HEAD~$1"
}

# ------------------------------- Suffix alias ------------------------------- #

alias -s go='$EDITOR'
alias -s md='$EDITOR'
alias -s yaml='$EDITOR'
alias -s yml='$EDITOR'
alias -s js='$EDITOR'
alias -s ts='$EDITOR'
alias -s json='$EDITOR'
