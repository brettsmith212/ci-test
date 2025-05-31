#!/usr/bin/env bash
set -euo pipefail

# CI-Feedback Loop Orchestrator for Amp CLI
# Usage: ./amp-agent.sh --task "your task" --repo "git@github.com:org/repo.git"

# Configuration
MAX_ATTEMPTS=5
POLL_INTERVAL=30
WORK_DIR="/tmp/amp-agent-$$"
LOG_SIZE_LIMIT=4000

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

usage() {
    cat << EOF
Usage: $0 --task "TASK_DESCRIPTION" --repo "REPO_URL" [OPTIONS]

Required:
  --task TASK       Natural language task description
  --repo REPO_URL   Git repository URL (SSH or HTTPS)

Optional:
  --base-branch BRANCH    Base branch for PR (default: main)
  --max-attempts NUM      Maximum CI retry attempts (default: 5)
  --poll-interval SEC     CI polling interval in seconds (default: 30)
  --work-dir DIR          Working directory (default: /tmp/amp-agent-PID)
  --dry-run               Don't push commits or create PR
  --help                  Show this help

Examples:
  $0 --task "migrate Mocha tests to Vitest" --repo git@github.com:acme/widgets.git
  $0 --task "add error handling to API calls" --repo https://github.com/org/app.git --base-branch develop
EOF
}

# Parse command line arguments
TASK=""
REPO_URL=""
BASE_BRANCH="main"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --task)
            TASK="$2"
            shift 2
            ;;
        --repo)
            REPO_URL="$2"
            shift 2
            ;;
        --base-branch)
            BASE_BRANCH="$2"
            shift 2
            ;;
        --max-attempts)
            MAX_ATTEMPTS="$2"
            shift 2
            ;;
        --poll-interval)
            POLL_INTERVAL="$2"
            shift 2
            ;;
        --work-dir)
            WORK_DIR="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$TASK" ]]; then
    log_error "Task description is required"
    usage
    exit 1
fi

if [[ -z "$REPO_URL" ]]; then
    log_error "Repository URL is required"
    usage
    exit 1
fi

# Check dependencies
check_dependencies() {
    local deps=("git" "gh" "jq" "amp")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "Required dependency not found: $dep"
            exit 1
        fi
    done
}

# Extract owner/repo from URL
get_repo_info() {
    local url="$1"
    # Handle both SSH and HTTPS URLs
    if [[ "$url" =~ git@github\.com:([^/]+)/([^.]+)(\.git)?$ ]]; then
        echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    elif [[ "$url" =~ https://github\.com/([^/]+)/([^/]+)(\.git)?/?$ ]]; then
        echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    else
        log_error "Invalid GitHub repository URL: $url"
        exit 1
    fi
}

# Generate Amp prompt
generate_prompt() {
    local task="$1"
    local attempt="$2"
    local error_log="$3"
    
    if [[ $attempt -eq 1 ]]; then
        cat << EOF
You are a coding agent working on a software project. 

Current repository HEAD: $(git rev-parse HEAD)
Task: $task

Create a unified diff patch that accomplishes this task. Follow these requirements:
1. Only output the patch in unified diff format
2. Ensure the changes are minimal and focused on the task
3. Include proper error handling and edge cases
4. Follow existing code style and conventions
5. Update tests if necessary

Output only the patch, no explanations.
EOF
    else
        cat << EOF
You are a coding agent fixing CI failures.

Previous task: $task
Attempt: $attempt/$MAX_ATTEMPTS

The CI failed with the following error:
---
$error_log
---

Analyze the error and create a unified diff patch to fix it. Requirements:
1. Only output the patch in unified diff format
2. Focus specifically on fixing the CI failure
3. Don't introduce new issues
4. Be conservative with changes

Output only the patch, no explanations.
EOF
    fi
}

# Apply patch and commit
apply_and_commit() {
    local patch="$1"
    local attempt="$2"
    
    log_info "Applying patch (attempt $attempt)..."
    
    # Save patch to file for debugging
    echo "$patch" > "patch-attempt-$attempt.diff"
    
    # Apply patch
    if echo "$patch" | git apply --check; then
        echo "$patch" | git apply
        git add -A
        
        if [[ $attempt -eq 1 ]]; then
            git commit -m "amp: $TASK"
        else
            git commit -m "amp: fix CI failure (attempt $attempt)"
        fi
        
        log_success "Patch applied and committed"
        return 0
    else
        log_error "Failed to apply patch"
        return 1
    fi
}

# Poll GitHub Actions status
poll_ci_status() {
    local owner_repo="$1"
    local sha="$2"
    
    log_info "Polling CI status for SHA: $sha"
    
    while true; do
        local response
        response=$(gh api "/repos/$owner_repo/actions/runs?head_sha=$sha" 2>/dev/null || echo '{"workflow_runs":[]}')
        
        local run_id
        run_id=$(echo "$response" | jq -r '.workflow_runs[0].id // "null"')
        
        if [[ "$run_id" == "null" ]]; then
            log_info "No CI run found yet, waiting..."
            sleep "$POLL_INTERVAL"
            continue
        fi
        
        local status
        status=$(echo "$response" | jq -r '.workflow_runs[0].status')
        local conclusion
        conclusion=$(echo "$response" | jq -r '.workflow_runs[0].conclusion // "null"')
        
        case "$status" in
            "queued"|"in_progress")
                log_info "CI is running... (status: $status)"
                sleep "$POLL_INTERVAL"
                ;;
            "completed")
                case "$conclusion" in
                    "success")
                        log_success "CI passed!"
                        return 0
                        ;;
                    "failure"|"cancelled"|"timed_out")
                        log_error "CI failed with conclusion: $conclusion"
                        
                        # Fetch logs
                        local logs
                        logs=$(fetch_ci_logs "$owner_repo" "$run_id")
                        echo "$logs"
                        return 1
                        ;;
                    *)
                        log_warning "Unexpected CI conclusion: $conclusion"
                        sleep "$POLL_INTERVAL"
                        ;;
                esac
                ;;
            *)
                log_warning "Unexpected CI status: $status"
                sleep "$POLL_INTERVAL"
                ;;
        esac
    done
}

