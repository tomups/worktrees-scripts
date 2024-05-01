#!/usr/bin/env bash
# Based on: https://morgan.cugerone.com/blog/workarounds-to-git-worktree-using-bare-repository-and-cannot-fetch-remote-branches/
set -e

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CLEAR="\033[0m"

# Examples of call:
# git-clone-bare-for-worktrees git@github.com:name/repo.git
# => Clones to a /repo directory
#
# git-clone-bare-for-worktrees git@github.com:name/repo.git my-repo
# => Clones to a /my-repo directory

url=$1
basename=${url##*/}
name=${2:-${basename%.*}}

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

