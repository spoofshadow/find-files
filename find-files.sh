#!/usr/bin/env bash
# find-files.sh - fast file and folder search by name, or file search by content.
# Linux counterpart of Find-Files.ps1. Needs only find, grep and awk (standard on Debian).

usage() {
    cat <<'EOF'
Usage: find-files.sh [NAME] [options]

NAME                 Name or wildcard. Plain text = "contains". Not case-sensitive.

Options:
  -p, --path DIR     Where to start searching (default: current folder)
  -t, --type TYPE    all, file or folder (default: all)
  -c, --content TEXT Search for TEXT inside files (files only)
  -r, --regex        Treat --content as an extended regex
  -e, --ext LIST     Only these extensions, comma-separated (e.g. txt,md,csv)
  -m, --max N        Stop after N results (default: unlimited)
  -H, --hidden       Also search hidden (dot) folders
  -o, --open         Pick a result and open it
  -h, --help         Show this help

Examples:
  find-files.sh report                     # files and folders containing "report"
  find-files.sh project -t folder          # folders only
  find-files.sh '*.pdf' -p ~/Documents     # wildcard match (quote it!)
  find-files.sh -c invoice -e txt,csv      # text inside .txt and .csv files
  find-files.sh budget -p / -m 20 -o       # stop at 20 results, then pick one to open
EOF
}

die() { echo "find-files: $*" >&2; exit 1; }
need_arg() { [[ $# -ge 2 && -n $2 ]] || die "option $1 needs a value"; }

name='*' path='.' type='all' content='' regex=0 exts='' max=0 hidden=0 open=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--path)    need_arg "$@"; path=$2;    shift 2 ;;
        -t|--type)    need_arg "$@"; type=$2;    shift 2 ;;
        -c|--content) need_arg "$@"; content=$2; shift 2 ;;
        -e|--ext)     need_arg "$@"; exts=$2;    shift 2 ;;
        -m|--max)     need_arg "$@"; max=$2;     shift 2 ;;
        -r|--regex)   regex=1;  shift ;;
        -H|--hidden)  hidden=1; shift ;;
        -o|--open)    open=1;   shift ;;
        -h|--help)    usage; exit 0 ;;
        -*)           usage >&2; die "unknown option: $1" ;;
        *)            name=$1; shift ;;
    esac
done

case "$type" in all|file|folder) ;; *) die "--type must be all, file or folder" ;; esac
[[ $max =~ ^[0-9]+$ ]] || die "--max must be a number"
path=$(realpath -e -- "$path" 2>/dev/null) || die "path not found"
[[ -d $path ]] || die "not a folder: $path"
[[ $name == *[*?]* ]] || name="*$name*"

# Content and extension filters only make sense for files
[[ -n $content || -n $exts ]] && type='file'

# Skip virtual filesystems and (unless --hidden) dot folders
args=("$path" -mindepth 1 '(' -path /proc -o -path /sys -o -path /dev -o -path /run)
(( hidden )) || args+=(-o '(' -type d -name '.*' ')')
args+=(')' -prune -o -iname "$name")

case "$type" in
    file)   args+=(-type f) ;;
    folder) args+=(-type d) ;;
    all)    args+=('(' -type f -o -type d ')') ;;
esac

if [[ -n $exts ]]; then
    IFS=',' read -ra ext_list <<< "$exts"
    args+=('(')
    for i in "${!ext_list[@]}"; do
        e=${ext_list[$i]#\*}; e=${e#.}
        (( i > 0 )) && args+=(-o)
        args+=(-iname "*.$e")
    done
    args+=(')')
fi

color=0; [[ -t 1 ]] && color=1
results=$(mktemp); trap 'rm -f "$results"' EXIT
start=$(date +%s.%N)

# Prints and counts matches; exits early once --max is reached
print_results() {
    awk -v max="$max" -v color="$color" -v content="${content:+1}" -v out="$results" '
{
    path = $0; line = $0
    if (content) {
        if (match($0, /:[0-9]+:/)) {
            path = substr($0, 1, RSTART - 1)
            if (color) line = "\033[36m" substr($0, 1, RSTART + RLENGTH - 1) "\033[0m" substr($0, RSTART + RLENGTH)
        }
    } else if (color && /\/$/) {
        line = "\033[33m" $0 "\033[0m"
    }
    print line
    print path > out
    if (max > 0 && ++n >= max) exit
}'
}

# Process substitution so we can stop the search as soon as print_results is done,
# instead of find scanning the rest of the tree
if [[ -n $content ]]; then
    grep_flags=(-HnIi -m1)   # filename, line number, skip binaries, ignore case, first hit per file
    if (( regex )); then
        grep_flags+=(-E)
    else
        # Escape regex characters rather than using -F (-iF crashes some older greps)
        content=$(printf '%s' "$content" | sed 's/[][\.*^$]/\\&/g')
    fi
    print_results < <(find "${args[@]}" -print0 2>/dev/null | xargs -0 -r grep "${grep_flags[@]}" -- "$content" 2>/dev/null)
else
    print_results < <(exec find "${args[@]}" '(' -type d -printf '%p/\n' -o -printf '%p\n' ')' 2>/dev/null)
fi
search_pid=$!
pkill -P "$search_pid" 2>/dev/null
kill "$search_pid" 2>/dev/null

count=$(wc -l < "$results")
elapsed=$(awk -v s="$start" -v e="$(date +%s.%N)" 'BEGIN { printf "%.2f", e - s }')
if (( color )); then
    printf '\n\033[32m%d match(es) in %ss\033[0m\n' "$count" "$elapsed"
else
    printf '\n%d match(es) in %ss\n' "$count" "$elapsed"
fi

if (( open && count > 0 )); then
    mapfile -t items < <(head -n 30 "$results")
    for i in "${!items[@]}"; do printf '[%d] %s\n' "$i" "${items[$i]}"; done
    read -rp 'Number to open (Enter to cancel): ' choice
    if [[ $choice =~ ^[0-9]+$ ]] && (( choice < ${#items[@]} )); then
        target=${items[$choice]}
        if command -v xdg-open >/dev/null && [[ -n ${DISPLAY:-}${WAYLAND_DISPLAY:-} ]]; then
            xdg-open "$target" >/dev/null 2>&1 &
        elif [[ -d $target ]]; then
            echo "Folder: cd \"$target\""
        else
            "${EDITOR:-nano}" "$target"
        fi
    fi
fi
