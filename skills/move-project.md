---
name: move-project
description: Move a project to a new GitHub owner (user↔org) and/or a new local folder, AND carry its Claude Code session history + memory along so `/resume` still works. Use when the user says "move this to the <org> org", "rename/relocate this repo", "move the local folder and session too", or otherwise relocates a project. Handles the three coupled moves at once — GitHub owner, on-disk folder, and the `~/.claude/projects/<munged-cwd>` session dirs — plus the hardcoded-absolute-path fixups that break after a move.
argument-hint: [new github owner and/or new local path — e.g. "punkfab, keep the name"]
allowed-tools: Read, Edit, Bash, Glob, Grep
---

The north star: **a "project" is three things that must move together — the GitHub repo, the local
folder, and the Claude session history under `~/.claude/projects/`.** Move one and forget the others
and you get a repo whose remote 404s, renders that write to a dead path, or a `/resume` that finds
nothing. This skill moves all three atomically-enough and leaves you able to relaunch cleanly.

There are up to **three independent moves**; do only the ones the user asked for:
1. **GitHub owner** (`dnewcome/foo` → `punkfab/foo`) — a repo transfer.
2. **Local folder** (e.g. `~/sandbox/dnewcome/foo` → `~/sandbox/<somewhere>/foo`) — a `mv`.
3. **Session history** (`~/.claude/projects/-home-...-dnewcome-foo*`) — directory renames so history + memory survive.

**The three are INDEPENDENT — never infer one from another.** In particular the local folder's
destination is **not** "the GitHub owner" — local trees are often grouped by *theme* (`~/sandbox/audio/…`,
`~/sandbox/robots/…`), not by GitHub org, so a repo can live under org `punkfab` on GitHub while its
folder belongs under `~/sandbox/audiodestrukt/`. Moving the GitHub owner tells you **nothing** about where
the folder goes. Always get the local target as its own explicit answer (Step 0), and if the user named
only one of the three moves, do that one and *offer* the others — don't assume they travel together.

## THE self-move gotcha (read first)

You are almost always running this **from inside the folder being moved**, in a session whose transcript
lives in the very project dir you're about to rename. That's fine if you order it right:

- Renaming a directory that holds open file descriptors is safe on Linux — the running process keeps
  writing. But the harness re-derives its project dir from the launch **cwd path** on later turns, and
  that path is gone after the `mv`. So the **active session cannot cleanly continue after step 2/3.**
- Therefore: do all the **irreversible GitHub work + path fixups FIRST** (steps 1–3 below), verify them,
  and only **then** do the folder move + project-dir renames as the **last actions**, from a neutral cwd
  (`cd /`). Print a full verification report in that same command.
- End by telling the user: **relaunch `claude` from the new path and `/resume`** — the renamed project
  dir contains this session, so resume finds the whole history and memory.

Never try to run more tool calls after you've moved the current cwd out from under yourself — they fail.

## Step 0 — Gather (read-only)

```bash
OLD_ABS="$(pwd)"                                   # e.g. /home/dan/sandbox/dnewcome/flexisette
OLD_URL="$(git remote get-url origin 2>/dev/null)"
REPO="$(basename "$OLD_ABS")"
# munged project-dir name = leading dash + path with every "/" -> "-"
munge() { printf '%s' "$1" | sed 's#[^A-Za-z0-9]#-#g'; }   # EVERY non-alnum -> '-' (so '/', '.', ' ', '&' all map). Claude Code encodes project-dir names this way: '/home/dan/x.com' -> '-home-dan-x-com', '.claude' -> '-claude'. A naive '/'-only munge mis-names any dir with a dot/space and breaks /resume.
OLD_MUNGE="$(munge "$OLD_ABS")"
ls -d ~/.claude/projects/"$OLD_MUNGE"* 2>/dev/null   # base + any subdir-scoped session dirs
```
Confirm with the user: **new owner** (org or user), the **new local absolute path** (ASK — do not derive
it from the owner or "swap the owner segment"; the user's local grouping may be thematic, so get the real
target even if it seems obvious), and whether the **repo name** changes. Then check the targets are free
and permitted:
```bash
gh repo view <new_owner>/<repo>            # want: 404 (does not exist yet)
gh api orgs/<new_owner>/memberships/$(gh api user --jq .login) --jq '.role+" / "+.state'   # need admin/member with create rights
ls -d <new_parent>/<repo> 2>/dev/null      # want: empty (no local collision)
ls -d ~/.claude/projects/$(munge <new_abs>)* 2>/dev/null   # want: empty (no session-dir collision)
```

## Step 1 — GitHub owner (only if the owner changes)

