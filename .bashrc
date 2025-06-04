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
# COLOR_RESET='\[\033[0m\]'

PATH=$PATH:/home/katharsis/.local/bin/

unset PROMPT_COMMAND

# Set the prompt with color
PS1="${PURPLE}(✿◠‿◠) \W ${MAGENTA}\$(.git-prompt-zkwinkle)${PURPLE}⌘ ${MAGENTA} "

export EDITOR=nvim
export LANG=en_US.UTF-8
export CHROOT=$HOME/chroot

alias c="clear"
alias off="shutdown now"
alias mimir="/usr/local/bin/lockscreen"
alias vim="nvim"
alias ls='eza -L=1 -T --icons=auto --no-quotes --group-directories-first'
alias blue='bluetoothctl'
alias k='bluetoothctl connect DC:2C:26:34:5F:88'
alias grep='grep --color=auto'
alias latam='setxkbmap -layout latam'
alias us='setxkbmap -layout us'
alias lst='eza -L=2 -T --icons=auto --no-quotes --group-directories-first'
alias lsa='eza -A --icons=auto --no-quotes --group-directories-first'
alias config='cd ~/GitHub/dotfiles'
alias home='cd ~'
alias ..='cd ..'
alias ...='cd ./..'
alias pacman='sudo pacman'
alias mkdir='mkdir -pv'
alias fer='ferdium'
alias wifi='nmtui'
alias bashrc='vim ~/.bashrc'
alias hdmi='xrandr --output eDP-1 --mode 1366x768 --pos 199x1080 --rotate normal --output DP-1 --off --output HDMI-1 --off --output DP-2 --off --output HDMI-2 --mode 1920x1080 --pos 0x0 --rotate normal'
alias downloads='cd ~/Downloads/'
alias tec='cd ~/Documents/TEC/1S2025/'

alias gc='git commit -m'
alias gp='git push'
pdf() {
  nohup okular "$(realpath "$1")"
  exit
}

# Path to git script
. ~/.local/bin/.git-prompt-zkwinkle

# models: thinkpad layout: latam

export PATH=$PATH:/home/katharsis/.spicetify
