# Define the repository URL and the destination directory
REPO_URL="https://github.com/tomups/worktrees-scripts.git"
DEST_DIR="$HOME/.local/bin"

# Create the destination directory if it does not exist
mkdir -p "$DEST_DIR"

# Clone the repository into a temporary directory
TEMP_DIR=$(mktemp -d)
git clone "$REPO_URL" "$TEMP_DIR"

# Copy the specified shell scripts to the destination directory
cp "$TEMP_DIR"/wtadd.sh "$DEST_DIR"
cp "$TEMP_DIR"/wtremove.sh "$DEST_DIR"
cp "$TEMP_DIR"/wtclone.sh "$DEST_DIR"

# Clean up the temporary directory
rm -rf "$TEMP_DIR"

# Add execute permissions to the scripts
chmod +x "$DEST_DIR"/wtadd.sh
chmod +x "$DEST_DIR"/wtremove.sh
chmod +x "$DEST_DIR"/wtclone.sh

# Add git aliases for each script
for script in wtadd.sh wtremove.sh wtclone.sh; do
  script_name=$(basename "$script" .sh)
  git config --global alias.$script_name "!$DEST_DIR/$script"
done

# Notify the user
echo "Shell scripts have been installed and configured as git aliases."
