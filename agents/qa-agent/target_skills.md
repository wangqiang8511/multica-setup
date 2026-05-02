# Skills for QA Agent.
#
# Format: one skills.sh URL per line. Lines starting with `#` are ignored.
# The create script derives the skill name from the last path segment of
# each URL and reuses it if already installed in the workspace, otherwise
# imports via `multica skill import --url <url>`.
#
# Bare skill names are accepted as a fallback for skills that do not yet
# have a public skills.sh URL.

# Clarify intent before acting when the test plan / scope is ambiguous.
https://skills.sh/obra/superpowers/brainstorming

# Root-cause discipline: no fix (or filed bug) without real investigation.
https://skills.sh/obra/superpowers/systematic-debugging

# Evidence-before-claims gate before posting "pass" or "fail" results.
https://skills.sh/obra/superpowers/verification-before-completion

# Native Playwright workflow for driving local web apps, capturing
# screenshots, and managing server lifecycle during integration runs.
https://skills.sh/anthropics/skills/webapp-testing

# Persistent headless / real-Chrome automation for scripted user-flow QA
# and network/DOM assertions across steps.
https://skills.sh/vercel-labs/agent-browser/agent-browser

# Custom workspace skill for talking to the Multica API to file bugfix
# issues, assign them to owner agents, and post QA summary comments.
# Pushed separately via `./scripts/push-skill.sh skills/multica-cli`;
# referenced here by bare name so create-agent.sh picks it up from the
# workspace's skill list.
multica-cli
