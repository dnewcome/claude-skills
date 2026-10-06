# claude-skills

Personal Claude Code skills for maintaining the devlog/dnuke.com/wip-stream ecosystem.

These install globally into `~/.claude/skills/` and are available in every Claude Code session — unlike devlog-tools, which is vendored per-project. The skills here know about your specific infrastructure: dnuke.com paths, wip-stream conventions, UUID scheme.

## Install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/dnewcome/claude-skills/main/install.sh)
```

Pin to a tag:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/dnewcome/claude-skills/main/install.sh) --tag v1.0
```

## Skills

### `init-project`

Scaffold `.project.toml` for a new project — generates a stable UUID, sets up publish config pointing at dnuke.com. Run this before `devlog-tools install` when starting a new project, or to add publish config to an existing one.

### `check-pipeline`

Verify a project is correctly wired: UUID present, devlog-tools installed, git hook in place, publish target resolves. Useful after cloning on a new machine or after an upgrade.

### `add-project`

Add a static project page to dnuke.com for art installations, offline work, or anything without a GitHub repo. Synced GitHub repos are handled automatically by `sync-projects.sh`.

### `move-project`

Relocate a project across all three places it lives at once: its GitHub owner (user↔org transfer), its local folder under `~/sandbox/…`, and its Claude Code session history + memory under `~/.claude/projects/` (so `/resume` still works). Also fixes hardcoded absolute paths that break after a move. The three moves are independent — it does only the ones you ask for and offers the rest. Handles the self-move gotcha (relocating the folder you're running from) and the project-dir name encoding.

## Relationship to devlog-tools

| | devlog-tools | claude-skills |
|---|---|---|
| Install target | `scripts/`, `.claude/commands/` per-project | `~/.claude/skills/` global |
| Versioned per-project | yes | no |
| Knows about your infrastructure | no | yes |
| Handles | snap, preview, publish | bootstrap, verify, cross-project ops |

See [devlog-tools](https://github.com/dnewcome/devlog-tools) for the vendored project tooling.