A **transfer** is the right primitive: it preserves history, issues, PRs, stars, and installs a redirect
from the old URL. Recreate-and-push only if transfer is refused (e.g. no create rights in the target org).
```bash
gh api repos/<old_owner>/<repo>/transfer -f new_owner=<new_owner>
# transfer is async — poll until it resolves, then repoint the local remote to the canonical URL:
until gh repo view <new_owner>/<repo> >/dev/null 2>&1; do sleep 2; done
git remote set-url origin git@github.com:<new_owner>/<repo>.git
```
Requires: **admin on the repo** + **create-repo permission in the target org**, and **no name collision**
in the target. A rename (name change) uses `gh repo rename <new>` instead / as well.

## Step 2 — Fix hardcoded absolute paths (only if the local folder moves)

Repos often bake the absolute repo root into scripts, docs, render output paths, configs. These break
silently after the `mv`. Find and rewrite them **before** moving:
```bash
git grep -l -F "$OLD_ABS"                 # tracked files that hardcode the old root
grep -rlF "$OLD_ABS" --exclude-dir=.git . # also catch untracked scripts
# rewrite each (text files only; skip binaries like PNGs whose metadata will regenerate):
git grep -lI -F "$OLD_ABS" | xargs -r sed -i "s#$OLD_ABS#<new_abs>#g"
```
These edits land in the working tree as **uncommitted changes** — tell the user; let them review + commit.
Also check owner-specific plumbing: `.project.toml` / devlog pipeline (see the check-pipeline skill), CI
badges, README clone URLs, and any config that names the old `owner/repo`.

## Step 3 — Verify the reversible-so-far state

Before the point of no return, confirm: `git remote -v` shows the new owner, `gh repo view <new>/<repo>`
resolves, and `git grep -F "$OLD_ABS"` is now empty. Good — proceed.

## Step 4 — Move folder + session dirs (LAST, from a neutral cwd, in ONE command)

Do this as a single `Bash` call that ends with a verification printout, because the session likely can't
continue afterward:
```bash
cd /                                                  # leave the folder you're about to move
mkdir -p <new_parent>
mv "<OLD_ABS>" "<new_abs>"                             # the local folder (working-tree changes ride along)

# rename EVERY session dir sharing the old munged prefix (base + subdir-scoped ones):
NEW_MUNGE="$(printf '%s' '<new_abs>' | sed 's#[^A-Za-z0-9]#-#g')"   # every non-alnum -> '-' (see munge() note in Step 0)
for d in ~/.claude/projects/"<OLD_MUNGE>"*; do
  [ -e "$d" ] || continue
  b="$(basename "$d")"; nb="${b/<OLD_MUNGE>/$NEW_MUNGE}"
  mv "$d" ~/.claude/projects/"$nb"
done

echo "=== VERIFY ==="; git -C "<new_abs>" remote -v
ls -d "<new_abs>"; ls -d ~/.claude/projects/"$NEW_MUNGE"*
```
(The `memory/`, `tool-results/`, and `*.jsonl` transcripts inside each project dir ride along in the
rename — that's what makes `/resume` and persisted memory keep working under the new path.)

## Step 5 — Hand off

Report what moved (owner, folder, N session dirs), note any uncommitted path fixups, and tell the user:
> This session's working dir has moved. **Relaunch `claude` from `<new_abs>` and `/resume`** to continue
> with full history + memory intact.

## Gotchas (hard-won)

- **Transfer is async** — poll `gh repo view` before `git remote set-url`; the URL 404s for a beat.
- **Old URLs redirect** after transfer, so nothing breaks immediately — but repoint `origin` to the
  canonical URL anyway, and update anyone else's clones / CI / submodules that pin the old owner.
- **Path munging rule:** project-dir name = leading `-` then the abs cwd with every `/` → `-`. Each
  directory you launched `claude` from has its **own** dir (`…-foo`, `…-foo-cad`, `…-foo-sim-x`) — the
  `<OLD_MUNGE>*` glob catches them all. Rename with the same prefix substitution so the tails match the
  new subdir paths.
- **Don't rename the active project dir and then keep working** — open FDs survive the rename, but the
  next turn's path re-derivation won't. Make it the last thing you do, then hand off for a relaunch.
- **`mv` across filesystems** still works (copy+unlink) but is slow for big session dirs (100s of MB of
  tool-results); expect a pause, not an error.
- **Secrets never travel in-repo** — API keys live outside the tree (e.g. `~/.config/*.env`, chmod 600)
  and are unaffected by the move; don't try to "bring them along."
- **Uncommitted work rides along** with the folder `mv` (it's the same working tree) — but it's still
  uncommitted; if the user wanted it committed, that's a separate ask.
