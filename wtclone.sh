#!/usr/bin/env bash
# Based on: https://morgan.cugerone.com/blog/workarounds-to-git-worktree-using-bare-repository-and-cannot-fetch-remote-branches/
set -e

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CLEAR="\033[0m"
VERBOSE=

function usage {
    cat <<EOF
Usage: wtclone [-vh] REPO_URL [DIR_NAME]
Clone a repository into a bare worktree layout.

This will:
- create a directory named DIR_NAME (defaults to the repo name)
- clone the repo as a bare repo into .bare
- fetch all branches
- add a worktree for the default branch

FLAGS:
  -h, --help    Print this help
  -v, --verbose Verbose mode
EOF
    kill -INT $$
}

# Parse flags
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

if [ -z "$1" ]; then
    usage
fi

url=$1
basename=${url##*/}
name=${2:-${basename%.*}}

if [ -n "$VERBOSE" ]; then
    set -x
fi

mkdir $name
cd "$name"

# Moves all the administrative git files (a.k.a $GIT_DIR) under .bare directory.
#
# Plan is to create worktrees as siblings of this directory.
# Example targeted structure:
# .bare
# main
# new-awesome-feature
# hotfix-bug-12
# ...
git clone --bare "$url" .bare
echo "gitdir: ./.bare" > .git

# Explicitly sets the remote origin fetch so we can fetch remote branches
git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"

# Gets all branches from origin
git fetch origin

# Add worktree for main branch
main_branch=$(git branch --show-current)
git worktree add "$main_branch"

printf "%bCloned repo to %s%b\n" "$GREEN" "$name" "$CLEAR"

