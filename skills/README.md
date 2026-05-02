# Skills

Custom skills that live in this repo and are pushed into a Multica workspace
via `scripts/push-skill.sh`.

Most agents should pull standard skills directly from [skills.sh](https://skills.sh)
via `target_skills.md`. This folder is for **custom** skills that don't live
on skills.sh — typically early drafts, private logic, or workspace-specific
helpers.

## Directory layout

```
skills/
  <skill-name>/
    SKILL.md              # required — frontmatter + body
    <any other files>     # optional — uploaded via `multica skill files upsert`
```

`SKILL.md` must start with a YAML frontmatter block:

```markdown
---
name: my-skill-name
description: One-line description that predicts when the skill should fire.
---

# Body of the skill goes here…
```

- `name` is the update-lookup key. If a skill with the same name already
  exists in the target workspace, the script updates it in place.
- `description` shapes when agents pick the skill up — write it as an
  instruction to the caller ("Use this when…").

Any additional files in the directory (scripts, references, templates) are
uploaded as skill files, preserving their relative paths.

## Workflow

1. **Scaffold** — `cp -r skills/_template skills/<new-skill>` and edit
   `SKILL.md`. Add any supporting files alongside it.
2. **PR review** — open a pull request against `main`. Only merged skills
   get pushed.
3. **Push** — run the interactive script:

   ```bash
   ./scripts/push-skill.sh skills/<new-skill>
   ```

   The script will:

   - Let you pick the target **workspace** (or pass `--workspace <id|name>`
     to skip the prompt). The chosen workspace is printed and scopes every
     subsequent `multica` call.
   - Create the skill if none with the same `name` exists, or update it if
     one does.
   - Upload every supporting file under the skill directory via
     `multica skill files upsert`, preserving relative paths.
   - With `--prune`, delete any remote files that are no longer present
     locally.

### Flags

- `--workspace <id|name>` — non-interactive workspace selection.
- `--dry-run` — print what would happen without calling the API.
- `--yes` — skip the final confirmation prompt.
- `--prune` — delete remote files that aren't in the local directory
  (use after removing or renaming files).

## Conventions

- **Names are identity.** The `name` field in the SKILL.md frontmatter is
  how the push script finds an existing skill to update. Do not rename
  without first archiving or deleting the old one.
- **Keep descriptions honest.** The description is what agents see when
  deciding whether to invoke the skill. Vague descriptions make it fire
  too often or not at all.
- **Prefer skills.sh for shared skills.** If a skill would be useful
  across workspaces, publish it to skills.sh and reference it via
  `target_skills.md` instead of vendoring it here.
