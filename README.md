# Claude Code Project Template

Reusable infrastructure for running [Claude Code](https://claude.ai/code) on projects — locally and on a remote server inside Docker containers.

## What's Included

| Directory | Purpose |
|-----------|---------|
| `.claude/settings.json` | Permissions + Stop hook with project-named notifications |
| `.claude/rules.txt` | Methodology rules injected into every prompt (TDD, commits, etc.) |
| `.claude/commands/` | Slash commands: `/pm`, `/review`, `/plan`, `/tdd`, `/deploy`, `/roadmap`, `/status` |
| `.claude/agents/` | Subagents: `pm-orchestrator` (work sessions), `qa-reviewer` (quality checks) |
| `.devcontainer/` | Docker container for remote Claude Code server |
| `PLAN.md` | Work plan stub (maintained by Claude during sessions) |
| `roadmap.md` | Task tracker stub |

## Quick Start

```bash
# Clone this template repo
git clone https://github.com/gkufera/claude-project-template.git ~/claude-project-template

# Go to your project
cd ~/Work/my-project

# Initialize Claude Code infrastructure
~/claude-project-template/init-claude.sh "My Project Name"

# Or with a custom test command:
~/claude-project-template/init-claude.sh "My Project Name" "cd frontend && npm test && cd ../backend && npm test"
```

The init script copies template files into your project and substitutes `{{PROJECT_NAME}}` and `{{TEST_COMMAND}}` placeholders.

## Template Variables

| Variable | Default | Used In |
|----------|---------|---------|
| `{{PROJECT_NAME}}` | *(required)* | Notification titles, agent prompts |
| `{{TEST_COMMAND}}` | `npm test` | Rules, deploy command, QA reviewer, PM orchestrator |

## Slash Commands

| Command | Purpose |
|---------|---------|
| `/pm` | Start a full work session (reads roadmap, picks task, executes with TDD) |
| `/review` | Run QA verification on recent work |
| `/plan` | Check current task and plan status |
| `/tdd` | Walk through test-first workflow step by step |
| `/deploy` | Run tests and deploy to production |
| `/roadmap` | Status report on roadmap.md priorities |
| `/status` | Quick project health dashboard |

## Methodology

The template enforces a strict development methodology via `.claude/rules.txt`:

- **TDD**: Failing test first, then implement, then verify
- **Granular commits**: After every logical step
- **PLAN.md**: Updated continuously as work progresses
- **No backwards compatibility code**: Projects aren't in production

## Customizing for Your Project

After running `init-claude.sh`:

1. **`.claude/rules.txt`** — Add project-specific rules (e.g., "never hard-delete records", "always use soft-delete")
2. **`.claude/settings.json`** — Add permissions for your stack's CLI tools (e.g., `Bash(cargo *)`, `Bash(python *)`)
3. **`roadmap.md`** — Add your project's tasks with P0/P1/P2 priorities
4. **`.devcontainer/init-firewall.sh`** — Add domains your project needs (e.g., your API host, database provider)

## Remote Server Setup

Claude Code runs on a remote server inside Docker containers — one per project. Each container has its own firewall, notifications, and isolated config.

### Prerequisites

- Linux server (Ubuntu recommended) with Docker installed
- SSH access configured
- The `~/cm` container manager script (see below)

### Server Layout

```
Server host (Ubuntu)
├── ~/cm                              # Container manager script
├── ~/workspace/<project>/            # Git repos (bind-mounted into containers)
├── ~/claude-configs/<project>/       # Per-project Claude configs
│   ├── .credentials.json             # Auth (synced from ~/.claude/)
│   └── settings.json                 # Overwritten by container on start
└── Docker containers (one per project)
    ├── /workspace                    # ← bind mount of ~/workspace/<project>
    ├── /home/node/.claude            # ← bind mount of ~/claude-configs/<project>
    └── tmux session "claude"         # Claude Code runs here
```

### Container Manager: `~/cm`

Single command to manage Claude containers:

```bash
~/cm a <project>     # Smart attach: starts if needed, restarts if crashed, then attaches
~/cm s <project>     # Start a new container
~/cm x <project>     # Stop and remove container
~/cm st              # Show status of all projects
~/cm l <project>     # Show container logs (last 50 lines)
~/cm r <project>     # Rebuild Docker image from .devcontainer/
```

**`~/cm a <project>` is the one command you need.** It handles:
1. Container not running → starts it → attaches
2. Container running but Claude crashed → restarts Claude → attaches
3. Everything running → just attaches

Multiple clients can attach simultaneously via tmux.

### Container Features

- **Base**: Node 20 with Claude Code, tmux, zsh, gh, AWS CLI, Railway CLI
- **Firewall**: Outbound restricted to: GitHub, npm, Anthropic API, ntfy.sh, Railway, Cloudflare, AWS (S3, SES, CloudFront, STS, IAM), PyPI
- **Notifications**: Push notifications via [ntfy.sh](https://ntfy.sh) with project name in the title
- **Config isolation**: Each project gets its own `~/claude-configs/<project>/` directory

### CLI Tools Available in Container

| Tool | Purpose | Firewall Access |
|------|---------|-----------------|
| `gh` | GitHub CLI (PRs, issues, actions, logs) | github.com (dynamic IPs via API) |
| `aws` | AWS CLI (S3, SES, CloudFront, IAM, STS) | s3.amazonaws.com, ses/email.us-east-1, cloudfront, sts, iam |
| `railway` | Railway CLI (deploy, logs, status) | railway.com, backboard.railway.com |
| `curl` | Cloudflare API, ntfy.sh, general HTTP | api.cloudflare.com, ntfy.sh |
| `npm` / `npx` | Node.js package management | registry.npmjs.org |
| `git` | Version control | github.com |

### Adding More Firewall Rules

Edit `.devcontainer/init-firewall.sh` to add domains:

```bash
# In the domain resolution loop, add your domain:
for domain in \
    ... \
    "your-api.example.com" \
    "your-database-provider.com"; do
```

For services with many IPs, add CIDR ranges:

```bash
# After the AWS CIDR block:
for cidr in \
    ... \
    "YOUR.CIDR/16"; do
```

### Per-Project Config Isolation

Each project gets its own `~/claude-configs/<project>/` directory mounted as `/home/node/.claude` inside the container. This means:

- Each project has its own `settings.json` (written by the container from `.devcontainer/claude-settings.json`)
- Auth credentials are synced from `~/.claude/.credentials.json` on each attach
- Two containers can run simultaneously without overwriting each other's settings

### Rebuilding After Changes

If you modify `.devcontainer/Dockerfile`, `notify.sh`, or `init-firewall.sh`:

```bash
~/cm x <project>     # Stop running container
~/cm r <project>     # Rebuild image
~/cm a <project>     # Start fresh and attach
```

## Notifications (ntfy.sh)

Push notifications via [ntfy.sh](https://ntfy.sh) alert you when Claude needs input or finishes a task.

### How It Works

The `notify.sh` script does a `curl` POST to `ntfy.sh/<topic>` with the project name as the title. Subscribe to the topic on your phone/laptop via the ntfy app.

### Hook Configuration

| Hook | Where | Purpose |
|------|-------|---------|
| **Notification** | Container (`claude-settings.json`) | Claude needs input (idle, permission prompt) |
| **Stop** | Local (`.claude/settings.json`) + Container | Claude finished a task |
| **UserPromptSubmit** | Container (`claude-settings.json`) | Injects rules.txt into every prompt |
| **PreCompact** | Container (`claude-settings.json`) | Re-reads rules before context compaction |

### Paths Per Environment

| Environment | notify.sh path | Settings source |
|-------------|----------------|-----------------|
| **Local Mac** | `~/.claude/notify.sh` | `.claude/settings.json` |
| **Server container** | `/usr/local/bin/notify.sh` | `.devcontainer/claude-settings.json` |

### Setting Up Local Notifications

Copy `notify.sh` to your home directory:

```bash
cp .devcontainer/notify.sh ~/.claude/notify.sh
chmod +x ~/.claude/notify.sh
```

Edit the `NTFY_TOPIC` variable in `~/.claude/notify.sh` to your private topic name.

## Container Manager Script (`~/cm`)

Install the container manager on your server:

```bash
# Copy cm to the server
scp cm your-server:~/cm
chmod +x ~/cm
```

See the `cm` file in this repo for the full script. Key features:

- Manages multiple projects simultaneously
- Per-project Docker images built from each project's `.devcontainer/`
- Per-project config directories for auth isolation
- Auto-syncs credentials on attach
- tmux-based session management
