#!/usr/bin/env bash
# Based on: https://github.com/llimllib/personal_code/blob/master/homedir/.local/bin/worktree

# Adjusted to work with bare repos

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CLEAR="\033[0m"
VERBOSE=
BRANCH_NAME=
COMMIT_ISH=

function usage {
    cat <<EOF
Usage: wtadd [-vh] [-b BRANCH_NAME] [-c COMMIT-ISH] WORKTREE_NAME
Create a git worktree named WORKTREE_NAME.

Will copy over any .env, .envrc, .tool-versions, or mise.toml files to the
new worktree as well as node_modules.

FLAGS:
  -h, --help               Print this help
  -v, --verbose            Verbose mode
  -b, --branch BRANCH_NAME Specify branch name for the new worktree
                          (defaults to WORKTREE_NAME if not provided)
  -c, --commit COMMIT-ISH  Create worktree from specific commit, tag, or branch
                          (can be SHA, tag name, or branch reference)

EXAMPLES:
  wtadd feature-work                    # Creates worktree and branch both named "feature-work"
  wtadd -b my-feature feature-work      # Creates worktree "feature-work" with branch "my-feature"
  wtadd -c main experiment              # Creates worktree "experiment" from main branch
  wtadd -b hotfix -c abc123def urgent   # Creates worktree "urgent" with branch "hotfix" from commit SHA

EOF
    kill -INT $$
}

function die {
    printf '%b%s%b\n' "$RED" "$1" "$CLEAR"
    # exit the script, but if it was sourced, don't kill the shell
    kill -INT $$
}

function warn {
    printf '%b%s%b\n' "$YELLOW" "$1" "$CLEAR"
}

# If at all possible, use copy-on-write to copy files. This is especially
# important to allow us to copy node_modules directories efficiently
#
# On mac or bsd: try to use -c
# see:
# https://spin.atomicobject.com/2021/02/23/git-worktrees-untracked-files/
#
# On gnu: use --reflink
#
# Use /bin/cp directly to avoid any of the user's aliases - this script is
# often eval'ed
#
# I tried to figure out how to actually determine the filesystem support for
# copy-on-write, but did not find any good references, so I'm falling back on
# "try and see if it fails"
function cp_cow {    
    if ! /bin/cp -Rc "$1" "$2" 2>/dev/null; then
        if ! /bin/cp -R --reflink "$1" "$2" 2>/dev/null; then
            if ! /bin/cp -R "$1" "$2" 2>/dev/null; then
                warn "Unable to copy file $1 to $2 - folder may not exist"
            fi
        fi
    fi
}


