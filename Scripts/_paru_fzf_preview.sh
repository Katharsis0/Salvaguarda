#!/usr/bin/env bash
# fzf preview for the `pain` / `pare` functions in .bashrc: package
# description in green on top, then the full `paru -Si/-Qi` info.
# Extracted from zkwinkle (https://github.com/zkwinkle/.config, zsh/bin/),
# ported from zsh + ripgrep to bash + grep.
#
# $1 = S (repo/AUR search) or Q (installed), $2 = package name

info=$(paru -"$1"i "$2" 2>/dev/null)
desc=$(grep -m1 '^Description' <<<"$info" | sed 's/^Description[^:]*: //')
printf '\e[0;32m%s\e[0m\n' "$desc"
printf '%s\n' "$info"
