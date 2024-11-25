#!/bin/bash

CONFIG_DIR="$HOME/.config/git-commit-ai"
CONFIG_FILE="$CONFIG_DIR/config"

# Debug mode flag
DEBUG=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --debug)
            DEBUG=true
            shift
            ;;
        *)
            API_KEY_ARG="$1"
            shift
            ;;
    esac
done

# Debug function
debug_log() {
    if [ "$DEBUG" = true ]; then
        echo "DEBUG: $1"
        if [ ! -z "$2" ]; then
            echo "DEBUG: Content >>>"
            echo "$2"
            echo "DEBUG: <<<"
        fi
    fi
}

debug_log "Script started"
debug_log "Config directory: $CONFIG_DIR"

# Create config directory if it doesn't exist
mkdir -p "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR"
debug_log "Config directory created/checked"

# Function to save API key
save_api_key() {
    echo "$1" > "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
    debug_log "API key saved to config file"
}

# Function to get API key
get_api_key() {
    if [ -f "$CONFIG_FILE" ]; then
        cat "$CONFIG_FILE"
    else
        echo ""
    fi
}

# Check if API key is provided as argument or exists in config
if [ ! -z "$API_KEY_ARG" ]; then
    debug_log "New API key provided as argument"
    save_api_key "$API_KEY_ARG"
fi

API_KEY=$(get_api_key)
debug_log "API key retrieved from config"

if [ -z "$API_KEY" ]; then
    echo "No API key found. Please provide the OpenRouter API key as an argument"
    echo "Usage: ./git-commit.sh [--debug] <api_key>"
    exit 1
fi

# Stage all changes
debug_log "Staging all changes"
git add .

# Get git changes
CHANGES=$(git diff --cached --name-status)
debug_log "Git changes detected" "$CHANGES"

if [ -z "$CHANGES" ]; then
    echo "No staged changes found. Please stage your changes using 'git add' first."
    exit 1
fi

# Prepare the request body
REQUEST_BODY=$(cat <<EOF
{
  "stream": false,
  "model": "google/gemini-flash-1.5-8b",
  "messages": [
    {
      "role": "user",
      "content": "Generate a commit message in conventional commit standard format based on the following file changes:\n\`\`\`\n${CHANGES}\n\`\`\`\n- IMPORTANT: Do not include any explanation in your response, only return a commit message content"
    }
  ]
}
EOF
)
debug_log "Request body prepared" "$REQUEST_BODY"

# Make the API request
debug_log "Making API request to OpenRouter"
RESPONSE=$(curl -s -X POST "https://openrouter.ai/api/v1/chat/completions" \
    -H "Authorization: Bearer ${API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$REQUEST_BODY")
debug_log "API response received" "$RESPONSE"

# Extract commit message from response
COMMIT_MESSAGE=$(echo "$RESPONSE" | grep -o '"content":"[^"]*"' | cut -d'"' -f4)
debug_log "Extracted commit message" "$COMMIT_MESSAGE"

if [ -z "$COMMIT_MESSAGE" ]; then
    echo "Failed to generate commit message. API response:"
    echo "$RESPONSE"
    exit 1
fi

# Execute git commit
debug_log "Executing git commit"
git commit -m "$COMMIT_MESSAGE"

if [ $? -ne 0 ]; then
    echo "Failed to commit changes"
    exit 1
fi

# Push to origin
debug_log "Pushing to origin"
git push origin

if [ $? -ne 0 ]; then
    echo "Failed to push changes"
    exit 1
fi

echo "Successfully committed and pushed changes with message:"
echo "$COMMIT_MESSAGE"
debug_log "Script completed successfully" 