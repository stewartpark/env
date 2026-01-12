#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}====================================${NC}"
echo -e "${BLUE}  Environment Setup - Multi-Stage${NC}"
echo -e "${BLUE}====================================${NC}"
echo ""

# ============================================================================
# Repository Setup
# ============================================================================
REPO_URL="https://github.com/stewartpark/env.git"
WORKSPACE_DIR="$HOME/workspace"
DOTFILES_DIR="$WORKSPACE_DIR/env"

# Check if repository exists
if [[ -d "$DOTFILES_DIR/.git" ]]; then
    echo -e "${GREEN}✓ Repository already exists at $DOTFILES_DIR${NC}"
    cd "$DOTFILES_DIR"

    # Pull latest changes
    echo -e "${YELLOW}Checking for updates...${NC}"
    git pull
else
    # Create workspace directory and clone
    echo -e "${YELLOW}Creating workspace directory...${NC}"
    mkdir -p "$WORKSPACE_DIR"

    echo -e "${YELLOW}Cloning repository to $DOTFILES_DIR...${NC}"
    git clone "$REPO_URL" "$DOTFILES_DIR"
    cd "$DOTFILES_DIR"
    echo -e "${GREEN}✓ Repository cloned${NC}"
fi

echo ""

# ============================================================================
# Platform Detection
# ============================================================================
echo -e "${YELLOW}Detecting platform...${NC}"

if [[ "$OSTYPE" == "darwin"* ]]; then
    PLATFORM="macos"
    echo -e "${GREEN}✓ Detected: macOS${NC}"
elif [ -f /etc/debian_version ]; then
    PLATFORM="debian"
    echo -e "${GREEN}✓ Detected: Debian/Ubuntu${NC}"
elif [ -f /etc/redhat-release ]; then
    PLATFORM="redhat"
    echo -e "${GREEN}✓ Detected: RHEL/Fedora${NC}"
else
    PLATFORM="linux"
    echo -e "${GREEN}✓ Detected: Generic Linux${NC}"
fi

echo ""

