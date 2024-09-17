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

# use rg if available, otherwise use grep
# TODO yields a syntax error
# grep() {
#   if command -v rg &> /dev/null; then
#     rg "$@"
#   else
#     command grep "$@"
#   fi
# }

# use fd if available, otherwise use find
find() {
  if command -v fd &> /dev/null; then
    fd "$@"
  else
    command find "$@"
  fi
}

# custom function for changing directory with z and listing with exa
cz() {
    if command -v z >/dev/null 2>&1; then
        z "$@" && {
            if command -v exa >/dev/null 2>&1; then
                exa
            else
                ls
            fi
        }
    else
        echo "z is not installed. Falling back to cd."
        cd "$@" && ls
    fi
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
