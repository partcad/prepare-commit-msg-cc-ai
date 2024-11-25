# Commit Message AI Generator

A command-line tool that automatically generates conventional commit messages using AI, based on your staged git changes.

## Features

- 🤖 AI-powered commit message generation
- 📝 Follows [Conventional Commits](https://www.conventionalcommits.org/) format
- 🔒 Secure local API key storage
- 🚀 Automatic git commit and push
- 🐛 Debug mode for troubleshooting

## Prerequisites

- Git installed and configured
- Bash shell environment
- An [OpenRouter](https://openrouter.ai/) API key
- `curl` installed

## Installation

1. Clone this repository: 

```bash
git clone https://github.com/yourusername/commit-message-ai.git
cd commit-message-ai
```

2. Run the installation script:

```bash
./install.sh
```

This will:
- Create necessary directories
- Install the script globally as `cmai`
- Set up proper permissions

## Configuration

Set up your OpenRouter API key:

```bash
cmai <your_openrouter_api_key>
```

The API key will be securely stored in `~/.config/git-commit-ai/config`

## Usage

1. Make your code changes
2. Generate commit message and push:

```bash
cmai
```

This will:
- Stage all changes
- Generate a commit message using AI
- Commit the changes
- Push to the remote repository

### Debug Mode

To see detailed information about what's happening:

```bash
cmai --debug
```

## Examples

```bash
# First time setup with API key
cmai your_openrouter_api_key

# Normal usage
cmai

# Debug mode
cmai --debug
```

Example generated commit messages:
- `feat: add user authentication system`
- `fix: resolve memory leak in data processing`
- `docs: update API documentation`
- `style: improve responsive layout for mobile devices`

## Directory Structure

```
~
├── git-commit-ai/
│ └── git-commit.sh
├── .config/
│ └── git-commit-ai/
│ └── config
└── usr/
└── local/
└── bin/
└── cmai -> ~/git-commit-ai/git-commit.sh
```

## Security

- API key is stored locally with restricted permissions (600)
- Configuration directory is protected (700)
- No data is stored or logged except the API key
- All communication is done via HTTPS

## Troubleshooting

1. **No API key found**
   - Run `cmai your_openrouter_api_key` to configure

2. **Permission denied**
   - Check file permissions: `ls -la ~/.config/git-commit-ai`
   - Should show: `drwx------` for directory and `-rw-------` for config file

3. **Debug mode**
   - Run with `--debug` flag to see detailed logs
   - Check API responses and git operations

## Uninstallation

```bash
bash
sudo rm /usr/local/bin/cmai
rm -rf ~/git-commit-ai
rm -rf ~/.config/git-commit-ai
```

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes (using `cmai` 😉)
4. Push to the branch
5. Create a Pull Request

## License

MIT License - see LICENSE file for details

## Acknowledgments

- [OpenRouter](https://openrouter.ai/) for providing the AI API
- [Conventional Commits](https://www.conventionalcommits.org/) for the commit message format