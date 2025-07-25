# Define scripts to work with
SCRIPTS=("wtadd.sh" "wtremove.sh" "wtclone.sh" "wtlist.sh")

# Define the repository URL and the destination directory
REPO_URL="https://github.com/tomups/worktrees-scripts.git"
DEST_DIR="$HOME/.local/bin"

# Create the destination directory if it does not exist
mkdir -p "$DEST_DIR"

# Clone the repository into a temporary directory
TEMP_DIR=$(mktemp -d)
git clone "$REPO_URL" "$TEMP_DIR"

for script in "${SCRIPTS[@]}"; do
  # Copy the specified shell scripts to the destination directory
  cp "$TEMP_DIR/$script" "$DEST_DIR"

  # Add execute permissions to the scripts
  chmod +x "$DEST_DIR/$script"

  # Add git aliases for each script
  script_name=$(basename "$script" .sh)
  git config --global alias."$script_name" "!$DEST_DIR/$script"
done

# Clean up the temporary directory
rm -rf "$TEMP_DIR"

# Notify the user
echo "Shell scripts have been installed and configured as git aliases."
