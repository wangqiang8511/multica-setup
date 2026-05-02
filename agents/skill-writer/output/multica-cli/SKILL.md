---
name: multica-cli
description: Use when interacting with the Multica platform from a coding agent — reading/writing issues, posting comments, managing agents, autopilots, skills, and repos via the `multica` CLI. Triggers: task assigned via Multica issue, need to post a result comment, read workspace state, or manage platform resources.
---

# multica-cli

## Overview

`multica` is the CLI for the Multica agent platform. Coding agents use it to read task context, post results, and manage workspace resources. **All platform interactions must go through `multica` — never use `curl` or HTTP clients directly.**

## Quick Reference

### Read Operations (always use `--output json`)

```bash
multica issue get <id> --output json                          # Issue details
multica issue list [--status X] [--assignee X] --output json  # List issues (default limit 50)
multica issue comment list <id> [--since <RFC3339>] --output json  # Comments (paginate with --limit/--offset)
multica workspace get --output json                           # Workspace context
multica workspace members [workspace-id] --output json        # Members list
multica agent list --output json                              # Agents in workspace
multica autopilot list [--status X] --output json             # Autopilots
multica skill list --output json                              # Skills in workspace
multica issue runs <id> --output json                         # Execution history
multica issue run-messages <task-id> [--since <seq>] --output json  # Run messages
```

### Write Operations

```bash
# Issues
multica issue create --title "..." [--description "..."] [--assignee X] [--status X]
multica issue assign <id> --to <name>           # Assign to member or agent
multica issue status <id> <status>              # todo|in_progress|in_review|done|blocked
multica issue update <id> [--title X] [--description X] [--priority X]

# Comments
multica issue comment add <issue-id> --content "..."
multica issue comment add <issue-id> --parent <comment-id> --content "..."   # Reply
cat <<'EOF' | multica issue comment add <issue-id> --content-stdin  # Stdin for special chars
content with `backticks` and "quotes"
EOF
multica issue comment delete <comment-id>

# Agents
multica agent create --name "..." --runtime-id <id> [--model <model>] [--instructions "..."]
multica agent update <id> [--name X] [--instructions X] [--model X]
multica agent skills set <id> --skills <skill-id,...>

# Autopilots
multica autopilot create --title "..." --agent <name> --mode create_issue
multica autopilot trigger-add <id> --cron "0 9 * * 1"   # Add cron schedule
multica autopilot update <id> [--status active|paused]
multica autopilot trigger <id>                            # Manually trigger once

# Skills
multica skill import --url <skills.sh-url>
multica skill create --name "..." --content "..."
multica skill update <id> [--content X] [--name X]
multica skill files upsert <skill-id> --name <filename> --content "..."

# Repos
multica repo checkout <url>   # Creates git worktree with dedicated branch
```

## Mention Links

Post results as comments — terminal output is NOT visible to users.

```markdown
[MUL-123](mention://issue/<issue-id>)      # Clickable issue link (no side effect)
[@Name](mention://member/<user-id>)        # Notifies a human (use sparingly)
[@Agent](mention://agent/<agent-id>)       # Enqueues a new agent run (causes re-trigger!)
```

**Warning:** Agent mentions create new runs — avoid in sign-offs to prevent loops.

## Key Patterns

### Agent Workflow Pattern

```bash
# 1. Read issue context
multica issue get <id> --output json

# 2. Read conversation (paginate if large)
multica issue comment list <id> --limit 30 --output json

# 3. Do the work...

# 4. Post result (mandatory — users only see comments)
multica issue comment add <id> --parent <trigger-comment-id> --content "Done. ..."
```

### Pagination

`issue list` and `issue comment list` support `--limit` / `--offset`. Check `has_more` in JSON output to paginate:

```bash
multica issue list --limit 50 --offset 0 --output json   # page 1
multica issue list --limit 50 --offset 50 --output json  # page 2
```

### Repo Checkout

```bash
multica repo checkout /path/to/local/repo    # or remote URL
# Returns: /path/to/worktree (branch: agent/<name>/<hash>)
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Forgetting `--output json` on reads | Always add it — table format drops fields |
| Using `curl` against Multica URLs | Use `multica` — URLs require CLI auth |
| Not posting a result comment | Users don't see terminal output — always comment |
| Mentioning agent in sign-off | Causes loop — omit `@mention` when wrapping up |
| Losing content with backticks/quotes | Use `--content-stdin` with heredoc |

## Limitations

- `multica autopilot create` only supports `--mode create_issue` (run_only not yet supported end-to-end)
- `multica runtime update` initiates a CLI update on the runtime (no remote code execution)
- `multica attachment download` downloads to current directory; use `-o <dir>` to redirect
