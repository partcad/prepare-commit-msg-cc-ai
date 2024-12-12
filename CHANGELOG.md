# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

## [1.0.0] - 2024-12-01

### Added

- Added `keep-a-changelog` pre-commit hook for CHANGELOG.md updates.
- Added `pre-commit` hook for commit message generation.

## [1.0.1] - 2024-12-01

### Changed

- Updated project description and README.
- Changed contributing documentation to reflect the new project name.
- Adjusted installation guidance.
- Updated example hooks.
- Updated prerequisites and installation instructions.

## [1.1.0] - 2024-12-01

### Changed

- Improved commit message generation.
- Enhanced pre-commit hook functionality.
- Updated documentation for clarity.

### Added

- Added support for configuring the output directory.
- Included instructions for configuring the hook.

### Fixed

- Resolved an issue with hook execution.
- Corrected a typo in the configuration file.

## [1.2.0] - 2024-12-01

### Changed

- Updated pre-commit dependency to v1.1.0.
- Updated example usage and configuration information.
- Enhanced README with additional guides.

### Fixed

- Resolved potential conflict with keep-a-changelog.sh handling.
- Corrected a minor syntax error in the pre-commit configuration.

## [1.3.0] - 2024-12-01

### Changed

- Updated Discord link in CONTRIBUTING.md and README.md.

## [1.4.0] - 2024-12-02

### Changed

- Updated `pre-commit-hooks.yaml` to change the language of `Git Commit AI` and `Changelog AI` hooks to `script`.

## [1.5.0] - 2024-12-02

### Changed

- Added fail_fast flag to Changelog AI hook.

## [1.6.0] - 2024-12-02

### Changed

- Enable passing filenames to commit-msg hook

## [1.7.0] - 2024-12-02

### Fixed

- jq: Argument list too long #3
- Cleaned up temporary files after API call.

## [1.7.1] - 2024-12-02

### Fixed

- prepare-commit-msg.sh: line 237: /usr/bin/curl: Argument list too long

## [1.8.0] - 2024-12-12

### Fixed

- Fixed `git diff` command to ignore whitespace.

### Changed

- Added `postCreateCommand` to `devcontainer.json` for `pre-commit` installation.
- Modified `keep-a-changelog.sh` to use `git diff --cached --ignore-all-space` to reduce API call size.
- Modified `prepare-commit-msg.sh` to handle whitespace discrepancies with `git diff --cached --ignore-all-space`.
- Use temporary files to store user and system prompts.
- Added cleanup for temp files on script exit in keep-a-changelog.sh and prepare-commit-msg.sh.
- Renamed "Changelog AI" hooks to "PartCAD: Update CHANGELOG.md"
- Renamed "Git Commit AI" hooks to "PartCAD: Prepare Commit Message"
- Improved cleanup mechanism for temporary files

## [1.8.1] - 2024-12-12

### Added

- Added $REQUEST_BODY_FILE for curl request and cleanup.
- Secure permissions on temporary files - `chmod 600`.

## [1.8.2] - 2024-12-12

### Changed

- Added transforms for improved results.
- Modified `keep-a-changelog.sh` and `prepare-commit-msg.sh` for better results.

## [1.8.3] - 2024-12-12

- Added filtering for `.stl` and `.step` files in `git diff` to avoid 5xx errors in API requests.
- Improved error handling and logging (potential debugging improvements).
- Added `--fail` option to curl requests.
- Added examples of API costs.
