# Skills for Infra Agent.
#
# Format: one skills.sh URL per line. Lines starting with `#` are ignored.
# The create script derives the skill name from the last path segment of
# each URL and reuses it if already installed in the workspace, otherwise
# imports via `multica skill import --url <url>`.
#
# Bare skill names are accepted as a fallback for skills that do not yet
# have a public skills.sh URL.

# --- Troubleshooting discipline ------------------------------------------
# Iron-law debugging: evidence -> hypothesis -> root cause -> fix.
# Keeps the agent from "restart and hope" behavior on incidents.
https://skills.sh/obra/superpowers/systematic-debugging

# Proof before sign-off: every fix/deploy must include verification output.
https://skills.sh/obra/superpowers/verification-before-completion

# --- Docker / local dev --------------------------------------------------
# Dockerfile authoring: multi-stage, small images, non-root users.
https://skills.sh/sickn33/antigravity-awesome-skills/docker-expert

# docker-compose for the local dev stack (db, cache, service, etc.).
https://skills.sh/manutej/luxor-claude-marketplace/docker-compose-orchestration

# --- Kubernetes / Helm / Tilt -------------------------------------------
# Scaffolds a Helm chart from a service's deployment shape.
https://skills.sh/wshobson/agents/helm-chart-scaffolding

# General Kubernetes ops: manifests, resources, rollout strategy.
https://skills.sh/jeffallan/claude-skills/kubernetes-specialist

# Tiltfile authoring for the local k8s dev loop.
https://skills.sh/0xbigboss/claude-code/tilt

# kubectl-centric debugging: describe / logs / events / exec workflows.
https://skills.sh/laurigates/claude-plugins/kubectl-debugging

# --- Release / operations ------------------------------------------------
# SRE playbook: incident response, runbooks, post-mortems.
https://skills.sh/jeffallan/claude-skills/sre-engineer

# Deployment pipeline patterns: progressive rollout, rollback, gates.
https://skills.sh/wshobson/agents/deployment-pipeline-design
