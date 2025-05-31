#!/usr/bin/env bash

# Example usage scenarios for the CI-Feedback Loop Demo

REPO_URL=$(git config --get remote.origin.url 2>/dev/null || echo "git@github.com:your-org/your-repo.git")

echo "🎯 CI-Feedback Loop Demo Examples"
echo "================================="
echo ""

echo "Example 1: Fix the power function bug"
echo "--------------------------------------"
echo "The calculator.js has a bug in the power function - it doesn't handle negative exponents."
echo "Command:"
echo "./scripts/amp-agent.sh \\"
echo "  --task 'fix the power function in calculator.js to handle negative exponents correctly' \\"
echo "  --repo '$REPO_URL'"
echo ""

echo "Example 2: Migrate tests from Mocha to Vitest"
echo "---------------------------------------------"
echo "Convert the existing Mocha test suite to use Vitest instead."
echo "Command:"
echo "./scripts/amp-agent.sh \\"
echo "  --task 'migrate all tests from Mocha to Vitest, update package.json and test files' \\"
echo "  --repo '$REPO_URL'"
echo ""

echo "Example 3: Add comprehensive error handling"
echo "------------------------------------------"
echo "Add better error handling throughout the codebase."
echo "Command:"
echo "./scripts/amp-agent.sh \\"
echo "  --task 'add comprehensive error handling and input validation to all functions' \\"
echo "  --repo '$REPO_URL'"
echo ""

echo "Example 4: Add TypeScript (dry run)"
echo "----------------------------------"
echo "Convert JavaScript to TypeScript (without actually executing)."
echo "Command:"
echo "./scripts/amp-agent.sh \\"
echo "  --task 'convert the JavaScript codebase to TypeScript with proper type definitions' \\"
echo "  --repo '$REPO_URL' \\"
echo "  --dry-run"
echo ""

echo "Example 5: Performance optimization"
echo "----------------------------------"
echo "Optimize code for better performance."
echo "Command:"
echo "./scripts/amp-agent.sh \\"
echo "  --task 'optimize the factorial function to use iterative approach instead of recursive' \\"
echo "  --repo '$REPO_URL' \\"
echo "  --base-branch develop"
echo ""

echo "Pro Tips:"
echo "========="
echo "• Use --dry-run to test without pushing changes"
echo "• Specify --base-branch for different target branches"
echo "• Tasks should be specific and focused"
echo "• The agent will automatically retry on CI failures"
echo "• Check the .github/workflows/ci.yml for CI configuration"
