# multica CLI Reference

Version: 0.2.16 | Source: `multica --help` / `multica <cmd> --help`

## Global Flags

```
--profile string        Config profile (isolates state per project)
--server-url string     Override server URL (env: MULTICA_SERVER_URL)
--workspace-id string   Set workspace (env: MULTICA_WORKSPACE_ID)
```

## issue

### list
```
--assignee string   Filter by assignee name
--limit int         Max results (default 50)
--offset int        Skip N results (pagination)
--output string     table|json (default table)
--priority string   Filter by priority
--project string    Filter by project ID
--status string     Filter by status
```
JSON output includes `total` and `has_more` for pagination.

### get
```
multica issue get <id> --output json
```

### create
```
--title string         (required)
--description string
--assignee string
--attachment strings   File paths (repeatable)
--due-date string      RFC3339 format
--parent string        Parent issue ID
--priority string      none|low|medium|high|urgent
--project string
--status string
```

### update
```
--title string
--description string
--assignee string
--due-date string      (use "" to clear)
--parent string        (use "" to clear)
--priority string
--project string
--status string
```

### assign
```
multica issue assign <id> --to <name>
multica issue assign <id> --unassign
```

### status
```
multica issue status <id> <status>
# Values: todo, in_progress, in_review, done, blocked
```

### search
```
multica issue search <query> [--include-closed] [--limit 20]
```

### comment add
```
--content string       Comment text (or use --content-stdin)
--content-stdin        Read from stdin (avoids shell escaping)
--parent string        Parent comment ID (thread reply)
--attachment strings   File paths (repeatable)
```

### comment list
```
--limit int     Max results (0 = all)
--offset int    Skip N (pagination)
--since string  RFC3339 timestamp — only newer comments
```

### runs / run-messages
```
multica issue runs <issue-id> --output json
multica issue run-messages <task-id> [--since <seq>] --output json
```

## agent

### create
```
--name string                  (required)
--runtime-id string            (required)
--model string                 e.g. claude-sonnet-4-6, openai/gpt-4o
--description string
--instructions string
--max-concurrent-tasks int32   default 6
--visibility string            private|workspace
--custom-args string           JSON array of CLI args
--runtime-config string        JSON string
```

### update
```
--name / --description / --instructions / --model / --status
--max-concurrent-tasks / --visibility / --runtime-id
--custom-args / --runtime-config
```
Pass empty string for --model to fall back to runtime default.

### skills
```
multica agent skills list <agent-id> --output json
multica agent skills set <agent-id> --skills <id1,id2,...>
```

## autopilot

### create
```
--title string                  (required)
--agent string                  Agent name or ID (required)
--mode string                   create_issue (required; run_only not yet supported)
--description string            Used as task prompt
--issue-title-template string   Template for created issue titles
--priority string               none|low|medium|high|urgent (default none)
--project string
```

### trigger-add
```
multica autopilot trigger-add <id> --cron "0 9 * * 1" [--label "..."] [--timezone "America/New_York"]
```

### trigger-update / trigger-delete
```
multica autopilot trigger-update <trigger-id> [--cron X] [--label X] [--timezone X]
multica autopilot trigger-delete <trigger-id>
```

### update
```
--title / --description / --agent / --mode / --project
--issue-title-template / --priority
--status string   active|paused
```

### runs
```
multica autopilot runs <id> [--limit N] --output json
```

## skill

```
multica skill list --output json
multica skill get <id> --output json               # includes files
multica skill create --name "..." --content "..." [--description "..."] [--config JSON]
multica skill update <id> [--name X] [--content X] [--description X] [--config JSON]
multica skill delete <id>
multica skill import --url <clawhub.ai-or-skills.sh-url>
multica skill files list <skill-id> --output json
multica skill files upsert <skill-id> --name <filename> --content "..."
multica skill files delete <skill-id> --name <filename>
```

## workspace

```
multica workspace get [workspace-id] --output json
multica workspace list --output json
multica workspace members [workspace-id] --output json
```

## runtime

```
multica runtime list --output json
multica runtime usage <runtime-id> [--days 90] --output json
multica runtime activity <runtime-id> --output json
multica runtime update <runtime-id>    # Initiates CLI update on the runtime
```

## repo

```
multica repo checkout <url>
# Returns local path; creates git worktree on branch agent/<name>/<hash>
```

## attachment

```
multica attachment download <id> [-o <dir>]
```

## daemon

```
multica daemon start
multica daemon stop
multica daemon restart
multica daemon status
multica daemon logs
```

## auth / config

```
multica auth status
multica auth logout
multica config     # Manage CLI configuration
multica login      # Authenticate + set up workspaces
multica setup      # Configure CLI, authenticate, start daemon
multica update     # Update multica binary
multica version    # Print version info
```
