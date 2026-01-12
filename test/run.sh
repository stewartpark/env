#!/bin/bash

set -e

# Get the repo root directory
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="env-test"

echo "Building Docker image..."
docker build -f "$REPO_ROOT/test/Dockerfile.ubuntu" -t "$IMAGE_NAME" "$REPO_ROOT"

echo ""
echo "Running tests..."
docker run --rm "$IMAGE_NAME"

echo ""
echo "Tests completed!"
