#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/template"

usage() {
    echo "Usage: $0 [--force] <project-name> [test-command]"
    echo ""
    echo "Initialize Claude Code infrastructure in the current git repository."
    echo ""
    echo "Arguments:"
    echo "  project-name   Human-readable name shown in notifications (e.g., 'Slug Max')"
    echo "  test-command   Tier 1 test command (default: 'npm test')"
    echo ""
    echo "Options:"
    echo "  --force        Overwrite existing .claude/ and .devcontainer/ directories"
    echo ""
    echo "Examples:"
    echo "  $0 'My Project'"
    echo "  $0 'My Project' 'cd frontend && npm test && cd ../backend && npm test'"
    echo "  $0 --force 'My Project'"
    exit 1
}

# Parse --force flag
FORCE=false
if [ "${1:-}" = "--force" ]; then
    FORCE=true
    shift
fi

# Validate arguments
if [ $# -lt 1 ]; then
    usage
fi

PROJECT_NAME="$1"
TEST_COMMAND="${2:-npm test}"

# Check we're in a git repo
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Error: Not inside a git repository. Run this from your project root."
    exit 1
fi

# Check we're at the repo root
REPO_ROOT="$(git rev-parse --show-toplevel)"
if [ "$PWD" != "$REPO_ROOT" ]; then
    echo "Error: Run this from the git repository root ($REPO_ROOT)"
    exit 1
fi

# Check for existing directories
if [ "$FORCE" = false ]; then
    if [ -d ".claude" ]; then
        echo "Error: .claude/ already exists. Use --force to overwrite."
        exit 1
    fi
    if [ -d ".devcontainer" ]; then
        echo "Error: .devcontainer/ already exists. Use --force to overwrite."
        exit 1
    fi
fi

echo "Initializing Claude Code for '$PROJECT_NAME'..."

# Copy template files
cp -r "$TEMPLATE_DIR/.claude" .
cp -r "$TEMPLATE_DIR/.devcontainer" .
cp "$TEMPLATE_DIR/PLAN.md" .
cp "$TEMPLATE_DIR/roadmap.md" .

# Make scripts executable
chmod +x .devcontainer/notify.sh .devcontainer/init-firewall.sh

# Substitute template variables
# Use | as sed delimiter since project names won't contain |
find .claude .devcontainer PLAN.md roadmap.md -type f | while read -r file; do
    if file "$file" | grep -q text; then
        sed -i '' "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g" "$file" 2>/dev/null || \
        sed -i "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g" "$file"
        sed -i '' "s|{{TEST_COMMAND}}|${TEST_COMMAND}|g" "$file" 2>/dev/null || \
        sed -i "s|{{TEST_COMMAND}}|${TEST_COMMAND}|g" "$file"
    fi
done

echo ""
echo "Initialized Claude Code for '$PROJECT_NAME'."
echo ""
echo "Created:"
echo "  .claude/          — Settings, rules, slash commands, agents"
echo "  .devcontainer/    — Docker container config for remote server"
echo "  PLAN.md           — Work plan (updated by Claude)"
echo "  roadmap.md        — Task tracker"
echo ""
echo "Next steps:"
echo "  1. Edit .claude/rules.txt to add project-specific rules"
echo "  2. Edit roadmap.md to add your tasks"
echo "  3. Review .claude/settings.json permissions for your stack"
echo "  4. If using a remote server, review .devcontainer/ configs"
echo "  5. Copy ~/.claude/notify.sh to your machine (for local notifications)"
