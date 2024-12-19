#!/usr/bin/env python3

import os
import re
import json
import click
import requests
import subprocess


USER_PROMPT = """I want to update my CHANGELOG.md file following Keep a Changelog format.

Ensure the release notes are appended below previous entries and use the Keep a Changelog format. If the file doesn't exist, create it.

\```
{}
\```

IMPORTANT:
  - Group changes by category (Added, Changed, Deprecated, Removed, Fixed, Security)
  - Each change should be on a separate line
  - Each line should be a concise summary (max 50 characters)
  - Do not include any explanation in your response
  - Do not wrap it in backticks
  - DO NOT, I REPEAT DO NOT, remove or alter previous entries.
  - Append new entries at the end of the file and that's it.
"""

SYSTEM_PROMPT = """You are an AI assistant tasked with maintaining a CHANGELOG.md file for a software project.

The output should meet the following criteria:

If the file already exists, append the new release notes under the existing entries.

Follow the Keep a Changelog format strictly:
- Provide a "## [Unreleased]" section if not already present for future updates.
- Use a "## [Version Number] - YYYY-MM-DD" header for the new release.
- Organize entries into the following categories if applicable: Added, Changed, Deprecated, Removed, Fixed, Security.

If the file does not exist, initialize it with:

\```
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

\```

Example for a new release:

\```markdown
## [1.2.0] - 2024-12-01
### Added
- Added support for user authentication.

### Fixed
- Fixed an issue with pagination on the main feed.
\```

IMPORTANT:
- Ensure entries are clear, concise, and accurately categorized.
- Provide the final CHANGELOG.md file as your response.
- Do not wrap it in backticks
- Return the entire file, old and new entries included.
- Keep all existing entries intact.
- DO NOT, I REPEAT DO NOT, remove or alter previous entries.

Here is the current changelog:
\```
{}
\```
"""

@click.command()
@click.option('--debug', is_flag=True, help='Enable debug logging.')
@click.option('--model', default='google/gemini-flash-1.5-8b', help='Select AI model.')
@click.option('--changelog-filename', default='CHANGELOG.md', help='Filename of the changelog.')
@click.option('--system-prompt', default=None, help='Override system prompt.')
@click.option('--user-prompt', default=None, help='Override user prompt.')
def main(debug, model, changelog_filename, system_prompt, user_prompt):
    def debug_log(message, content=None):
        if debug:
            click.echo(f"DEBUG: {message}")
            if content:
                click.echo(f"DEBUG: Content >>>\n{content}\nDEBUG: <<<")

    debug_log("Script started")
    debug_log(f"MODEL={model}")
    debug_log(f"CHANGELOG_FILENAME={changelog_filename}")

    if not is_git_repository():
        click.echo("ERROR: Not in a git repository", err=True)
        return

    if is_changelog_staged(changelog_filename):
        click.echo(f"INFO: Skipping {changelog_filename} update")
        return

    changes = get_git_diff()
    if not changes:
        click.echo("INFO: No staged changes found. Please stage your changes using 'git add' first.")
        return

    current_changelog = read_file(changelog_filename) if os.path.isfile(changelog_filename) else ""

    user_prompt = USER_PROMPT.format(changes)
    system_prompt = SYSTEM_PROMPT.format(current_changelog)

    api_key = os.getenv("OPENROUTER_API_KEY")
    if not api_key:
        click.echo("ERROR: No API key found. Please provide the OpenRouter API key as an argument or set the OPENROUTER_API_KEY environment variable.", err=True)
        return
  
    response = make_api_request(model, user_prompt, system_prompt, api_key, debug_log)
    if not response:
        click.echo("ERROR: Failed to generate release notes.", err=True)
        return

    # Extract and clean the commit message
    # First, try to parse the response as JSON and extract the content
    generated_changelog = extract_generated_changelog(response, debug_log)
    if not generated_changelog:
        click.echo("ERROR: Failed to extract release notes from API response.", err=True)
        return

    if not write_file(changelog_filename, generated_changelog):
        click.echo(f"ERROR: Failed to write to {changelog_filename}", err=True)
        return

    click.echo(f"Release notes successfully written to {changelog_filename}")


def is_git_repository():
    try:
        subprocess.run(["git", "rev-parse", "--git-dir"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
        return True
    except subprocess.CalledProcessError:
        return False


def is_changelog_staged(changelog_filename):
    result = subprocess.run(["git", "diff", "--cached", "--name-only", "--", changelog_filename], stdout=subprocess.PIPE)
    return bool(result.stdout.strip())


def get_git_diff():
    result = subprocess.run(["git", "diff", "--cached", "--ignore-all-space"], stdout=subprocess.PIPE)
    return result.stdout.decode("utf-8").strip()


def read_file(filename):
    try:
        with open(filename, "r") as file:
            return file.read()
    except Exception as e:
        return ""


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

def extract_generated_changelog(response, debug_log):
    try:
        generated_changelog = response["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError):
        # If parsing fails, fallback to regex method
        match = re.search(r'"content":"([^"]*)"', response)
        generated_changelog = match.group(1) if match else None

    # Clean the message:
    # 1. Preserve the structure of the commit message
    # 2. Clean up escape sequences
    generated_changelog = re.sub(r'\\n', '\n', generated_changelog)
    generated_changelog = re.sub(r'\\r', '', generated_changelog)
    generated_changelog = re.sub(r'^\s+', '', generated_changelog)
    generated_changelog = re.sub(r'\s+$', '', generated_changelog)
    generated_changelog = re.sub(r'\\[a-zA-Z]+', '', generated_changelog)
    generated_changelog = debug_log("Extracted relevant notes", generated_changelog)
    return generated_changelog


if __name__ == "__main__":
    main()
