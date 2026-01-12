# CLAUDE.md - Technical Documentation

This document contains technical knowledge about this dotfiles repository for future maintenance and AI-assisted development.

## Project Overview

This is a cross-platform dotfiles and environment setup repository that supports macOS (Apple Silicon) and Linux (Debian/Ubuntu, RHEL/Fedora). It uses a multi-stage installation process to set up a complete development environment with Docker-based testing for Linux environments.

The repository can be installed with a single command:
```bash
curl -fsSL https://raw.githubusercontent.com/stewartpark/env/main/install.sh | bash
```

This will:
1. Clone the repository to `~/workspace/env`
2. Install Homebrew and all packages
3. Symlink dotfiles using rcm with platform-specific configurations
4. Set up SSH keys and configure GitHub access
5. Optionally clone and unlock secrets repository

## Repository Structure

```
env/
├── home/                           # Dotfiles managed by rcm
│   ├── zprofile                   # Login shell - sets up Homebrew PATH
│   ├── zshrc                      # Interactive shell - prompt, aliases, tools
│   ├── gitconfig                  # Git configuration
│   ├── gitignore_global           # Global gitignore
│   ├── rcrc                       # rcm configuration
│   ├── config/
│   │   ├── mise/
│   │   │   ├── config.toml        # Global mise runtime versions
│   │   │   └── conf.d/            # Additional mise configs
│   │   └── kitty/                 # Kitty terminal config
│   ├── gnupg/                     # GPG configuration (common)
│   │   └── gpg.conf
│   ├── tag-macos/                 # macOS-specific dotfiles
│   │   └── gnupg/
│   │       └── gpg-agent.conf     # macOS GPG agent (pinentry-mac)
│   ├── tag-linux/                 # Linux-specific dotfiles
│   │   └── gnupg/
│   │       └── gpg-agent.conf     # Linux GPG agent (pinentry-curses)
│   ├── ssh/                       # SSH configuration
│   └── claude/                    # Claude Code configuration
├── homebrew/                      # Package definitions
│   ├── Brewfile                   # Common packages (all platforms)
│   ├── Brewfile.macos             # macOS-specific packages
│   └── Brewfile.linux             # Linux-specific packages
├── install.sh                     # Multi-stage installation script
├── test/                          # Test infrastructure
│   ├── Dockerfile.ubuntu          # Ubuntu test environment
│   ├── integration.sh             # Integration test suite
│   └── run.sh                     # Helper to build and run tests
└── CLAUDE.md                      # This file
```

## Key Design Decisions

### Shell Initialization Order

**IMPORTANT**: The shell initialization is split across files:

- **`.zprofile`** (login shell): Sets up Homebrew PATH for all platforms
  - Runs BEFORE `.zshrc`
  - Must be sourced first to make `brew` commands available
  - Handles macOS (Apple Silicon at `/opt/homebrew`) and Linux (`/home/linuxbrew`)

- **`.zshrc`** (interactive shell): Configures shell features, prompt, tools
  - Assumes Homebrew is already in PATH
  - Uses `gpgconf` and `mise` which are installed via Homebrew
  - Must NOT duplicate Homebrew setup (handled in `.zprofile`)

### Brewfile Naming Convention

- Uses standard Homebrew naming: `Brewfile` (NOT `.Brewfile`)
- `.Brewfile` was incorrect - dotfiles are for user configs, not project files
- Platform-specific files use suffix convention: `Brewfile.macos`, `Brewfile.linux`

### Package Management

All packages are managed via Homebrew Bundle:
- `Brewfile` - Common packages (git, gnupg, mise, neovim, etc.)
- `Brewfile.macos` - macOS GUI apps (Kitty, pinentry-mac, fonts)
- `Brewfile.linux` - Linux-specific packages

### Dotfile Management

