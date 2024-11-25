#!/bin/bash

# Detect OS
OS="unknown"
case "$(uname)" in
    "Darwin")
        OS="macos"
        ;;
    "Linux")
        OS="linux"
        ;;
    "MINGW"*|"MSYS"*|"CYGWIN"*)
        OS="windows"
        ;;
esac

# Configuration
SCRIPT_NAME="git-commit.sh"
if [ "$OS" = "windows" ]; then
    SCRIPT_DIR="$USERPROFILE/git-commit-ai"
    EXECUTABLE_NAME="cmai.sh"
else
    SCRIPT_DIR="$HOME/git-commit-ai"
    EXECUTABLE_NAME="cmai"
fi
CONFIG_DIR="${HOME:-$USERPROFILE}/.config/git-commit-ai"

# Debug function
debug_log() {
    echo "Install Script > $1"
}

# Check if script is being run with sudo (skip on Windows)
if [ "$OS" != "windows" ] && [ "$EUID" -eq 0 ]; then
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

# Handle executable installation
if [ "$OS" = "windows" ]; then
    # On Windows, we rely on PATH
    cp "$SCRIPT_DIR/$SCRIPT_NAME" "$SCRIPT_DIR/$EXECUTABLE_NAME"
else
    # Create symbolic link on Unix systems
    debug_log "Creating symbolic link"
    sudo ln -sf "$SCRIPT_DIR/$SCRIPT_NAME" "/usr/local/bin/$EXECUTABLE_NAME"
fi

# Ensure config directory exists
debug_log "Ensuring config directory exists"
mkdir -p "$CONFIG_DIR"
if [ "$OS" != "windows" ]; then
    chmod 700 "$CONFIG_DIR"
fi

# Add instructions for API key
echo "Installation complete!"
echo "To set up your OpenRouter API key, run:"
echo "cmai <your_openrouter_api_key>"
echo ""
echo "Usage:"
echo "- Stage your git changes"
echo "- Run 'cmai' to generate a commit message"
