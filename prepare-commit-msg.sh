#!/usr/bin/env bash

set -euo pipefail

# Debug mode flag
DEBUG=false
# Model selection
MODEL="google/gemini-flash-1.5-8b"
# Either send patch or only filenames
OPEN_SOURCE=false

USER_PROMPT=$(cat <<EOF
Generate a commit message based on the following changes below:

\`\`\`
%s
\`\`\`

IMPORTANT

  - Follow conventional commit format
  - First line should be a concise summary (max 50 characters)
  - Do not include any explanation in your response
  - Only return a commit message content
  - Do not wrap it in backticks
  - One change per line.
  - All lines should be a concise summary (max 80 characters)
EOF
)

SYSTEM_PROMPT=$(cat <<EOF
Provide a detailed commit message with a title and description.
The title should be a concise summary (max 50 characters).
The description should provide more context about the changes,
explaining why the changes were made and their impact.
Use bullet points if multiple changes are significant.

SPECIFICATION

The key words MUST, MUST NOT, REQUIRED, SHALL, SHALL NOT, SHOULD, SHOULD NOT, RECOMMENDED, MAY, and OPTIONAL in this document are to be interpreted as described in RFC 2119.

- Commits MUST be prefixed with a type, which consists of a noun, feat, fix, etc., followed by the OPTIONAL scope, OPTIONAL !, and REQUIRED terminal colon and space.
- The type feat MUST be used when a commit adds a new feature to your application or library.
- The type fix MUST be used when a commit represents a bug fix for your application.
- A scope MAY be provided after a type. A scope MUST consist of a noun describing a section of the codebase surrounded by parenthesis, e.g., fix(parser):
- A description MUST immediately follow the colon and space after the type/scope prefix. The description is a short summary of the code changes, e.g., fix: array parsing issue when multiple spaces were contained in string.
- A longer commit body MAY be provided after the short description, providing additional contextual information about the code changes. The body MUST begin one blank line after the description.
- A commit body is free-form and MAY consist of any number of newline separated paragraphs.
- One or more footers MAY be provided one blank line after the body. Each footer MUST consist of a word token, followed by either a :<space> or <space># separator, followed by a string value (this is inspired by the git trailer convention).
- A footer's token MUST use - in place of whitespace characters, e.g., Acked-by (this helps differentiate the footer section from a multi-paragraph body). An exception is made for BREAKING CHANGE, which MAY also be used as a token.
- A footer's value MAY contain spaces and newlines, and parsing MUST terminate when the next valid footer token/separator pair is observed.
- Breaking changes MUST be indicated in the type/scope prefix of a commit, or as an entry in the footer.
- If included as a footer, a breaking change MUST consist of the uppercase text BREAKING CHANGE, followed by a colon, space, and description, e.g., BREAKING CHANGE: environment variables now take precedence over config files.
- If included in the type/scope prefix, breaking changes MUST be indicated by a ! immediately before the :. If ! is used, BREAKING CHANGE: MAY be omitted from the footer section, and the commit description SHALL be used to describe the breaking change.
- Types other than feat and fix MAY be used in your commit messages, e.g., docs: update ref docs.
- The units of information that make up Conventional Commits MUST NOT be treated as case sensitive by implementors, with the exception of BREAKING CHANGE which MUST be uppercase.
- BREAKING-CHANGE MUST be synonymous with BREAKING CHANGE, when used as a token in a footer.

EXAMPLES

Commit message with description and breaking change footer:

  feat: allow provided config object to extend other configs
  BREAKING CHANGE: 'extends' key in config file is now used for extending other config files

Commit message with ! to draw attention to breaking change:

  feat!: send an email to the customer when a product is shipped

Commit message with scope and ! to draw attention to breaking change:

  feat(api)!: send an email to the customer when a product is shipped

Commit message with both ! and BREAKING CHANGE footer:

  chore!: drop support for Node 6
  BREAKING CHANGE: use JavaScript features not available in Node 6.

Commit message with no body:

  docs: correct spelling of CHANGELOG

Commit message with scope:

  feat(lang): add Polish language

Commit message with multi-paragraph body and multiple footers:

  fix: prevent racing of requests

  Introduce a request id and a reference to latest request. Dismiss
  incoming responses other than from latest request.

  Remove timeouts which were used to mitigate the racing issue but are
  obsolete now.
EOF
)

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            cat <<EOF
Usage: $0 [OPTIONS] --commit-msg-filename <file>

Options:
  --debug                Enable debug logging
  --model <name>         Select AI model (default: google/gemini-flash-1.5-8b)
  --open-source          Send complete diff instead of just filenames
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
        --commit-msg-filename)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "Error: --commit-msg-filename requires a valid filename"
                exit 1
            fi
            COMMIT_MSG_FILENAME="$2"
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
        --open-source)
            OPEN_SOURCE=true
            shift 1
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

debug_log "MODEL=$MODEL"
debug_log "COMMIT_MSG_FILENAME=${COMMIT_MSG_FILENAME}"

# Verify git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "ERROR: Not in a git repository"
    exit 1
fi

# Get git changes
if [ "$OPEN_SOURCE" = true ]; then
    CHANGES=$(git diff --cached --ignore-all-space -- ':!*.stl' ':!*.step')
else
    CHANGES=$(git diff --cached --ignore-all-space --name-status -- ':!*.stl' ':!*.step')
fi


# # Maximum size of changes to send to API (in bytes)
# MAX_CHANGES_SIZE=10000
#
# if [ "${#CHANGES}" -gt "$MAX_CHANGES_SIZE" ]; then
#     CHANGES=$(echo "$CHANGES" | head -c "$MAX_CHANGES_SIZE")
#     CHANGES+=$'\n... (truncated due to size)'
# fi

# shellcheck disable=SC2059
PROMPT=$(printf "$USER_PROMPT" "$CHANGES")
PROMPT=$(echo "$PROMPT" | jq -Rsa .)

if [ -z "$CHANGES" ]; then
    echo "INFO: No staged changes found. Please stage your changes using 'git add' first."
    exit 0
fi

debug_log "Script started"

if [ -z "$OPENROUTER_API_KEY" ]; then
    echo "ERROR: No API key found. Please provide the OpenRouter API key as an argument or set OPENROUTER_API_KEY environment variable."
    exit 1
fi

PROMPT_FILE=$(mktemp)
echo "$PROMPT" > "$PROMPT_FILE"
debug_log "Prompt saved to $PROMPT_FILE"

SYSTEM_PROMPT_FILE=$(mktemp)
echo "$SYSTEM_PROMPT" > "$SYSTEM_PROMPT_FILE"
debug_log "System prompt saved to $SYSTEM_PROMPT_FILE"

# Ensure cleanup on script exit
cleanup() {
    local exit_code=$?
    rm -f "$PROMPT_FILE" "$SYSTEM_PROMPT_FILE" "$REQUEST_BODY_FILE" 2>/dev/null
    exit $exit_code
}
trap cleanup EXIT INT TERM

# Prepare the request body
REQUEST_BODY=$(jq -n \
    --arg model "$MODEL" \
    --rawfile prompt "$PROMPT_FILE" \
    --rawfile system "$SYSTEM_PROMPT_FILE" \
    '{
        stream: false,
        model: $model,
        transforms: ["middle-out"],
        messages: [
            {role: "user", content: $prompt},
            {role: "system", content: $system}
        ]
    }'
)
debug_log "Request body prepared with model: $MODEL" "$REQUEST_BODY"
debug_log "Cleaning up temporary files"
rm -v "$PROMPT_FILE" "$SYSTEM_PROMPT_FILE"

REQUEST_BODY_FILE=$(mktemp)
if [ ! -f "$REQUEST_BODY_FILE" ]; then
    echo "ERROR: Failed to create temporary file"
    exit 1
fi
chmod 600 "$REQUEST_BODY_FILE" || {
    echo "ERROR: Failed to set secure permissions on temporary file"
    rm -f "$REQUEST_BODY_FILE"
    exit 1
}
echo "$REQUEST_BODY" > "$REQUEST_BODY_FILE"
debug_log "Request body saved to $REQUEST_BODY_FILE"

# Make the API request
debug_log "Making API request to OpenRouter"
if ! RESPONSE=$(curl -s -X POST "https://openrouter.ai/api/v1/chat/completions" \
    -H "Authorization: Bearer ${OPENROUTER_API_KEY}" \
    -H "Content-Type: application/json" \
    -d @"$REQUEST_BODY_FILE"); then
    echo "ERROR: API request failed with exit code $?"
    exit 1
fi
debug_log "API response received" "$RESPONSE"
debug_log "Cleaning up temporary files"
rm -v "$REQUEST_BODY_FILE"

# Check for errors
if [[ "$RESPONSE" == *'"error"'* ]]; then
    error_message=$(echo "$RESPONSE" | jq -r '.error.message // .error // "Unknown error"')
    echo "ERROR: API request failed: $error_message"
    exit 1
fi

# Extract and clean the commit message
# First, try to parse the response as JSON and extract the content
COMMIT_FULL=$(echo "$RESPONSE" | jq -r '.choices[0].message.content')

# If jq fails or returns null, fallback to grep method
if [ -z "$COMMIT_FULL" ] || [ "$COMMIT_FULL" = "null" ]; then
    COMMIT_FULL=$(echo "$RESPONSE" | grep -o '"content":"[^"]*"' | cut -d'"' -f4)
fi

# Validate commit message format
validate_commit_message() {
    local message="$1"
    # Check if message follows conventional commit format
    if ! echo "$message" | grep -qE '^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?: .+'; then
        return 1
    fi
    return 0
}

# Clean the message:
# 1. Preserve the structure of the commit message
# 2. Clean up escape sequences
COMMIT_FULL=$(echo "$COMMIT_FULL" | \
    sed 's/\\n/\n/g' | \
    sed 's/\\r//g' | \
    sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | \
    sed 's/\\[[:alpha:]]//g')

debug_log "Extracted commit message" "$COMMIT_FULL"

if ! validate_commit_message "$COMMIT_FULL"; then
    echo "ERROR: Generated message does not follow conventional commit format"
    echo "Message: $COMMIT_FULL"
    exit 1
fi

if [ -z "$COMMIT_FULL" ]; then
    echo "Failed to generate commit message. API response:"
    echo "$RESPONSE"
    exit 1
fi

debug_log "$COMMIT_FULL"

# Write the commit message to .git/COMMIT_EDITMSG
debug_log "Writing commit message to $(realpath "$COMMIT_MSG_FILENAME")"
if ! echo "$COMMIT_FULL" > "$COMMIT_MSG_FILENAME"; then
    echo "ERROR: Failed to write commit message to $COMMIT_MSG_FILENAME"
    exit 1
fi
