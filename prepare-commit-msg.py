#!/usr/bin/env python3

import os
import re
import json
import click
import requests
import subprocess


USER_PROMPT = """Generate a commit message based on the following changes below:

\```
{}
\```

IMPORTANT

  - Follow conventional commit format
  - First line should be a concise summary (max 50 characters)
  - Do not include any explanation in your response
  - Only return a commit message content
  - Do not wrap it in backticks
  - One change per line.
  - All lines should be a concise summary (max 80 characters)
  """

SYSTEM_PROMPT = f"""Provide a detailed commit message with a title and description.
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
    """


@click.command()
@click.option('--debug', is_flag=True, help='Enable debug logging.')
@click.option('--model', default='google/gemini-flash-1.5-8b', help='Select AI model.')
@click.option('--commit-msg-filename', required=True, help='Path to the commit message file.')
@click.option('--open-source', is_flag=True, help='Send complete diff instead of just filenames')
@click.option('--system-prompt', default=None, help='Override system prompt.')
@click.option('--user-prompt', default=None, help='Override user prompt.')
def main(debug, model, commit_msg_filename, open_source, system_prompt, user_prompt):
    def debug_log(message, content=None):
        if debug:
            click.echo(f"DEBUG: {message}")
            if content:
                click.echo(f"DEBUG: Content >>>\n{content}\nDEBUG: <<<")

    debug_log(f"MODEL={model}")
    debug_log(f"COMMIT_MSG_FILENAME={commit_msg_filename}")

    if not is_git_repository():
        click.echo("ERROR: Not in a git repository", err=True)
        return

    debug_log("Getting git changes")
    if open_source:
        changes = subprocess.run(["git", "diff", "--cached", "--ignore-all-space"], stdout=subprocess.PIPE)
    else:
        changes = subprocess.run(["git", "diff", "--cached", "--name-status", "--ignore-all-space"], stdout=subprocess.PIPE)

    if not changes:
        click.echo("INFO: No staged changes found. Please stage your changes using 'git add' first.")
        return
    
    debug_log("Script started")

    api_key = os.getenv("OPENROUTER_API_KEY")
    if not api_key:
        click.echo("ERROR: No API key found. Please provide the OpenRouter API key as an argument or set the OPENROUTER_API_KEY environment variable.", err=True)
        return

    user_prompt = USER_PROMPT.format(changes)
    system_prompt = SYSTEM_PROMPT
  
    response = make_api_request(model, user_prompt, system_prompt, api_key, debug_log)

    debug_log("API response received", response)
    
    # Extract and clean the commit message
    # First, try to parse the response as JSON and extract the content
    commit_full = extract_commit_message(response)
    if not commit_full:
        click.echo("ERROR: Failed to extract commit message from API response.", err=True)
        return

    if not validate_commit_message(commit_full):
        click.echo("ERROR: Generated message does not follow conventional commit format", err=True)

    # Write the commit message to .git/COMMIT_EDITMSG
    debug_log(f"Writing commit message to {os.path.realpath(commit_msg_filename)}")
    if not write_file(commit_msg_filename, commit_full):
        click.echo("ERROR: Failed to write commit message to {}".format(commit_msg_filename), err=True)


def is_git_repository():
    try:
        subprocess.run(["git", "rev-parse", "--git-dir"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
        return True
    except subprocess.CalledProcessError:
        return False


def write_file(filename, content):
    try:
        with open(filename, "w") as file:
            file.write(content)
        return True
    except Exception as e:
        return False


def make_api_request(model, user_prompt, system_prompt, api_key, debug_log):
    url = "https://openrouter.ai/api/v1/chat/completions"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    payload = {
        "stream": False,
        "transforms": ["middle-out"],
        "model": model,
        "messages": [
            {"role": "user", "content": user_prompt},
            {"role": "system", "content": system_prompt},
        ],
    }

    debug_log("Making API request to OpenRouter", json.dumps(payload, indent=2))

    try:
        response = requests.post(url, headers=headers, json=payload)
        response.raise_for_status()
        debug_log("API response received", response.json())
        return response.json()
    except requests.RequestException as e:
        debug_log(f"ERROR: API request failed with error: {e}")
        return None


def extract_commit_message(response, debug_log):
    try:
        commit_full = response["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError):
        # If parsing fails, fallback to regex method
        match = re.search(r'"content":"([^"]*)"', response)
        commit_full = match.group(1) if match else None
    
    # Clean the message:
    # 1. Preserve the structure of the commit message
    # 2. Clean up escape sequences
    commit_full = re.sub(r'\\n', '\n', commit_full)
    commit_full = re.sub(r'\\r', '', commit_full)
    commit_full = re.sub(r'^\s+', '', commit_full)
    commit_full = re.sub(r'\s+$', '', commit_full)
    commit_full = re.sub(r'\\[a-zA-Z]+', '', commit_full)

    debug_log("Extracted commit message ", commit_full)
    
    return commit_full

# Validate commit message format
def validate_commit_message(message):
    # Check if message follows conventional commit format
    pattern = r"^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(.+\))?: .+$"
    if not re.match(pattern, message):
        return False
    return True



if __name__ == "__main__":
    main()