# Fetch CI logs
fetch_ci_logs() {
    local owner_repo="$1"
    local run_id="$2"
    
    log_info "Fetching CI logs for run $run_id..."
    
    # Download logs archive
    local logs_file="logs-$run_id.zip"
    if gh api -H "Accept: application/vnd.github+json" "/repos/$owner_repo/actions/runs/$run_id/logs" > "$logs_file" 2>/dev/null; then
        # Extract and process logs
        local extracted_logs
        extracted_logs=$(unzip -p "$logs_file" 2>/dev/null | head -c "$LOG_SIZE_LIMIT" || echo "Failed to extract logs")
        rm -f "$logs_file"
        echo "$extracted_logs"
    else
        echo "Failed to download CI logs"
    fi
}

# Main execution function
main() {
    log_info "Starting Amp CI-Feedback Loop Agent"
    log_info "Task: $TASK"
    log_info "Repo: $REPO_URL"
    log_info "Working directory: $WORK_DIR"
    
    # Check dependencies
    check_dependencies
    
    # Get repository info
    local owner_repo
    owner_repo=$(get_repo_info "$REPO_URL")
    log_info "Repository: $owner_repo"
    
    # Create working directory and clone repo
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"
    
    log_info "Cloning repository..."
    git clone "$REPO_URL" repo
    cd repo
    
    # Create feature branch
    local branch="amp/bg-$(date +%s)"
    git switch -c "$branch"
    log_info "Created branch: $branch"
    
    # Main loop
    local attempt=1
    local error_log=""
    
    while [[ $attempt -le $MAX_ATTEMPTS ]]; do
        log_info "Starting attempt $attempt/$MAX_ATTEMPTS"
        
        # Generate prompt and get patch from Amp
        local prompt
        prompt=$(generate_prompt "$TASK" "$attempt" "$error_log")
        
        log_info "Requesting patch from Amp..."
        local patch
        if patch=$(echo "$prompt" | amp --non-interactive 2>/dev/null); then
            log_success "Received patch from Amp"
        else
            log_error "Failed to get patch from Amp"
            exit 1
        fi
        
        # Apply patch and commit
        if apply_and_commit "$patch" "$attempt"; then
            local sha
            sha=$(git rev-parse HEAD)
            
            # Push commit (unless dry run)
            if [[ "$DRY_RUN" == "false" ]]; then
                log_info "Pushing commit..."
                git push origin "$branch"
                log_success "Pushed SHA: $sha"
                
                # Poll CI status
                if poll_ci_status "$owner_repo" "$sha"; then
                    # CI passed - create PR
                    log_info "Creating pull request..."
                    local pr_url
                    pr_url=$(gh pr create -B "$BASE_BRANCH" -H "$branch" -t "Amp: $TASK" -b "Automated changes by Amp CI-Feedback Loop Agent

Task: $TASK
Attempts: $attempt
Final SHA: $sha" 2>/dev/null || echo "")
                    
                    if [[ -n "$pr_url" ]]; then
                        log_success "Pull request created: $pr_url"
                    else
                        log_warning "Failed to create pull request, but changes are ready on branch: $branch"
                    fi
                    
                    log_success "Task completed successfully!"
                    exit 0
                else
                    # CI failed - capture error log for next attempt
                    error_log=$(fetch_ci_logs "$owner_repo" "$(gh api "/repos/$owner_repo/actions/runs?head_sha=$sha" | jq -r '.workflow_runs[0].id')")
                fi
            else
                log_info "Dry run mode - skipping push and CI check"
                log_success "Patch would be applied successfully"
                exit 0
            fi
        else
            log_error "Failed to apply patch on attempt $attempt"
        fi
        
        ((attempt++))
    done
    
    log_error "Failed to complete task after $MAX_ATTEMPTS attempts"
    exit 1
}

# Cleanup on exit
cleanup() {
    if [[ -d "$WORK_DIR" ]]; then
        log_info "Cleaning up working directory: $WORK_DIR"
        rm -rf "$WORK_DIR"
    fi
}
trap cleanup EXIT

# Run main function
main "$@"
