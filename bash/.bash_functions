# .bash_functions
_fzf_compgen_path() {
  fd --hidden --follow --exclude ".git" . "$1"
}

_fzf_compgen_dir() {
  fd --type d --hidden --follow --exclude ".git" . "$1"
}

# _fzf_comprun() {
#   local command=$1
#   shift
#
#   case "$command" in
#     cd)           fzf --preview 'tree -C {} | head -200'   "$@" ;;
#     export|unset) fzf --preview "eval 'echo \$'{}"         "$@" ;;
#     ssh)          fzf --preview 'dig {}'                   "$@" ;;
#     *)            fzf --preview 'bat -n --color=always {}' "$@" ;;
#   esac
# }

# Function to change directory and list contents
cd() {
    z "$@" && exa
}

# Interactive zoxide navigation using fzf
fcd() {
    local dir
    dir=$(zoxide query -l | fzf --preview='exa --tree --level=1 {}')
    if [[ -n "$dir" ]]; then
        cd "$dir"
    fi
}

# FZF-based directory navigation (as a fallback or alternative)
ffcd() {
    local dir
    dir=$(fd . "$HOME" --type d --hidden --follow --exclude .git | fzf --preview='exa --tree --level=1 {}')
    if [[ -d "$dir" ]]; then
        cd "$dir"
    fi
}
