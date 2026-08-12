#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return
# Define color codes
# BLACK='\[\033[0;30m\]'
# RED='\[\033[0;31m\]'
# GREEN='\[\033[0;32m\]'
# YELLOW='\[\033[0;33m\]'
# BLUE='\[\033[0;34m\]'
MAGENTA='\[\033[38;2;209;182;254m\]'
# CYAN='\[\033[0;36m\]'
# WHITE='\[\033[0;37m\]'
PURPLE='\[\033[38;2;161;107;253m\]'
COLOR_RESET='\[\033[0m\]'

PATH=$PATH:/home/katharsis/.local/bin/:/home/katharsis/.cargo/bin

unset PROMPT_COMMAND

# Set the prompt with color
PS1="${PURPLE}(✿◠‿◠) \W ${MAGENTA}\$(.git-prompt-zkwinkle)${PURPLE}⌘ ${COLOR_RESET}"

export EDITOR=nvim
export LANG=en_US.UTF-8
export CHROOT=$HOME/chroot

# Git alias

alias gc="git commit -m"
alias gbr="git branch"
alias gco="git checkout"
alias glog="git log"
# git
alias gsts='git status'

alias .="pwd"
alias c="clear"
alias off="shutdown now"
alias mimir="~/GitHub/dotfiles/Scripts/lock_screen"
alias vim="nvim"
alias ls='eza -L=0 --icons=auto --no-quotes --group-directories-first'
alias blue='bluetoothctl'
alias grep='grep --color=auto'
alias latam='setxkbmap -layout latam'
alias us='setxkbmap -layout us'
alias lst='eza -L=2 -T --icons=auto --no-quotes --group-directories-first'
alias -- -='cd -'
alias lsa='eza -A --icons=auto --no-quotes --group-directories-first'
alias config='cd ~/GitHub/dotfiles'
alias home='cd ~'
alias ..='cd ..'
alias ...='cd ./..'
alias mkdir='mkdir -pv'
alias repos='cd ~/GitHub/'
alias bashrc='vim ~/.bashrc'
alias srcsh='source ~/.bashrc'
alias hdmi='~/.config/Scripts/display.sh hdmi'
alias dock='~/.config/Scripts/display.sh dock'
alias solo='~/.config/Scripts/display.sh laptop'
alias screens='~/.config/Scripts/display.sh auto'
alias downloads='cd ~/Downloads/'
alias feh='feh -F'
alias proton='proton-ge'
pdf() {
  nohup okular "$(realpath "$1")"
  exit
}

# Path to git script
~/.local/bin/.git-prompt-zkwinkle

# models: thinkpad layout: latam

export PATH=$PATH:/home/katharsis/.spicetify
