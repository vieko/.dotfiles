#!/bin/bash
input=$(cat)

CWD=$(echo "$input" | jq -r '.workspace.current_dir')
CWD_TILDE="${CWD/#$HOME/~}"

printf "\033[1mSUMMONING DEMONS\033[22m ▲ %s" "$CWD_TILDE"
