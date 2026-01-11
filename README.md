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

`git wtclone <remote-url> [destination]`

Clone a repository into a bare worktree layout.

This will:
- create a directory named destination (defaults to the repo name)
- clone the repo as a bare repo into `.bare`
- fetch all branches
- add a worktree for the default branch

`git wtadd <worktree-name> [-b branch]`

Create a git worktree named `worktree-name` based on `branch`. If no branch is provided, it defaults to the current branch.

Also copies over untracked convenience files to the new worktree: `.env`, `.envrc`, `.tool-versions`, `mise.toml`, and the root `node_modules` directory. On macOS or *BSD, Copy-on-Write is used when available to save space.

`git wtremove <worktree-name>`

Remove a worktree, prune it, and delete its associated branch.

`git wtlist`

List all git worktrees in the current repository with their respective branch information.

