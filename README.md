# Scripts to help using worktrees with bare repos

More information in <https://www.tomups.com/worktrees>

The commands work from either the parent directory or from inside a worktree.

They can only be used with a repo cloned with `git wtclone`.

## Installing

Run the following command in your terminal to install the scripts and add them as alias to gitconfig:

```bash
bash <(curl -s https://raw.githubusercontent.com/tomups/worktrees-scripts/main/install.sh)
```

## Usage

`git wtclone <remote-url> <destination>`

Clones a repo as bare, and creates a worktree for the main branch. If destination is omitted, it will be created in a folder with the same name as the repo, in the current directory.

`git wtadd <worktree-name> <branch>`

Adds a worktree to the current repo, with the specified name and branch. If the branch is omitted, it will be created from the current branch.

This will also copy some untracked files, like node_modules and .env for convenience. If you are in OSX or FreeBSD it will use Copy on Write to save space.

`git wtremove <worktree-name>`

Will remove the worktree, prune it and delete its associated branch.

`git wtlist`

Lists all git worktrees in the current repository with their respective branch information.
