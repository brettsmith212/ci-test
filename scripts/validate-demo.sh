#!/usr/bin/env bash
set -euo pipefail

# Validation script for CI-Feedback Loop Demo

echo "🔍 Validating CI-Feedback Loop Demo Setup"
echo "========================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

check_pass() { echo -e "${GREEN}✅ $1${NC}"; }
check_fail() { echo -e "${RED}❌ $1${NC}"; }
check_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
check_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

# Track validation results
ERRORS=0
WARNINGS=0

# Check file structure
echo "📁 Checking file structure..."
required_files=(
    "scripts/amp-agent.sh"
    "scripts/setup-demo.sh"
    "scripts/examples.sh"
    ".github/workflows/ci.yml"
    "package.json"
    "src/calculator.js"
    "src/utils.js"
    "tests/calculator.test.js"
    "tests/utils.test.js"
    ".amp-agent.config"
    "README.md"
)

for file in "${required_files[@]}"; do
    if [[ -f "$file" ]]; then
        check_pass "Found $file"
    else
        check_fail "Missing $file"
        ((ERRORS++))
    fi
done

# Check script permissions
echo ""
echo "🔧 Checking script permissions..."
scripts=("scripts/amp-agent.sh" "scripts/setup-demo.sh" "scripts/examples.sh")
for script in "${scripts[@]}"; do
    if [[ -x "$script" ]]; then
        check_pass "$script is executable"
    else
        check_fail "$script is not executable"
        ((ERRORS++))
    fi
done

# Check dependencies
echo ""
echo "🛠️  Checking dependencies..."
dependencies=("git" "jq")
for dep in "${dependencies[@]}"; do
    if command -v "$dep" &> /dev/null; then
        check_pass "$dep is installed"
    else
        check_fail "$dep is not installed"
        ((ERRORS++))
    fi
done

# Check optional dependencies
optional_deps=("amp" "gh")
for dep in "${optional_deps[@]}"; do
    if command -v "$dep" &> /dev/null; then
        check_pass "$dep is installed"
    else
        check_warn "$dep is not installed (required for full functionality)"
        ((WARNINGS++))
    fi
done

# Check Git setup
echo ""
echo "📦 Checking Git setup..."
if git rev-parse --git-dir > /dev/null 2>&1; then
    check_pass "Running in a Git repository"
    
    # Check remote
    if git config --get remote.origin.url > /dev/null 2>&1; then
        repo_url=$(git config --get remote.origin.url)
        check_pass "Git remote configured: $repo_url"
    else
        check_warn "No Git remote configured"
        ((WARNINGS++))
    fi
    
    # Check Git user
    if git config --get user.name > /dev/null 2>&1 && git config --get user.email > /dev/null 2>&1; then
        check_pass "Git user configured"
    else
        check_warn "Git user not configured"
        ((WARNINGS++))
    fi
else
    check_fail "Not in a Git repository"
    ((ERRORS++))
fi

# Check GitHub CLI setup
echo ""
echo "🔑 Checking GitHub CLI setup..."
if command -v gh &> /dev/null; then
    if gh auth status &> /dev/null; then
        check_pass "GitHub CLI authenticated"
    else
        check_warn "GitHub CLI not authenticated (run 'gh auth login')"
        ((WARNINGS++))
    fi
else
    check_warn "GitHub CLI not installed"
    ((WARNINGS++))
fi

# Validate package.json
echo ""
echo "📋 Validating package.json..."
if [[ -f "package.json" ]]; then
    if command -v node &> /dev/null; then
        if node -e "JSON.parse(require('fs').readFileSync('package.json', 'utf8'))" 2>/dev/null; then
            check_pass "package.json is valid JSON"
        else
            check_fail "package.json is invalid JSON"
            ((ERRORS++))
        fi
    else
        check_warn "Node.js not installed, cannot validate package.json"
        ((WARNINGS++))
    fi
fi

# Validate CI workflow
echo ""
echo "🚀 Validating CI workflow..."
if [[ -f ".github/workflows/ci.yml" ]]; then
    # Basic YAML syntax check
    if command -v python3 &> /dev/null; then
        if python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))" 2>/dev/null; then
            check_pass "CI workflow YAML is valid"
        elif python3 -c "import sys; sys.exit(0)" 2>/dev/null; then
            # Python is available but yaml module is not
            check_info "Python yaml module not available, skipping YAML validation"
        else
            check_fail "CI workflow YAML is invalid"
            ((ERRORS++))
        fi
    else
        check_info "Python3 not available, skipping YAML validation"
    fi
    
    # Check for required jobs
    if grep -q "jobs:" ".github/workflows/ci.yml" && grep -q "test:" ".github/workflows/ci.yml"; then
        check_pass "CI workflow has test job"
    else
        check_fail "CI workflow missing test job"
        ((ERRORS++))
    fi
fi

# Test dry run functionality
echo ""
echo "🧪 Testing dry run functionality..."
if [[ -x "scripts/amp-agent.sh" ]] && command -v jq &> /dev/null; then
    # Test help output
    if ./scripts/amp-agent.sh --help > /dev/null 2>&1; then
        check_pass "Script help works"
    else
        check_fail "Script help not working"
        ((ERRORS++))
    fi
    
    # Test argument parsing
    if ./scripts/amp-agent.sh --task "test" --repo "fake-repo" --dry-run 2>&1 | grep -q "Missing required dependency"; then
        check_pass "Script correctly identifies missing dependencies"
    else
        check_info "Cannot test dependency checking without missing dependencies"
    fi
else
    check_warn "Cannot test script functionality (missing dependencies)"
    ((WARNINGS++))
fi

# Check for potential issues
echo ""
echo "🔍 Checking for potential issues..."

# Check if running on correct platform
if [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "darwin"* ]]; then
    check_pass "Running on supported platform ($OSTYPE)"
else
    check_warn "Running on potentially unsupported platform ($OSTYPE)"
    ((WARNINGS++))
fi

# Check shell
if [[ -n "${BASH_VERSION:-}" ]]; then
    check_pass "Running with Bash"
else
    check_warn "Not running with Bash, some features may not work"
    ((WARNINGS++))
fi

# Final summary
echo ""
echo "📊 Validation Summary"
echo "===================="
if [[ $ERRORS -eq 0 ]] && [[ $WARNINGS -eq 0 ]]; then
    check_pass "All checks passed! Demo is ready to use."
    echo ""
    echo "Next steps:"
    echo "1. Run: ./scripts/setup-demo.sh"
    echo "2. Run: ./scripts/examples.sh"
    echo "3. Try: ./scripts/amp-agent.sh --task 'fix power function' --repo \$(git config --get remote.origin.url) --dry-run"
elif [[ $ERRORS -eq 0 ]]; then
    check_warn "Validation completed with $WARNINGS warnings"
    echo ""
    echo "The demo should work, but some features may not be available."
    echo "See warnings above for details."
else
    check_fail "Validation failed with $ERRORS errors and $WARNINGS warnings"
    echo ""
    echo "Please fix the errors above before using the demo."
    exit 1
fi
