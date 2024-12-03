#!/usr/bin/env bash

set -euo pipefail

# Debug mode flag
DEBUG=false
# Model selection
MODEL="google/gemini-flash-1.5-8b"

CHANGELOG_FILENAME="CHANGELOG.md"

USER_PROMPT=$(cat <<EOF
I want to update my CHANGELOG.md file following Keep a Changelog format.

Ensure the release notes are appended below previous entries and use the Keep a Changelog format. If the file doesn't exist, create it.

\`\`\`
%s
\`\`\`

IMPORTANT:
  - Group changes by category (Added, Changed, Deprecated, Removed, Fixed, Security)
  - Each change should be on a separate line
  - Each line should be a concise summary (max 50 characters)
  - Do not include any explanation in your response
  - Do not wrap it in backticks
  - DO NOT, I REPEAT DO NOT, remove or alter previous entries.
  - Append new entries at the end of the file and that's it.
EOF
)

SYSTEM_PROMPT=$(cat <<EOF
You are an AI assistant tasked with maintaining a CHANGELOG.md file for a software project.

The output should meet the following criteria:

If the file already exists, append the new release notes under the existing entries.

Follow the Keep a Changelog format strictly:
- Provide a "## [Unreleased]" section if not already present for future updates.
- Use a "## [Version Number] - YYYY-MM-DD" header for the new release.
- Organize entries into the following categories if applicable: Added, Changed, Deprecated, Removed, Fixed, Security.

If the file does not exist, initialize it with:

\`\`\`markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

\`\`\`

Example for a new release:

\`\`\`markdown
## [1.2.0] - 2024-12-01
### Added
- Added support for user authentication.

### Fixed
- Fixed an issue with pagination on the main feed.
\`\`\`

IMPORTANT:
- Ensure entries are clear, concise, and accurately categorized.
- Provide the final CHANGELOG.md file as your response.
- Do not wrap it in backticks
- Return the entire file, old and new entries included.
- Keep all existing entries intact.
- DO NOT, I REPEAT DO NOT, remove or alter previous entries.

Here is output from \`git diff --cached\`:

\`\`\`
%s
\`\`\`
EOF
)

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --debug                Enable debug logging
  --model <name>         Select AI model (default: google/gemini-flash-1.5-8b)
  --system-prompt <text> Override system prompt
  --user-prompt <text>   Override user prompt
  -h, --help             Show this help message
EOF
            exit 0
            ;;
        --debug)
            DEBUG=true
            shift
            ;;
        --model)
            # Check if next argument exists and doesn't start with -
            if [[ -n "$2" && "$2" != -* ]]; then
                MODEL="$2"
                shift 2
            else
                echo "Error: --model requires a valid model name"
                exit 1
            fi
            ;;
        --changelog-filename)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "Error: --changelog-filename requires a valid filename"
                exit 1
            fi
            CHANGELOG_FILENAME="$2"
            shift 2
            ;;
        --system-prompt)
            SYSTEM_PROMPT="$2"
            shift 2
            ;;
        --user-prompt)
            USER_PROMPT="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Debug function
debug_log() {
    if [ "$DEBUG" = true ]; then
        echo "DEBUG: $1"
        if [ "${2:-}" ]; then
            echo "DEBUG: Content >>>"
            echo "$2"
            echo "DEBUG: <<<"
        fi
    fi
}

debug_log "Script started"
debug_log "MODEL=$MODEL"
debug_log "CHANGELOG_FILENAME=${CHANGELOG_FILENAME}"

# Verify git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "ERROR: Not in a git repository"
    exit 1
fi

if [ -n "$(git diff --cached --name-only -- "${CHANGELOG_FILENAME}")" ]; then
    echo "INFO: Skipping ${CHANGELOG_FILENAME} update"
    exit 0
fi

# Get git changes
CHANGES=$(git diff --cached)
CURRENT_CHANGELOG=""
if [ -f "${CHANGELOG_FILENAME}" ]; then
    CURRENT_CHANGELOG=$(cat "${CHANGELOG_FILENAME}")
fi

# # Maximum size of changes to send to API (in bytes)
# MAX_CHANGES_SIZE=10000
#
# if [ "${#CHANGES}" -gt "$MAX_CHANGES_SIZE" ]; then
#     CHANGES=$(echo "$CHANGES" | head -c "$MAX_CHANGES_SIZE")
#     CHANGES+=$'\n... (truncated due to size)'
# fi

# shellcheck disable=SC2059
USER_PROMPT=$(printf "$USER_PROMPT" "$CHANGES")
USER_PROMPT=$(echo "$USER_PROMPT" | jq -Rsa .)

# shellcheck disable=SC2059
SYSTEM_PROMPT=$(printf "$SYSTEM_PROMPT" "$CURRENT_CHANGELOG")
SYSTEM_PROMPT=$(echo "$SYSTEM_PROMPT" | jq -Rsa .)


if [ -z "$CHANGES" ]; then
    echo "INFO: No staged changes found. Please stage your changes using 'git add' first."
    exit 0
fi


if [ -z "$OPENROUTER_API_KEY" ]; then
    echo "ERROR: No API key found. Please provide the OpenRouter API key as an argument or set OPENROUTER_API_KEY environment variable."
    exit 1
fi

# Prepare the request body
REQUEST_BODY=$(jq -n \
    --arg model "$MODEL" \
    --arg prompt "$USER_PROMPT" \
    --arg system "$SYSTEM_PROMPT" \
    '{
        stream: false,
        model: $model,
        messages: [
            {role: "user", content: $prompt},
            {role: "system", content: $system}
        ]
    }'
)
debug_log "Request body prepared with model: $MODEL" "$REQUEST_BODY"

# Make the API request
debug_log "Making API request to OpenRouter"
RESPONSE=$(curl -s -X POST "https://openrouter.ai/api/v1/chat/completions" \
    -H "Authorization: Bearer ${OPENROUTER_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$REQUEST_BODY")
debug_log "API response received" "$RESPONSE"

# Check for errors
if [[ "$RESPONSE" == *'"error"'* ]]; then
    error_message=$(echo "$RESPONSE" | jq -r '.error.message // .error // "Unknown error"')
    echo "ERROR: API request failed: $error_message"
    exit 1
fi

# Extract and clean the commit message
# First, try to parse the response as JSON and extract the content
GENERATED_CHANGELOG=$(echo "$RESPONSE" | jq -r '.choices[0].message.content')

# If jq fails or returns null, fallback to grep method
if [ -z "$GENERATED_CHANGELOG" ] || [ "$GENERATED_CHANGELOG" = "null" ]; then
    GENERATED_CHANGELOG=$(echo "$RESPONSE" | grep -o '"content":"[^"]*"' | cut -d'"' -f4)
fi

# Clean the message:
# 1. Preserve the structure of the commit message
# 2. Clean up escape sequences
GENERATED_CHANGELOG=$(echo "$GENERATED_CHANGELOG" | \
    sed 's/\\n/\n/g' | \
    sed 's/\\r//g' | \
    sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | \
    sed 's/\\[[:alpha:]]//g')

debug_log "Extracted relevant notes" "$GENERATED_CHANGELOG"

if [ -z "$GENERATED_CHANGELOG" ]; then
    echo "Failed to generate release notes. API response:"
    echo "$RESPONSE"
    exit 1
fi

# Write the commit message to .git/COMMIT_EDITMSG
debug_log "Writing release notes to $(realpath "$CHANGELOG_FILENAME")"
if ! echo "$GENERATED_CHANGELOG" > "$CHANGELOG_FILENAME"; then
    echo "ERROR: Failed to write commit message to $CHANGELOG_FILENAME"
    exit 1
fi
