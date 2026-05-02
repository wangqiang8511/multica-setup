# MetaSetup

A repo for defining and bootstrapping Multica agents in a repeatable way.

Each agent lives under `agents/<agent-name>/` and is described by three files:

1. `instructions.md` — the agent's system instructions / working style / constraints.
2. `target_skills.md` — the skills the agent needs, listed as `skills.sh` URLs so they can be imported directly.
3. `config.env` + `custom_args.json` — optional runtime env vars and CLI args.

Agents are created in Multica by running the interactive script:

```bash
./scripts/create-agent.sh agents/<agent-name>
```

The script picks a runtime, imports any missing skills listed in `target_skills.md`, and calls `multica agent create` with the right flags. See [agents/README.md](agents/README.md) for the full workflow.

## Layout

```
agents/
  README.md             — workflow + conventions
  _template/            — starter layout for new agents
  agent-builder/        — reference agent (this project's own builder)
scripts/
  create-agent.sh       — interactive create/update
  lib/common.sh         — shared helpers
```

## Constraints

- This repo is the single source of truth for agent definitions on the MetaSetup project.
- Changes land via PR — never create agents ad-hoc against the API.
