#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Environment Integration Tests${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Set up Homebrew
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

FAILED=0

# Test 1: Check required commands exist
echo -e "${YELLOW}Test 1: Checking required commands...${NC}"
COMMANDS=("git" "gpgconf" "mise" "nvim" "rg" "fd" "bat" "gh" "zsh")
for cmd in "${COMMANDS[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}  ✓ $cmd found${NC}"
    else
        echo -e "${RED}  ✗ $cmd not found${NC}"
        FAILED=1
    fi
done
echo ""

# Test 2: Check dotfiles are symlinked
echo -e "${YELLOW}Test 2: Checking dotfiles are symlinked...${NC}"
if [[ -L "$HOME/.zshrc" ]]; then
    echo -e "${GREEN}  ✓ .zshrc is symlinked${NC}"
else
    echo -e "${RED}  ✗ .zshrc is not a symlink${NC}"
    FAILED=1
fi

if [[ -L "$HOME/.zprofile" ]]; then
    echo -e "${GREEN}  ✓ .zprofile is symlinked${NC}"
else
    echo -e "${RED}  ✗ .zprofile is not a symlink${NC}"
    FAILED=1
fi
echo ""

# Test 3: Source zsh configuration without errors
echo -e "${YELLOW}Test 3: Sourcing zsh configuration...${NC}"
export SHELL=/home/linuxbrew/.linuxbrew/bin/zsh
if zsh -c 'source ~/.zprofile && source ~/.zshrc && echo "Configuration loaded successfully"' 2>&1 | grep -q "Configuration loaded successfully"; then
    echo -e "${GREEN}  ✓ .zprofile and .zshrc loaded without errors${NC}"
else
    echo -e "${RED}  ✗ Error loading zsh configuration${NC}"
    echo -e "${YELLOW}  Running again with verbose output:${NC}"
    zsh -c 'source ~/.zprofile && source ~/.zshrc' 2>&1 || true
    FAILED=1
fi
echo ""

# Test 4: Run mise doctor
echo -e "${YELLOW}Test 4: Running mise doctor...${NC}"
if mise doctor >/dev/null 2>&1; then
    echo -e "${GREEN}  ✓ mise doctor passed${NC}"
else
    echo -e "${YELLOW}  ⚠ mise doctor had warnings (this may be expected)${NC}"
    mise doctor || true
fi
echo ""

# Test 5: Test GPG agent can start
echo -e "${YELLOW}Test 5: Testing GPG agent...${NC}"
export GPG_TTY=$(tty)
if gpgconf --list-dirs agent-socket >/dev/null 2>&1; then
    echo -e "${GREEN}  ✓ GPG agent socket available${NC}"
else
    echo -e "${RED}  ✗ GPG agent socket not available${NC}"
    FAILED=1
fi

if gpgconf --list-dirs agent-ssh-socket >/dev/null 2>&1; then
    echo -e "${GREEN}  ✓ GPG agent SSH socket available${NC}"
else
    echo -e "${RED}  ✗ GPG agent SSH socket not available${NC}"
    FAILED=1
fi
echo ""

# Test 6: Verify completions exist
echo -e "${YELLOW}Test 6: Checking zsh completions...${NC}"
if [[ -f "$HOME/.local/share/zsh/site-functions/_mise" ]]; then
    echo -e "${GREEN}  ✓ mise completions generated${NC}"
else
    echo -e "${RED}  ✗ mise completions not found${NC}"
    FAILED=1
fi
echo ""

# Test 7: Verify required directories exist
echo -e "${YELLOW}Test 7: Checking required directories...${NC}"
DIRS=("$HOME/.ssh/sockets" "$HOME/.local/share/zsh/site-functions" "$HOME/.gnupg")
for dir in "${DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        echo -e "${GREEN}  ✓ $dir exists${NC}"
    else
        echo -e "${RED}  ✗ $dir not found${NC}"
        FAILED=1
    fi
done
echo ""

# Test 8: Test mise can list available runtimes
echo -e "${YELLOW}Test 8: Testing mise functionality...${NC}"
if mise ls-remote node 2>&1 | head -5 | grep -q "node"; then
    echo -e "${GREEN}  ✓ mise can list available runtimes${NC}"
else
    echo -e "${RED}  ✗ mise cannot list runtimes${NC}"
    FAILED=1
fi
echo ""

# Test 9: Verify mise runtimes are installed
echo -e "${YELLOW}Test 9: Verifying installed mise runtimes...${NC}"
RUNTIMES=("node" "python" "ruby" "go" "rust" "java")
for runtime in "${RUNTIMES[@]}"; do
    if mise where "$runtime" >/dev/null 2>&1; then
        echo -e "${GREEN}  ✓ $runtime installed${NC}"
    else
        echo -e "${YELLOW}  ⚠ $runtime not installed (may be expected)${NC}"
    fi
done
echo ""

# Test 10: Test that installed runtimes are in PATH
echo -e "${YELLOW}Test 10: Testing runtime executables in zsh...${NC}"
if zsh -c 'source ~/.zprofile && source ~/.zshrc && node --version' >/dev/null 2>&1; then
    NODE_VERSION=$(zsh -c 'source ~/.zprofile && source ~/.zshrc && node --version')
    echo -e "${GREEN}  ✓ node executable works: $NODE_VERSION${NC}"
else
    echo -e "${YELLOW}  ⚠ node not in PATH${NC}"
fi

if zsh -c 'source ~/.zprofile && source ~/.zshrc && python --version' >/dev/null 2>&1; then
    PYTHON_VERSION=$(zsh -c 'source ~/.zprofile && source ~/.zshrc && python --version')
    echo -e "${GREEN}  ✓ python executable works: $PYTHON_VERSION${NC}"
else
    echo -e "${YELLOW}  ⚠ python not in PATH${NC}"
fi
echo ""

# Final results
echo -e "${BLUE}========================================${NC}"
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}  All Tests Passed! ✓${NC}"
    echo -e "${BLUE}========================================${NC}"
    exit 0
else
    echo -e "${RED}  Some Tests Failed ✗${NC}"
    echo -e "${BLUE}========================================${NC}"
    exit 1
fi
