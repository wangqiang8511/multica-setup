# Agents

Each subdirectory in `agents/` defines one Multica agent. The `_template/`
directory is the starting point — copy it, fill in the fields, open a PR,
then run the create script.

## Directory layout

```
agents/
  <agent-name>/
    instructions.md       # required — becomes the agent's `instructions` field
    target_skills.md      # required — list of skills.sh URLs (one per line)
    config.env            # optional — KEY=VALUE env vars (becomes custom_env)
    custom_args.json      # optional — JSON array of CLI args (becomes custom_args)
    agent.yaml            # required — name, description, model, visibility, etc.
```

The `agent.yaml` carries the static metadata the CLI needs:

```yaml
name: Agent Builder
description: Builds other agents
model: ""                 # leave empty if passing --model via custom_args
visibility: private       # private | workspace
max_concurrent_tasks: 6
```

## Workflow

1. **Scaffold** — `cp -r agents/_template agents/<new-agent>` and edit the files.
2. **Draft instructions** — write `instructions.md`. Include identity, working
   style, and constraints.
3. **List skills** — in `target_skills.md`, list one `skills.sh` URL per line.
   URLs are the portable, preferred form; the script derives the skill name
   from the last path segment and reuses an already-installed skill by that
   name, otherwise it imports via `multica skill import --url <url>`.
   Bare skill names are accepted as a fallback for skills that do not yet
   have a public skills.sh URL. Lines starting with `#` are comments.
4. **Runtime config** — populate `config.env` and `custom_args.json` if the
   agent needs specific env vars (e.g. `CLAUDE_CODE_USE_BEDROCK=1`) or CLI
   flags.
5. **PR review** — open a pull request against `main`. Only merged agents get
   created in Multica.
6. **Create / update** — run the interactive script:

   ```bash
   ./scripts/create-agent.sh agents/<new-agent>
   ```

   The script will:

   - Let you pick the target **workspace** from the workspaces you belong to
     (or pass `--workspace <id|name>` to skip the prompt). The chosen
     workspace is printed and scopes every subsequent `multica` call, so
     the agent is always created exactly where you confirmed.
   - Let you pick a runtime from the online runtimes in that workspace.
   - Import any skills from `target_skills.md` that are not yet in the
     workspace (`multica skill import --url ...`).
   - Create the agent if it does not exist, or update it if an agent with the
     same `name` already does.
   - Assign the listed skills to the agent.

## Conventions

- **Names are identity.** `agent.yaml.name` is how the script finds an
  existing agent to update. Do not rename without manually archiving the old
  one first.
- **Secrets don't live here.** `config.env` is for non-sensitive config — it
  is committed to git. For real secrets, set them directly on the agent in
  the Multica web UI, or pipe a JSON object into
  `multica agent update <id> --custom-env-stdin` after creation.
- **CLI requirement.** Applying `config.env` needs `multica` >= 0.2.23
  (adds `--custom-env-stdin`). On older CLIs the script aborts with an
  upgrade hint rather than silently dropping the env.
- **Skills are portable.** Prefer `skills.sh` URLs over custom skills so the
  definition works on any workspace.