Uses `rcm` (Thoughtbot's dotfile manager):
- Dotfiles live in `home/` directory
- `rcup` creates symlinks from `~/.zshrc` → `home/zshrc`
- Convention: no leading dots in `home/` directory, rcm adds them
- **Platform-specific configs** use rcm tags:
  - `tag-macos/` - macOS-specific files (installed with `rcup -t macos`)
  - `tag-linux/` - Linux-specific files (installed with `rcup -t linux`)
  - Currently used for GPG agent configuration (different pinentry programs per platform)

## Installation Stages

The `install.sh` script has 4 stages:

### Stage 0: Repository Setup (for curl pipe installation)
- Creates `~/workspace` directory if needed
- Clones repository to `~/workspace/env` (or updates if already exists)
- Uses HTTPS for initial clone (no SSH keys yet)
- Changes to repository directory for remaining stages

### Stage 1: Base Installation
- Install Homebrew (if needed)
- Install packages from Brewfiles
- Symlink dotfiles with rcm using platform-specific tag (`-t macos` or `-t linux`)
- Create required directories (`~/.ssh/sockets`, `~/.local/share/zsh/site-functions`)
- Restart GPG agent to pick up new configuration
- Install mise runtimes (if config exists)
- Generate mise completions

### Stage 2: SSH Key Setup
- Check for existing SSH keys (ed25519 or RSA)
- Generate new key if needed
- Test GitHub authentication
- Interactive prompts for key registration
- **Switch git remote from HTTPS to SSH** for future operations

### Stage 3: Secrets Repository
- Clone `env-secrets` repository (git-crypt encrypted)
- Unlock git-crypt with user's key file
- Import GPG keys
- Set trust levels

### Stage 4: Finalization
- Set zsh as default shell
- Display next steps

## Platform Detection

The install script detects platform using:
- macOS: `$OSTYPE == "darwin"*`
- Debian/Ubuntu: `/etc/debian_version`
- RHEL/Fedora: `/etc/redhat-release`
- Generic Linux: fallback

## Common Tools & Configurations

### SSH Configuration
- Configuration file: `home/ssh/config` (symlinked to `~/.ssh/config`)
- GPG agent integration via `IdentityAgent ~/.gnupg/S.gpg-agent.ssh`
- Automatic key management with `AddKeysToAgent yes`
- macOS Keychain integration via `UseKeychain yes` (ignored on Linux)
- Connection multiplexing for better performance (ControlMaster/ControlPath)
- Keepalive settings prevent connection timeouts

### GPG Setup
- GPG agent provides SSH authentication via `SSH_AUTH_SOCK`
- Platform-specific pinentry programs configured via rcm tags:
  - macOS (Apple Silicon): `pinentry-mac` at `/opt/homebrew/bin/pinentry-mac` (with Keychain integration)
  - Linux: `pinentry-curses` at `/usr/bin/pinentry-curses`
- Configuration files:
  - Common: `home/gnupg/gpg.conf` - strong algorithms, TOFU+PGP trust model
  - macOS-specific: `home/tag-macos/gnupg/gpg-agent.conf`
  - Linux-specific: `home/tag-linux/gnupg/gpg-agent.conf`
- GPG agent features:
  - SSH support enabled for key management
  - Secure PIN entry with keyboard grab
  - Configurable cache timeouts (10min general, 30min SSH)
  - Loopback pinentry for browser extensions
- GPG_TTY is set for proper terminal interaction
- No sed-based file editing needed - rcm tags handle platform differences

### mise (Runtime Manager)
- Replaces asdf/rbenv/nvm/etc.
- Activated in `.zshrc` with `eval "$(mise activate zsh)"`
- Completions generated to `~/.local/share/zsh/site-functions/_mise`
- Global configuration at `home/config/mise/config.toml` (symlinked to `~/.config/mise/config.toml`)
- Current runtimes: node (lts), python (3.12), rust (latest), go (latest), java (21), scala (3), ruby (latest)
- Install script checks for mise config before running `mise install` (supports both global and project-local configs)
- Config can be split across multiple files in `conf.d/` directory

### Zsh Configuration
- Custom prompt with git branch, timestamp, command duration, exit codes
- vcs_info for git integration
- History: 10k lines, shared across sessions, ignores duplicates
- Syntax highlighting loaded at end (must be last)
- Auto-completion enabled via compinit

## Docker Testing

A complete Docker-based testing infrastructure validates the Linux installation:

### Test Environment
- **Base image**: Ubuntu 22.04 LTS
- **User**: Non-root user `testuser` (matches real-world usage)
- **Tests**: 10 integration tests covering all components

### Running Tests

Quick method:
```bash
./test/run.sh
```

Manual method:
```bash
docker build -f test/Dockerfile.ubuntu -t env-test .
docker run --rm env-test
```

### Test Coverage

The `test/integration.sh` script validates:
1. Required commands exist (git, gpgconf, mise, nvim, rg, fd, bat, gh, zsh)
2. Dotfiles are properly symlinked (`.zshrc`, `.zprofile`)
3. Zsh configuration loads without errors
4. `mise doctor` passes
5. GPG agent sockets available (agent-socket, agent-ssh-socket)
6. Zsh completions generated
7. Required directories exist (`~/.ssh/sockets`, `~/.local/share/zsh/site-functions`, `~/.gnupg`)
8. mise can list available runtimes
9. mise runtimes installed (node, python, ruby, go, rust, java)
10. Runtime executables work in PATH (node, python versions)

### CI Integration

The Dockerfile can be integrated into CI/CD:
- GitHub Actions: Use standard Docker build/run actions
- GitLab CI: Use `docker:dind` service
- Exit code 0 = all tests passed, non-zero = failures

## Troubleshooting

### "command not found: gpgconf" or "command not found: mise"

**Cause**: Homebrew not in PATH when `.zshrc` runs, or packages not installed.

**Solution**:
1. Ensure `.zprofile` sets up Homebrew (should have platform detection for macOS/Linux)
2. Install packages:
   ```bash
   eval "$(/opt/homebrew/bin/brew shellenv)"  # macOS Apple Silicon
   # OR
   eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"  # Linux

   brew bundle --file="homebrew/Brewfile"
   brew bundle --file="homebrew/Brewfile.macos"  # or Brewfile.linux
   ```
3. Restart shell or source files: `source ~/.zprofile && source ~/.zshrc`

### Brewfile syntax errors

**Solution**: Use `brew bundle check --file="homebrew/Brewfile"` to validate

### mise install fails

**Cause**: No mise configuration file found.

**Solution**: The install script will skip `mise install` if no config exists. This is expected. Add runtimes to `~/.config/mise/config.toml` and run `mise install` manually.

### Docker build fails on mise install

**Cause**: Some runtimes may fail to compile (especially on resource-constrained systems).

**Solution**: The Dockerfile uses `|| echo "Warning: ..."` to continue on failure. Check which specific runtime failed and investigate build logs.

## Git Strategy

- Main branch: `main`
- Symlinked files are tracked in repo (e.g., `home/zshrc`)
- Actual dotfiles (e.g., `~/.zshrc`) are symlinks created by rcm
- Changes to `~/.zshrc` should be made in `home/zshrc`

## Best Practices

1. **Never modify `~/.zshrc` directly** - edit `home/zshrc` and re-run `rcup -t <platform>`
2. **Keep Homebrew setup in `.zprofile`** - don't duplicate in `.zshrc`
3. **Test on both platforms** when adding packages
4. **Use standard naming** - `Brewfile`, not `.Brewfile`
5. **Respect shell init order** - login shell (`.zprofile`) before interactive (`.zshrc`)
6. **Use rcm tags for platform-specific configs** - don't use sed or manual file editing in install.sh
7. **Run rcup with platform tag** - `rcup -t macos` or `rcup -t linux` to get platform-specific files

## Dependencies

### Required Packages (from Brewfile)
- git, git-lfs, git-crypt, git-delta
- rcm (dotfile management)
- mise (runtime management)
- gnupg (GPG agent for SSH)
- neovim, ripgrep, fd, bat
- curl, wget
- zsh-syntax-highlighting
- gh (GitHub CLI)

### Platform-Specific
- macOS: kitty, pinentry-mac, fonts
- Linux: TBD in Brewfile.linux

## Future Maintenance

- Add new packages to appropriate Brewfile
- Platform-specific configs go in platform-specific Brewfiles
- Keep install stages idempotent (can be run multiple times safely)
- Document breaking changes in this file
