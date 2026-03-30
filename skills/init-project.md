---
name: init-project
description: Scaffold or update .project.toml for a project, wiring it into the devlog/dnuke.com pipeline with a stable UUID and publish config. Use when starting a new project or when .project.toml is missing or incomplete.
argument-hint: [project-name]
allowed-tools: Read, Write, Bash
---

Create or update `.project.toml` for this project, wiring it into the devlog/dnuke.com/wip-stream pipeline.

## Steps

1. Read the current directory name as the default project name.
2. Check if `.project.toml` already exists. If it does, read it and show the user what's already there before making any changes.
3. Determine the project UUID:
   - If `.project.toml` already has a `uuid`, keep it unchanged.
   - Otherwise generate one with `python3 -c "import uuid; print(uuid.uuid4())"`.
4. Ask the user (or infer from context) for:
   - `name` — human-readable project name (default: directory name)
   - `description` — one sentence
   - `devlog_tag` — the tag used when publishing entries to dnuke.com (default: slugified project name)
   - `devlog_dest` — relative path from this repo to the dnuke.com posts directory (default: `../dnuke.com/src/blog/posts`)
5. Write `.project.toml` with this structure:

```toml
[project]
uuid = "<uuid>"
name = "<name>"
description = "<description>"

[publish]
devlog_tag = "<devlog_tag>"
devlog_dest = "<devlog_dest>"
```

   If a `[devlog]` section already exists (written by devlog-tools install), preserve it.

6. If devlog-tools is not yet installed (no `scripts/devsnap.sh`), suggest running:
   ```bash
   bash <(curl -fsSL https://raw.githubusercontent.com/dnewcome/devlog-tools/main/install.sh) --tag v1.0
   ```

7. Report what was created or updated.
