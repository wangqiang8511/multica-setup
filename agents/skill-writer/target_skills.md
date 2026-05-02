# Skills for Skill Writer.
#
# Format: one skills.sh URL per line. Lines starting with `#` are ignored.
# The create script derives the skill name from the last path segment of
# each URL and reuses it if already installed in the workspace, otherwise
# imports via `multica skill import --url <url>`.
#
# Bare skill names are accepted as a fallback for skills that do not yet
# have a public skills.sh URL.

# Core writing discipline — the source of truth for skill structure,
# frontmatter, and verification steps.
https://skills.sh/obra/superpowers/writing-skills

# Search installed and published skills so we don't duplicate existing ones.
https://skills.sh/vercel-labs/skills/find-skills

# Clarify intent before writing — catches ambiguous tool-docs / repo inputs.
https://skills.sh/obra/superpowers/brainstorming

# Run the skill through a realistic scenario before handing off.
https://skills.sh/obra/superpowers/verification-before-completion
