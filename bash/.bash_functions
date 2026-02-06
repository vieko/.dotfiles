#!/usr/bin/env bash

# .bash_functions
_fzf_compgen_path() {
  fd --hidden --follow --exclude ".git" . "$1"
}

_fzf_compgen_dir() {
  fd --type d --hidden --follow --exclude ".git" . "$1"
}


# Alternative to find using fd - use 'fdfind' instead of overriding 'find'
if command -v fd &>/dev/null; then
  alias fdfind='fd'
fi

# Custom function for changing directory with z and listing with eza (optimized)
# Since zoxide is loaded immediately, z command will be available
if command -v eza &>/dev/null; then
    cz() { z "$@" && eza; }
else
    cz() { z "$@" && ls; }
fi

# Interactive zoxide navigation using fzf (optimized)
fcd() {
    local dir
    dir=$(zoxide query -l | fzf --preview='eza --tree --level=1 {} 2>/dev/null || ls {}')
    [[ -n "$dir" ]] && cd "$dir"
}

# FZF-based directory navigation (optimized fallback)
ffcd() {
    local dir
    dir=$(fd . "$HOME" --type d --hidden --follow --exclude .git | fzf --preview='eza --tree --level=1 {} 2>/dev/null || ls {}')
    [[ -d "$dir" ]] && cd "$dir"
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

# Fish-style abbreviations for bash (requires bash 4.0+ for associative arrays)
if ((BASH_VERSINFO[0] >= 4)); then
declare -A __bash_abbr_list

# Abbreviation storage file
__ABBR_FILE="$HOME/.bash_abbreviations"

# Load abbreviations from file
__load_abbreviations() {
    [[ -f "$__ABBR_FILE" ]] && source "$__ABBR_FILE"
}

# Save abbreviations to file
__save_abbreviations() {
    {
        echo "#!/usr/bin/env bash"
        echo "# Auto-generated bash abbreviations file"
        echo
        for key in "${!__bash_abbr_list[@]}"; do
            printf "__bash_abbr_list[%q]=%q\n" "$key" "${__bash_abbr_list[$key]}"
        done
    } > "$__ABBR_FILE"
}

# Main abbr function
abbr() {
    case "$1" in
        --add|-a)
            shift
            if [[ $# -ne 2 ]]; then
                echo "Usage: abbr --add <abbreviation> <expansion>" >&2
                return 1
            fi
            __bash_abbr_list["$1"]="$2"
            __save_abbreviations
            echo "Added abbreviation: $1 -> $2"
            ;;
        --erase|-e)
            shift
            if [[ $# -ne 1 ]]; then
                echo "Usage: abbr --erase <abbreviation>" >&2
                return 1
            fi
            if [[ -n "${__bash_abbr_list[$1]:-}" ]]; then
                unset "__bash_abbr_list[$1]"
                __save_abbreviations
                echo "Erased abbreviation: $1"
            else
                echo "Abbreviation '$1' not found" >&2
                return 1
            fi
            ;;
        --list|-l|"")
            if [[ ${#__bash_abbr_list[@]} -eq 0 ]]; then
                echo "No abbreviations defined"
                return 0
            fi
            for key in $(printf '%s\n' "${!__bash_abbr_list[@]}" | sort); do
                printf "abbr -a %s %q\n" "$key" "${__bash_abbr_list[$key]}"
            done
            ;;
        --show|-s)
            shift
            if [[ $# -ne 1 ]]; then
                echo "Usage: abbr --show <abbreviation>" >&2
                return 1
            fi
            if [[ -n "${__bash_abbr_list[$1]:-}" ]]; then
                echo "${__bash_abbr_list[$1]}"
            else
                echo "Abbreviation '$1' not found" >&2
                return 1
            fi
            ;;
        --help|-h)
            cat << 'EOF'
abbr - manage command abbreviations

USAGE:
    abbr --add <abbr> <expansion>     Add an abbreviation
    abbr --erase <abbr>               Remove an abbreviation  
    abbr --list                       List all abbreviations
    abbr --show <abbr>                Show expansion for abbreviation
    abbr --help                       Show this help

EXAMPLES:
    abbr --add gc "git commit"
    abbr --add ll "ls -la"
    abbr --erase gc
EOF
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Use 'abbr --help' for usage information" >&2
            return 1
            ;;
    esac
}

# Expansion function bound to space key
__expand_abbr() {
    local line words word
    line="$READLINE_LINE"
    words=($line)
    
    # Get the last word
    if [[ ${#words[@]} -gt 0 ]]; then
        word="${words[-1]}"
        
        # Check if it's an abbreviation
        if [[ -n "${__bash_abbr_list[$word]:-}" ]]; then
            # Replace the abbreviation with its expansion
            local new_line="${line%$word}${__bash_abbr_list[$word]}"
            READLINE_LINE="$new_line"
            READLINE_POINT=${#new_line}
        fi
    fi
    
    # Insert the space
    READLINE_LINE="$READLINE_LINE "
    READLINE_POINT=$((READLINE_POINT + 1))
}

# Initialize abbreviations
__load_abbreviations

# Bind space key to expansion function (only in interactive mode)
if [[ $- == *i* ]]; then
    bind -x '" ": __expand_abbr'
fi

fi  # End bash 4.0+ check for abbreviations

# ==> dangerous agent shortcuts
xcc() { claude --dangerously-skip-permissions "$@"; }
xcd() { codex --dangerously-bypass-approvals-and-sandbox "$@"; }
