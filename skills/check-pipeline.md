---
name: check-pipeline
description: Verify a project is correctly wired into the devlog/dnuke.com pipeline. Use when the user asks to check, verify, or diagnose their project setup.
allowed-tools: Read, Bash, Glob
---

Verify this project is correctly wired into the devlog/dnuke.com/wip-stream pipeline. Report what's present, what's missing, and what to do about it.

## Checks

Run through each item and report pass/fail with a brief note:

**Identity**
- [ ] `.project.toml` exists
- [ ] `[project]` has `uuid`, `name`, `description`
- [ ] `[publish]` has `devlog_tag` and `devlog_dest`

**devlog-tools**
- [ ] `[devlog]` section present in `.project.toml` (written by install.sh)
- [ ] `scripts/devsnap.sh` exists and is executable
- [ ] `scripts/devlog-preview.sh` exists and is executable
- [ ] `scripts/devpublish.sh` exists and is executable
- [ ] `scripts/install-hooks.sh` exists and is executable
- [ ] `.claude/commands/devsnap.md` exists
- [ ] `.git/hooks/post-commit` exists (note: not tracked in git, must be installed per-clone)

**devlog**
- [ ] `devlog/` directory exists
- [ ] At least one `.md` entry present (or note that it's a fresh project)

**publish target**
- [ ] Path referenced in `devlog_dest` resolves to an existing directory

## Output format

Group by section. For each failure, show a one-line fix command or instruction where possible. End with a summary: "N checks passed, M failed."
