#!/usr/bin/env bash
set -e
set +x

CLEAR="\033[0m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BOLD="\033[1m"

VERBOSE=

function usage {
    cat <<EOF
Usage: wtlist [-vh]
Lists all git worktrees in the current repository with their respective branch information.

FLAGS:
  -h, --help    Print this help
  -v, --verbose Verbose mode
EOF
    kill -INT $$
}

function warn {
    printf '%b%s%b\n' "$YELLOW" "$1" "$CLEAR"
}

function print_data_as_table {
    local title=$1
    shift 1

    local column1=()
    local column2=()

    for row in "$@"; do
        IFS=',' read -r s1 s2 <<< "$row"
        column1+=("$s1")
        column2+=("$s2")
    done

    local max_width_column1=0
    local max_width_column2=0
    local number_of_rows=${#column1[@]}

    for ((i=0; i<number_of_rows; i++)); do
        local current_length_column1=${#column1[$i]}
        local current_length_column2=${#column2[$i]}

        if [ "$current_length_column1" -gt "$max_width_column1" ]; then
            max_width_column1=$current_length_column1
        fi

        if [ "$current_length_column2" -gt "$max_width_column2" ]; then
            max_width_column2=$current_length_column2
        fi
    done

    # Add padding
    max_width_column1=$((max_width_column1 + 2))

    echo -e "\n${GREEN}Worktrees for repository: ${BOLD}$title${CLEAR}\n"
    for ((i=0; i<number_of_rows; i++)); do
        printf "%-${max_width_column1}s %s\n" "${column1[$i]}" "${column2[$i]}"
    done
}

function collect_and_show_worktrees() {
    local repo_name=""
    local repo_url=$(git config --get remote.origin.url 2>/dev/null)
    if [ -n "$repo_url" ]; then
        repo_name=$(basename -s .git "$repo_url")
    else
        repo_name=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
    fi

    local worktrees
    if [ -n "$VERBOSE" ]; then
        worktrees=$(git worktree list --verbose 2>/dev/null)
    else
        worktrees=$(git worktree list 2>/dev/null)
    fi
    if [ -z "$worktrees" ]; then
        warn "No Worktrees found. Make sure you're operating inside a worktree repository."
        return 0
    fi

    local table_data=()
    while IFS= read -r line; do
      local path=$(echo "$line" | awk '{print $1}')
      if [[ "$path" == *".bare"* ]]; then
        continue
      fi

      local dir_name=$(basename "$path")
      local rest_of_line=$(echo "$line" | cut -d' ' -f2- | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

      table_data+=("$dir_name,$rest_of_line")
    done <<< "$worktrees"

  print_data_as_table "$repo_name" "${table_data[@]}"

  echo ""
}

while true; do
    case $1 in
        help | -h | --help)
            usage
            ;;
        -v | --verbose)
            VERBOSE=true
            shift
            ;;
        *)
            break
            ;;
    esac
done

collect_and_show_worktrees
