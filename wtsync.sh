#!/usr/bin/env bash
# Sync untracked files (like .env, node_modules) to existing worktrees

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CLEAR="\033[0m"
VERBOSE=
FORCE=

function usage {
    cat <<EOF
Usage: wtsync [-vfh] [SOURCE_WORKTREE] [TARGET_WORKTREE]
Sync untracked files (.env, .envrc, .tool-versions, mise.toml, node_modules) 
from one worktree to another or to all worktrees.

ARGUMENTS:
  SOURCE_WORKTREE   Source worktree to copy from (default: main or master)
  TARGET_WORKTREE   Target worktree to copy to (default: all worktrees)

FLAGS:
  -f, --force       Overwrite existing files
  -h, --help        Print this help
  -v, --verbose     Verbose mode

EXAMPLES:
  wtsync                           # Sync from main/master to all worktrees
  wtsync main feature-branch       # Sync from main to feature-branch
  wtsync . feature-branch          # Sync from current worktree to feature-branch
  wtsync main                      # Sync from main to all other worktrees

EOF
    kill -INT $$
}

function die {
    printf '%b%s%b\n' "$RED" "$1" "$CLEAR"
    kill -INT $$
}

function warn {
    printf '%b%s%b\n' "$YELLOW" "$1" "$CLEAR"
}

function info {
    printf '%b%s%b\n' "$GREEN" "$1" "$CLEAR"
}

# Copy-on-write function (same as wtadd.sh)
function cp_cow {
    if ! /bin/cp -Rc "$1" "$2" 2>/dev/null; then
        if ! /bin/cp -R --reflink "$1" "$2" 2>/dev/null; then
            if ! /bin/cp -R "$1" "$2" 2>/dev/null; then
                warn "Unable to copy file $1 to $2"
            fi
        fi
    fi
}

# Detect find variant (same as wtadd.sh)
function detect_find_variant {
    if find -E /dev/null -maxdepth 0 >/dev/null 2>&1; then
        echo "bsd"
    elif find /dev/null -maxdepth 0 -regextype posix-extended >/dev/null 2>&1; then
        echo "gnu"
    else
        echo "basic"
    fi
}

# Get list of all worktrees
function get_worktrees {
    git worktree list --porcelain | grep "worktree " | cut -d' ' -f2
}