# ============================================================================
# STAGE 1: Base Installation
# ============================================================================
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  STAGE 1: Base Installation${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Install Homebrew if missing
if ! command -v brew &> /dev/null; then
    echo -e "${YELLOW}Installing Homebrew...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for this script
    if [[ "$PLATFORM" == "macos" ]]; then
        if [[ -f /opt/homebrew/bin/brew ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        else
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    else
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi

    echo -e "${GREEN}✓ Homebrew installed${NC}"
else
    echo -e "${GREEN}✓ Homebrew already installed${NC}"
fi

# Install packages via brew bundle
echo -e "${YELLOW}Installing packages...${NC}"
cd "$DOTFILES_DIR"
brew bundle --file="homebrew/Brewfile"

if [[ "$PLATFORM" == "macos" ]]; then
    brew bundle --file="homebrew/Brewfile.macos"
else
    brew bundle --file="homebrew/Brewfile.linux"
fi
echo -e "${GREEN}✓ Packages installed${NC}"

# Symlink dotfiles with rcm (platform-specific via tags)
echo -e "${YELLOW}Symlinking dotfiles with rcm...${NC}"
if [[ "$PLATFORM" == "macos" ]]; then
    rcup -d "$DOTFILES_DIR/home" -t macos -f -v
else
    rcup -d "$DOTFILES_DIR/home" -t linux -f -v
fi
echo -e "${GREEN}✓ Dotfiles symlinked${NC}"

# Create required directories
echo -e "${YELLOW}Creating required directories...${NC}"
mkdir -p ~/.ssh/sockets
mkdir -p ~/.local/share/zsh/site-functions
echo -e "${GREEN}✓ Directories created${NC}"

# Set permissions
echo -e "${YELLOW}Setting permissions...${NC}"
chmod 700 ~/.gnupg
chmod 700 ~/.ssh
echo -e "${GREEN}✓ Permissions set${NC}"

# Restart GPG agent to pick up new config
echo -e "${YELLOW}Restarting GPG agent...${NC}"
gpgconf --kill gpg-agent
gpg-agent --daemon
echo -e "${GREEN}✓ GPG agent restarted${NC}"

# Install mise language runtimes
echo -e "${YELLOW}Installing mise language runtimes (this may take a while)...${NC}"
mise install
echo -e "${GREEN}✓ mise runtimes installed${NC}"

# Generate mise completions
echo -e "${YELLOW}Generating mise completions...${NC}"
mise completion zsh > ~/.local/share/zsh/site-functions/_mise
echo -e "${GREEN}✓ mise completions generated${NC}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  STAGE 1 Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# ============================================================================
# STAGE 2: SSH Key Setup
# ============================================================================
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  STAGE 2: SSH Key Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

SSH_KEY_EXISTS=false
if [[ -f ~/.ssh/id_ed25519 ]]; then
    SSH_KEY="~/.ssh/id_ed25519"
    SSH_KEY_PUB="~/.ssh/id_ed25519.pub"
    SSH_KEY_EXISTS=true
elif [[ -f ~/.ssh/id_rsa ]]; then
    SSH_KEY="~/.ssh/id_rsa"
    SSH_KEY_PUB="~/.ssh/id_rsa.pub"
    SSH_KEY_EXISTS=true
fi

if $SSH_KEY_EXISTS; then
    echo -e "${GREEN}✓ SSH key found at $SSH_KEY${NC}"

    # Test SSH connection to GitHub
    echo -e "${YELLOW}Testing SSH connection to GitHub...${NC}"
    if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        echo -e "${GREEN}✓ SSH key already configured for GitHub${NC}"
    else
        echo -e "${RED}✗ SSH key is not registered on GitHub${NC}"
        echo ""
        echo -e "${YELLOW}Your SSH public key:${NC}"
        cat "$SSH_KEY_PUB"
        echo ""
        echo -e "${YELLOW}Please add this key to GitHub at:${NC}"
        echo -e "${BLUE}https://github.com/settings/keys${NC}"
        echo ""
        read -p "Press Enter after adding the key to GitHub..."

        # Re-test connection
        echo -e "${YELLOW}Testing connection again...${NC}"
        if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
            echo -e "${GREEN}✓ SSH connection successful${NC}"
        else
            echo -e "${RED}✗ Connection failed. You may need to check your key.${NC}"
        fi
    fi
else
    echo -e "${YELLOW}No SSH key found. Generating new ed25519 key...${NC}"
    echo ""
    read -p "Enter your email for the SSH key: " email
    ssh-keygen -t ed25519 -C "$email" -f ~/.ssh/id_ed25519
    SSH_KEY_PUB="~/.ssh/id_ed25519.pub"

    echo ""
    echo -e "${YELLOW}Your new SSH public key:${NC}"
    cat ~/.ssh/id_ed25519.pub
    echo ""
    echo -e "${YELLOW}Please add this key to GitHub at:${NC}"
    echo -e "${BLUE}https://github.com/settings/keys${NC}"
    echo ""
    read -p "Press Enter after adding the key to GitHub..."

    # Test connection
    echo -e "${YELLOW}Testing SSH connection...${NC}"
    if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        echo -e "${GREEN}✓ SSH connection successful${NC}"
    else
        echo -e "${RED}✗ Connection failed. You may need to check your key.${NC}"
    fi
fi

echo ""

# Switch git remote from HTTPS to SSH for future operations
echo -e "${YELLOW}Updating git remote to use SSH...${NC}"
cd "$DOTFILES_DIR"
CURRENT_REMOTE=$(git remote get-url origin)
if [[ "$CURRENT_REMOTE" == https://* ]]; then
    git remote set-url origin "git@github.com:stewartpark/env.git"
    echo -e "${GREEN}✓ Git remote updated to SSH${NC}"
else
    echo -e "${GREEN}✓ Git remote already using SSH${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  STAGE 2 Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# ============================================================================
# STAGE 3: Secrets Repository
# ============================================================================
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  STAGE 3: Secrets Repository${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

SECRETS_REPO_URL="git@github.com:stewartpark/env-secrets.git"
SECRETS_DIR="$DOTFILES_DIR/secrets"

if [[ -d "$SECRETS_DIR" ]]; then
    echo -e "${GREEN}✓ Secrets repository already cloned${NC}"
else
    echo -e "${YELLOW}Cloning secrets repository...${NC}"
    git clone "$SECRETS_REPO_URL" "$SECRETS_DIR"
    echo -e "${GREEN}✓ Secrets repository cloned${NC}"
fi

# Unlock git-crypt
echo ""
echo -e "${YELLOW}Enter the path to your git-crypt key file:${NC}"
echo -e "${BLUE}(Usually in Google Drive or a secure location)${NC}"
read -p "Path: " git_crypt_key

if [[ -f "$git_crypt_key" ]]; then
    echo -e "${YELLOW}Unlocking git-crypt...${NC}"
    cd "$SECRETS_DIR"
    git-crypt unlock "$git_crypt_key"
    echo -e "${GREEN}✓ git-crypt unlocked${NC}"

    # Import GPG keys
    GPG_KEY_ID="B85463C5"

    # Check if key already exists
    if gpg --list-keys "$GPG_KEY_ID" &>/dev/null; then
        echo -e "${GREEN}✓ GPG key $GPG_KEY_ID already imported${NC}"
    else
        echo -e "${YELLOW}Importing GPG keys...${NC}"
        if [[ -f keys/private.key && -f keys/public.key ]]; then
            gpg --import keys/private.key
            gpg --import keys/public.key
            echo -e "${GREEN}✓ GPG keys imported${NC}"

            # Set trust level
            echo ""
            echo -e "${YELLOW}Please set the trust level for your GPG key:${NC}"
            echo -e "${BLUE}Run: gpg --edit-key $GPG_KEY_ID${NC}"
            echo -e "${BLUE}Then type: trust${NC}"
            echo -e "${BLUE}Select: 5 (ultimate)${NC}"
            echo -e "${BLUE}Then type: quit${NC}"
            echo ""

            # Restart gpg-agent
            gpgconf --kill gpg-agent
            gpg-agent --daemon
            echo -e "${GREEN}✓ GPG agent restarted${NC}"
        else
            echo -e "${YELLOW}⚠ GPG keys not found in secrets repo${NC}"
        fi
    fi
else
    echo -e "${RED}✗ git-crypt key file not found${NC}"
    echo -e "${YELLOW}Skipping secrets repository unlock${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  STAGE 3 Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# ============================================================================
# STAGE 4: Finalization
# ============================================================================
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  STAGE 4: Finalization${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Set zsh as default shell
if [[ "$SHELL" != *"zsh"* ]]; then
    echo -e "${YELLOW}Setting zsh as default shell...${NC}"
    chsh -s $(which zsh)
    echo -e "${GREEN}✓ zsh set as default shell${NC}"
else
    echo -e "${GREEN}✓ zsh is already the default shell${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Restart your terminal or run: source ~/.zshrc"
echo "  2. Run: kitty +kitten themes   (to select a Kitty color theme)"
echo "  3. Run: mise doctor   (to verify mise installation)"
echo "  4. Set GPG key trust level (if you haven't already)"
echo ""
echo -e "${YELLOW}Enjoy your new environment setup!${NC}"
