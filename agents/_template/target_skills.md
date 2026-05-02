# Skills for this agent.
#
# Format: one skills.sh URL per line. Lines starting with `#` are ignored.
#
# Example:
#   https://skills.sh/vercel-labs/skills/find-skills
#   https://skills.sh/obra/superpowers/writing-skills
#
# Find URLs via https://skills.sh or `https://skills.sh/api/search?q=<name>`.
#
# The create script derives the skill name from the last path segment of
# each URL. If a skill with that name is already installed in the workspace
# it is reused; otherwise it is imported with
#   multica skill import --url <url>
#
# Bare skill names are also accepted as a fallback for skills that do not
# yet have a public skills.sh URL.
