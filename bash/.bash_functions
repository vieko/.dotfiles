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

# Wrapper around `gh copilot suggest` to suggest a command based on a natural language description of the desired output effort
ghcs() {
	TARGET="shell"
	local GH_DEBUG="$GH_DEBUG"
	local GH_HOST="$GH_HOST"

	read -r -d '' __USAGE <<-EOF
	Wrapper around \`gh copilot suggest\` to suggest a command based on a natural language description of the desired output effort.
	Supports executing suggested commands if applicable.

	USAGE
	 $FUNCNAME [flags] <prompt>

	FLAGS
	 -d, --debug              Enable debugging
	 -h, --help               Display help usage
	     --hostname           The GitHub host to use for authentication
	 -t, --target target      Target for suggestion; must be shell, gh, git
	                          default: "$TARGET"

	EXAMPLES

	- Guided experience
	 $ $FUNCNAME

	- Git use cases
	 $ $FUNCNAME -t git "Undo the most recent local commits"
	 $ $FUNCNAME -t git "Clean up local branches"
	 $ $FUNCNAME -t git "Setup LFS for images"

	- Working with the GitHub CLI in the terminal
	 $ $FUNCNAME -t gh "Create pull request"
	 $ $FUNCNAME -t gh "List pull requests waiting for my review"
	 $ $FUNCNAME -t gh "Summarize work I have done in issues and pull requests for promotion"

	- General use cases
	 $ $FUNCNAME "Kill processes holding onto deleted files"
	 $ $FUNCNAME "Test whether there are SSL/TLS issues with github.com"
	 $ $FUNCNAME "Convert SVG to PNG and resize"
	 $ $FUNCNAME "Convert MOV to animated PNG"
	EOF

	local OPT OPTARG OPTIND
	while getopts "dht:-:" OPT; do
		if [ "$OPT" = "-" ]; then     # long option: reformulate OPT and OPTARG
			OPT="${OPTARG%%=*}"       # extract long option name
			OPTARG="${OPTARG#"$OPT"}" # extract long option argument (may be empty)
			OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
		fi

		case "$OPT" in
			debug | d)
				GH_DEBUG=api
				;;

			help | h)
				echo "$__USAGE"
				return 0
				;;

			hostname)
				GH_HOST="$OPTARG"
				;;

			target | t)
				TARGET="$OPTARG"
				;;
		esac
	done

	# shift so that $@, $1, etc. refer to the non-option arguments
	shift "$((OPTIND-1))"

	TMPFILE="$(mktemp -t gh-copilotXXXXXX)"
	trap 'rm -f "$TMPFILE"' EXIT
	if GH_DEBUG="$GH_DEBUG" GH_HOST="$GH_HOST" gh copilot suggest -t "$TARGET" "$@" --shell-out "$TMPFILE"; then
		if [ -s "$TMPFILE" ]; then
			FIXED_CMD="$(cat $TMPFILE)"
			history -s $(history 1 | cut -d' ' -f4-); history -s "$FIXED_CMD"
			echo
			eval "$FIXED_CMD"
		fi
	else
		return 1
	fi
}

# Wrapper around `gh copilot explain` to explain a given input command in natural language
ghce() {
	local GH_DEBUG="$GH_DEBUG"
	local GH_HOST="$GH_HOST"

	read -r -d '' __USAGE <<-EOF
	Wrapper around \`gh copilot explain\` to explain a given input command in natural language.

	USAGE
	 $FUNCNAME [flags] <command>

	FLAGS
	 -d, --debug      Enable debugging
	 -h, --help       Display help usage
	     --hostname   The GitHub host to use for authentication

	EXAMPLES

	# View disk usage, sorted by size
	$ $FUNCNAME 'du -sh | sort -h'

	# View git repository history as text graphical representation
	$ $FUNCNAME 'git log --oneline --graph --decorate --all'

	# Remove binary objects larger than 50 megabytes from git history
	$ $FUNCNAME 'bfg --strip-blobs-bigger-than 50M'
	EOF

	local OPT OPTARG OPTIND
	while getopts "dh-:" OPT; do
		if [ "$OPT" = "-" ]; then     # long option: reformulate OPT and OPTARG
			OPT="${OPTARG%%=*}"       # extract long option name
			OPTARG="${OPTARG#"$OPT"}" # extract long option argument (may be empty)
			OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
		fi

		case "$OPT" in
			debug | d)
				GH_DEBUG=api
				;;

			help | h)
				echo "$__USAGE"
				return 0
				;;

			hostname)
				GH_HOST="$OPTARG"
				;;
		esac
	done

	# shift so that $@, $1, etc. refer to the non-option arguments
	shift "$((OPTIND-1))"

	GH_DEBUG="$GH_DEBUG" GH_HOST="$GH_HOST" gh copilot explain "$@"
}
