#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Setting up git hooks..."

# Configure git to use our hooks directory
git config core.hooksPath .githooks

# Make hooks executable
chmod +x "$PROJECT_DIR/.githooks/"*

echo "Git hooks configured."
echo ""
echo "Pre-commit hook will run trufflehog to scan for secrets."
echo "Make sure trufflehog is installed: brew install trufflehog"
