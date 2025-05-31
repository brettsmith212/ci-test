#!/usr/bin/env bash
set -euo pipefail

# Setup script for CI-Feedback Loop Demo

echo "🚀 Setting up CI-Feedback Loop Demo"

# Check if running in git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ This script must be run in a git repository"
    exit 1
fi

# Install dependencies
echo "📦 Installing dependencies..."
npm install

# Check required tools
echo "🔧 Checking required tools..."
tools=("amp" "gh" "jq")
missing_tools=()

for tool in "${tools[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        missing_tools+=("$tool")
    fi
done

if [[ ${#missing_tools[@]} -gt 0 ]]; then
    echo "❌ Missing required tools:"
    for tool in "${missing_tools[@]}"; do
        echo "  - $tool"
    done
    echo ""
    echo "Installation instructions:"
    echo "  - amp: https://github.com/sourcegraph/amp"
    echo "  - gh: https://github.com/cli/cli"
    echo "  - jq: https://jqlang.github.io/jq/"
    exit 1
fi

# Check GitHub CLI authentication
echo "🔑 Checking GitHub CLI authentication..."
if ! gh auth status &> /dev/null; then
    echo "❌ GitHub CLI not authenticated"
    echo "Run: gh auth login"
    exit 1
fi

# Verify repository access
repo_url=$(git config --get remote.origin.url || echo "")
if [[ -n "$repo_url" ]]; then
    echo "✅ Repository: $repo_url"
else
    echo "⚠️  No remote origin configured"
fi

echo "✅ Setup complete!"
echo ""
echo "Usage examples:"
echo "  ./scripts/amp-agent.sh --task 'fix the power function to handle negative exponents' --repo \$repo_url"
echo "  ./scripts/amp-agent.sh --task 'migrate tests from Mocha to Vitest' --repo \$repo_url"
echo "  ./scripts/amp-agent.sh --task 'add JSDoc comments to all functions' --repo \$repo_url --dry-run"
