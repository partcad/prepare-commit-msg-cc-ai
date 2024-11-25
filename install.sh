#!/bin/bash

# Configuration
SCRIPT_NAME="git-commit.sh"
SCRIPT_DIR="$HOME/git-commit-ai"
EXECUTABLE_NAME="cmai"
CONFIG_DIR="$HOME/.config/git-commit-ai"

# Debug function
debug_log() {
    echo "Install Script > $1"
}

# Check if script is being run with sudo
if [ "$EUID" -eq 0 ]; then
    echo "Please do not run this script with sudo. Run as a regular user."
    exit 1
fi

# Create directory for the script
debug_log "Creating script directory"
mkdir -p "$SCRIPT_DIR"

# Copy the git-commit.sh script to the directory
debug_log "Copying git-commit script"
cp "$(dirname "$0")/$SCRIPT_NAME" "$SCRIPT_DIR/$SCRIPT_NAME"
chmod +x "$SCRIPT_DIR/$SCRIPT_NAME"

# Create symbolic link to make the script executable from anywhere
debug_log "Creating symbolic link"
sudo ln -sf "$SCRIPT_DIR/$SCRIPT_NAME" "/usr/local/bin/$EXECUTABLE_NAME"

# Ensure config directory exists
debug_log "Ensuring config directory exists"
mkdir -p "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR"

# Add instructions for API key
echo "Installation complete!"
echo "To set up your OpenRouter API key, run:"
echo "cmai <your_openrouter_api_key>"
echo ""
echo "Usage:"
echo "- Stage your git changes"
echo "- Run 'cmai' to generate a commit message"
