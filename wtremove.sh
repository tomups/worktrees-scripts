#!/usr/bin/env bash
# Source: https://github.com/llimllib/personal_code/blob/master/homedir/.local/bin/rmtree

RED="\033[0;31m"
YELLOW="\033[0;33m"
CLEAR="\033[0m"
VERBOSE=

function usage {
    cat <<"EOF"
Usage: wtremove [-vh] WORKTREE_NAME
Removes and prunes a worktree and its branch.

FLAGS:
  -h, --help    Print this help
  -v, --verbose Verbose mode   
EOF
    exit 1
}

function die {
    # if verbose was set, and we're exiting early, make sure that we set +x to
    # stop the shell echoing verbosely
    if [ -n "$VERBOSE" ]; then
        set +x
    fi
    printf '%b%s%b\n' "$RED" "$1" "$CLEAR"
    exit 1
}

function err {
    printf '%b%s%b\n' "$YELLOW" "$1" "$CLEAR"
}

function warn {
    printf '%b%s%b\n' "$YELLOW" "$1" "$CLEAR"
}

# rmtree <dir> will remove a worktree's directory, then prune the worktree list
# and delete the branch
function rmtree {
    if [ -n "$VERBOSE" ]; then
        set -x
    fi

    # verify that the first argument is a directory that exists, that we want
    # to remove
    if [ -z "$1" ]; then
        die "You must provide a directory name that is a worktree to remove"
    fi

    is_worktree=$(git rev-parse --is-inside-work-tree)
    if $is_worktree; then        
        parent_dir=".."  
    else        
        parent_dir="."
    fi

    # for each argument, delete the directory and remove the worktree
    while [ -n "$1" ]; do
        final_dir="$parent_dir/$1"
        if [ ! -d "$final_dir" ]; then
            err "Unable to find directory $final_dir, skipping"
            shift
            continue
        fi

        warn "removing $1"       

        branch_name=${1//_//}        
        rm -rf "$final_dir"
        git worktree prune && git branch -D "$branch_name"

        shift
    done
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
        -m | --main-branch)
            MAIN_BRANCH=$2
            shift
            ;;
        *)
            break
            ;;
    esac
done

rmtree "$@"
