# Skills for Dev Planner.
#
# Format: one skills.sh URL per line. Lines starting with `#` are ignored.
# The create script derives the skill name from the last path segment of
# each URL and reuses it if already installed in the workspace, otherwise
# imports via `multica skill import --url <url>`.
#
# Bare skill names are accepted as a fallback for skills that do not yet
# have a public skills.sh URL.

# --- Process discipline -------------------------------------------------
# Clarify the problem before designing. A planner that skips brainstorming
# produces plans that solve the wrong problem.
https://skills.sh/obra/superpowers/brainstorming

# The canonical structure for implementation plans — phases, tasks,
# acceptance criteria, rollout. Drives how design.md and plan.md are shaped.
https://skills.sh/obra/superpowers/writing-plans

# How to run a plan in a fresh execution session with review checkpoints.
# The planner references this when describing how each sub-issue should be
# picked up by the assigned agent.
https://skills.sh/obra/superpowers/executing-plans

# Decomposition patterns: when to split work into parallelizable sub-tasks
# vs sequential dependencies. Informs sub-issue ordering.
https://skills.sh/obra/superpowers/subagent-driven-development
https://skills.sh/obra/superpowers/dispatching-parallel-agents

# TDD discipline so the integration-test proposal isn't a bolt-on.
https://skills.sh/obra/superpowers/test-driven-development

# Close the loop — verify before marking plan complete or handing off.
https://skills.sh/obra/superpowers/verification-before-completion

# The planner routinely asks other agents to review its plan before
# execution starts.
https://skills.sh/obra/superpowers/requesting-code-review

# --- Platform integration ----------------------------------------------
# Custom workspace skill — no public skills.sh URL yet. Pushed separately
# via `./scripts/push-skill.sh skills/multica-cli`. The planner uses the
# multica CLI to list available agents, create sub-issues, and assign them.
multica-cli
