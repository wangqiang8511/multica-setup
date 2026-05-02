# Skills for Agent Builder.
#
# Format: one skills.sh URL per line. Lines starting with `#` are ignored.
# The create script derives the skill name from the last path segment of
# each URL and reuses it if already installed in the workspace, otherwise
# imports via `multica skill import --url <url>`.
#
# Bare skill names are also accepted as a fallback for skills that do not
# yet have a public skills.sh URL.

https://skills.sh/vercel-labs/skills/find-skills
https://skills.sh/obra/superpowers/writing-skills

# Custom workspace skill — no public skills.sh URL yet. Pushed separately via
# `./scripts/push-skill.sh skills/multica-cli`; referenced here by bare name
# so create-agent.sh picks it up from the workspace's skill list.
multica-cli