# Find the main/master worktree
function find_main_worktree {
    local worktrees=($(get_worktrees))
    
    for wt in "${worktrees[@]}"; do
        local branch=$(cd "$wt" && git branch --show-current 2>/dev/null)
        if [[ "$branch" == "main" || "$branch" == "master" ]]; then
            echo "$wt"
            return
        fi
    done
    
    # If no main/master found, return the first worktree
    if [[ ${#worktrees[@]} -gt 0 ]]; then
        echo "${worktrees[0]}"
    fi
}

# Sync files from source to target
function sync_files {
    local source="$1"
    local target="$2"
    
    if [[ ! -d "$source" ]]; then
        die "Source worktree does not exist: $source"
    fi
    
    if [[ ! -d "$target" ]]; then
        die "Target worktree does not exist: $target"
    fi
    
    if [[ "$source" == "$target" ]]; then
        return 0
    fi
    
    if [ -n "$VERBOSE" ]; then
        info "Syncing from $source to $target"
    fi
    
    local files_copied=0
    
    # Copy node_modules if it exists
    if [[ -d "$source/node_modules" ]]; then
        if [[ ! -d "$target/node_modules" || -n "$FORCE" ]]; then
            if [[ -d "$target/node_modules" && -n "$FORCE" ]]; then
                rm -rf "$target/node_modules"
            fi
            cp_cow "$source/node_modules" "$target/node_modules"
            if [[ $? -eq 0 ]]; then
                files_copied=$((files_copied + 1))
                if [ -n "$VERBOSE" ]; then
                    info "  ✓ Copied node_modules"
                fi
            fi
        elif [ -n "$VERBOSE" ]; then
            warn "  ⚠ Skipped existing node_modules (use -f to overwrite)"
        fi
    fi
    
    # Find and copy other untracked files
    local find_variant=$(detect_find_variant)
    local files_to_copy=()
    
    # Set IFS for proper array handling
    IFS=$'\n'
    
    
    case "$find_variant" in
    "bsd")
        files_to_copy=($(find -E "$source" -maxdepth 1 -not -path '*node_modules*' -and \
            -iregex '.*\/\.(envrc|env(\.local)?|tool-versions|mise\.toml)'))
        ;;
    "gnu")
        files_to_copy=($(find "$source" -maxdepth 1 -not -path '*node_modules*' -and \
            -regextype posix-extended -iregex '.*\/\.(envrc|env(\.local)?|tool-versions|mise\.toml)'))
        ;;
    "basic")
        files_to_copy=($(find "$source" -maxdepth 1 -not -path '*node_modules*' \
            \( -name '.envrc' -o -name '.env' -o -name '.env.local' -o -name '.tool-versions' -o -name 'mise.toml' \)))
        ;;
    esac
    
    # Reset IFS
    unset IFS
    
    if [ -n "$VERBOSE" ]; then
        info "  Found ${#files_to_copy[@]} files to potentially copy: ${files_to_copy[*]}"
    fi
    
    for f in "${files_to_copy[@]}"; do
        local filename=$(basename "$f")
        local target_file="$target/$filename"
        
        if [[ ! -f "$target_file" || -n "$FORCE" ]]; then
            cp_cow "$f" "$target_file"
            if [[ $? -eq 0 ]]; then
                files_copied=$((files_copied + 1))
                if [ -n "$VERBOSE" ]; then
                    info "  ✓ Copied $filename"
                fi
            fi
        elif [ -n "$VERBOSE" ]; then
            warn "  ⚠ Skipped existing $filename (use -f to overwrite)"
        fi
    done
    
    # Handle direnv if .envrc was copied
    if [[ -f "$target/.envrc" && $files_copied -gt 0 ]]; then
        if command -v direnv >/dev/null 2>&1; then
            direnv allow "$target"
            if [ -n "$VERBOSE" ]; then
                info "  ✓ Allowed direnv for $target"
            fi
        fi
    fi
    
    if [[ $files_copied -gt 0 ]]; then
        info "Synced $files_copied file(s) to $(basename "$target")"
    elif [ -n "$VERBOSE" ]; then
        warn "No files synced to $(basename "$target")"
    fi
}

function main {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
        -h | --help)
            usage
            ;;
        -v | --verbose)
            VERBOSE=true
            shift
            ;;
        -f | --force)
            FORCE=true
            shift
            ;;
        *)
            break
            ;;
        esac
    done
    
    # Determine source worktree
    local source="$1"
    if [[ -z "$source" ]]; then
        source=$(find_main_worktree)
        if [[ -z "$source" ]]; then
            die "Could not find main/master worktree and no source specified"
        fi
        if [ -n "$VERBOSE" ]; then
            info "Using source: $source"
        fi
    elif [[ "$source" == "." ]]; then
        source=$(pwd)
    elif [[ ! "$source" =~ ^/ ]]; then
        # Convert relative path to absolute
        if [[ -d "$source" ]]; then
            source=$(cd "$source" && pwd)
        else
            die "Source worktree not found: $source"
        fi
    fi
    
    # Determine target worktree(s)
    local target="$2"
    if [[ -n "$target" ]]; then
        # Single target specified
        if [[ "$target" == "." ]]; then
            target=$(pwd)
        elif [[ ! "$target" =~ ^/ ]]; then
            # Convert relative path to absolute
            if [[ -d "$target" ]]; then
                target=$(cd "$target" && pwd)
            else
                die "Target worktree not found: $target"
            fi
        fi
        sync_files "$source" "$target"
    else
        # Sync to all worktrees
        local worktrees=($(get_worktrees))
        local synced=0
        
        for wt in "${worktrees[@]}"; do
            if [[ "$wt" != "$source" ]]; then
                sync_files "$source" "$wt"
                synced=$((synced + 1))
            fi
        done
        
        if [[ $synced -eq 0 ]]; then
            warn "No target worktrees found to sync to"
        fi
    fi
}

main "$@"