# Create a worktree from a given worktree name, and copy some untracked files
function _worktree {
    if [ -z "$1" ]; then
        usage
    fi

    if [ -n "$VERBOSE" ]; then
        set -x
    fi

    worktree_name="$1"

    # If no branch name specified via -b flag, use worktree name as branch name
    if [ -z "$BRANCH_NAME" ]; then
        branchname="$worktree_name"
    else
        branchname="$BRANCH_NAME"
    fi

    # Replace slashes with underscores. If there's no slash, dirname will equal
    # worktree_name. So "feature/something-other" becomes "feature_something-other", but
    # "quick-fix" stays unchanged
    # https://www.tldp.org/LDP/abs/html/parameter-substitution.html
    dirname=${worktree_name//\//_}
    
    is_worktree=$(git rev-parse --is-inside-work-tree)
    if $is_worktree; then
        parent_dir=".."
    else
        parent_dir="."
    fi

    # Validate commit-ish if provided
    if [ -n "$COMMIT_ISH" ]; then
        if ! git rev-parse --verify "$COMMIT_ISH^{commit}" >/dev/null 2>&1; then
            die "Invalid commit-ish: $COMMIT_ISH"
        fi
    fi

    # Handle worktree creation based on whether commit-ish is provided
    if [ -n "$COMMIT_ISH" ]; then
        # When commit-ish is provided, always create a new branch from that commit-ish
        if ! git worktree add -b "$branchname" "$parent_dir/$dirname" "$COMMIT_ISH"; then
            die "failed to create git worktree $branchname from $COMMIT_ISH"
        fi
    else
        # Original logic: check if branch exists locally/remotely, or create new
        # if the branch exists locally:
        if git for-each-ref --format='%(refname:lstrip=2)' refs/heads | grep -E "^$branchname$" > /dev/null 2>&1; then
            if ! git worktree add "$parent_dir/$dirname" "$branchname"; then
                die "failed to create git worktree $branchname"
            fi
        # if the branch exists on a remote:
        elif git for-each-ref --format='%(refname:lstrip=3)' refs/remotes/origin | grep -E "^$branchname$" > /dev/null 2>&1; then
            if ! git worktree add "$parent_dir/$dirname" "$branchname"; then
                die "failed to create git worktree $branchname"
            fi
        else
            # otherwise, create a new branch
            if ! git worktree add -b "$branchname" "$parent_dir/$dirname"; then
                die "failed to create git worktree $branchname"
            fi
        fi
    fi

    # Find untracked files that we want to copy to the new worktree

    # packages in node_modules packages can have sub-node-modules packages, and
    # we don't want to copy them; only copy the root node_modules directory
    if [ -d "node_modules" ]; then
      cp_cow node_modules "$parent_dir/$dirname"/node_modules
    fi

    # this will fail for any files with \n in their names. don't do that.
    IFS=$'\n'

    # (XXX: should I add some mechanism for users to spcify this list? perhaps
    # ~/.config/worktree/untracked or something?)
    #
    # this is the best of a bunch of bad options for reading the files into an
    # array. We're often executing in bash or zsh, so we're going to let them
    # use their file splitting rules, with an explicit IFS. We can't use find's
    # exec because we want to use cp_cow to copy files copy-on-write when
    # possible.
    #
    # Skip any of these files if they're found within node_modules.
    #
    # Putting the `-not -path` argument first is a great deal faster than the
    # other way around
    #
    # shellcheck disable=SC2207
    platform=$(uname)
    if $is_worktree; then
        copy_source="."
    else
        copy_source=./$(git rev-parse --abbrev-ref HEAD)
    fi
    if [ "$platform" = "Darwin" ]; then
        files_to_copy=( $(find -E "$copy_source" -not -path '*node_modules*' -and \
                -iregex '.*\/\.(envrc|env|env.local|tool-versions|mise.toml)' ) )
    else
        files_to_copy=( $(find "$copy_source" -not -path '*node_modules*' -and \
                -regextype posix-extended -iregex '.*\/\.(envrc|env|env.local|tool-versions|mise.toml)' ) )
    fi

    for f in "${files_to_copy[@]}"; do
      target_path="${f#"$copy_source"/}"
      cp_cow "$f" "$parent_dir/$dirname/$target_path"
    done

    # return the shell to normal splitting mode
    unset IFS

    # pull the most recent version of the remote
    # ensure any inherited bare-repo env (GIT_DIR/GIT_WORK_TREE) doesn't leak into this call
    # silence stdout/stderr from git; only show our warning on failure
    if ! env -u GIT_DIR -u GIT_WORK_TREE git -C "$parent_dir/$dirname" pull >/dev/null 2>&1; then
        warn "Unable to run git pull, there may not be an upstream"
    fi

    # if there was an envrc file, tell direnv that it's ok to run it
    if [ -f "$parent_dir/$dirname/.envrc" ]; then
        direnv allow "$parent_dir/$dirname"
    fi
        
    printf "%bcreated worktree %s%b\n" "$GREEN" "$parent_dir/$dirname" "$CLEAR"   
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
        -b | --branch)
            BRANCH_NAME="$2"
            shift 2
            ;;
        -c | --commit)
            COMMIT_ISH="$2"
            shift 2
            ;;
        *)
            break
            ;;
    esac
done

_worktree "$@"