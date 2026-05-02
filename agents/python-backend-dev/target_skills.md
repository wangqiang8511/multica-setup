# Skills for Python Backend Developer.
#
# Format: one skills.sh URL per line. Lines starting with `#` are ignored.
# The create script derives the skill name from the last path segment of
# each URL and reuses it if already installed in the workspace, otherwise
# imports via `multica skill import --url <url>`.

# --- FastAPI --------------------------------------------------------------
# Production-ready FastAPI project templates and conventions.
https://skills.sh/wshobson/agents/fastapi-templates

# --- Python packaging / tooling ------------------------------------------
# uv as the canonical package manager and virtualenv tool.
https://skills.sh/wshobson/agents/uv-package-manager

# Standard python project layout (src/ vs flat, pyproject.toml, module
# boundaries).
https://skills.sh/wshobson/agents/python-project-structure

# Ruff + formatting + naming conventions.
https://skills.sh/wshobson/agents/python-code-style

# Typing discipline: mypy strict, Pydantic v2, typed exceptions.
https://skills.sh/wshobson/agents/python-type-safety

# Structured error handling patterns (domain exceptions -> HTTP).
https://skills.sh/wshobson/agents/python-error-handling

# --- Testing --------------------------------------------------------------
# pytest patterns, fixtures, async testing, FastAPI TestClient usage.
https://skills.sh/wshobson/agents/python-testing-patterns

# TDD workflow discipline (red / green / refactor) applied to each feature.
https://skills.sh/obra/superpowers/test-driven-development

# --- Observability --------------------------------------------------------
# Structured logging, correlation IDs, metrics, tracing patterns.
https://skills.sh/wshobson/agents/python-observability

# --- Docker ---------------------------------------------------------------
# Multi-stage Dockerfile patterns for slim, secure production images.
https://skills.sh/github/awesome-copilot/multi-stage-dockerfile

# --- Debugging ------------------------------------------------------------
# Systematic debugging discipline when an endpoint or service misbehaves.
https://skills.sh/obra/superpowers/systematic-debugging
