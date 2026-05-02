---
name: tilt
description: Use when working with Tilt (tilt.dev) for local Kubernetes or Docker Compose development — writing or editing Tiltfiles, configuring live update, setting up resource dependencies, port forwarding, running `tilt up`/`tilt down`/`tilt ci`, or troubleshooting slow rebuild loops in containerized microservices.
---

# Tilt

## Overview

Tilt automates the inner dev loop for containerized applications: watch files → build images → deploy to local Kubernetes or Docker Compose → live-update running containers. A single `Tiltfile` (Starlark/Python-like) encodes the full team setup.

## When to Use

- Writing or editing a `Tiltfile`
- Speeding up rebuild loops (switching to live update)
- Orchestrating multi-service local environments
- Integrating Tilt into CI with `tilt ci`
- Configuring resource startup order / readiness probes

## CLI Quick Reference

| Command | Purpose |
|---------|---------|
| `tilt up [resources]` | Start all (or named) resources; opens web UI |
| `tilt down` | Remove all resources created by `tilt up` |
| `tilt ci` | Batch/CI mode — exit 0 if all healthy, else non-zero |
| `tilt trigger <resource>` | Force a rebuild/update for one resource |
| `tilt logs [-f] [--level warn]` | Stream or query logs |
| `tilt doctor` | Print diagnostic info for bug reports |

Key `tilt up` flags: `--file/-f`, `--context`, `--namespace`, `--port`

## Tiltfile Core Functions

### Image Building

```python
# Standard Docker build
docker_build('my-image', './app')

# With live update (sync files, skip full rebuild)
docker_build('my-image', './app',
  live_update=[
    sync('./app/src', '/app/src'),
    run('pip install -r requirements.txt',
        trigger=['./app/requirements.txt']),
  ]
)
```

### Kubernetes Resources

```python
k8s_yaml('k8s/')                          # apply YAML files/dirs
k8s_resource('api', port_forwards=8080)   # port forward
k8s_resource('worker',
  resource_deps=['postgres'],             # wait for postgres first
  pod_readiness='wait')
```

### Docker Compose

```python
docker_compose('./docker-compose.yml')
dc_resource('web', port_forwards=3000)
```

### Local Resources

```python
local_resource('db-migrate',
  cmd='./scripts/migrate.sh',
  resource_deps=['postgres'],
  deps=['./migrations'])
```

### Configuration Helpers

```python
allow_k8s_contexts(['docker-desktop', 'minikube'])
default_registry('gcr.io/my-project')
update_settings(max_parallel_updates=3)

load('ext://helm_resource', 'helm_resource')   # community extensions
```

## Live Update Pattern

Live update skips image rebuilds by syncing files directly into running containers. Use it for interpreted languages (Python, Node.js, Ruby) and compiled languages with hot-reload support.

```python
docker_build('flask-api', '.',
  live_update=[
    sync('.', '/app'),
    run('pip install -r requirements.txt',
        trigger=['requirements.txt']),
    restart_container(),   # if no hot-reload
  ]
)
```

Performance impact: 10–14 s (full rebuild) → 1–2 s (live update).

## Resource Dependencies

```python
k8s_resource('api',    resource_deps=['postgres', 'redis'])
k8s_resource('worker', resource_deps=['api'])
```

Tilt waits for each dependency to become ready before starting dependents. Readiness defaults: K8s pods → all containers ready; Docker Compose → container started; local resources → command exits 0.

## Common Patterns

**Run only services under active development:**
```bash
tilt up frontend api  # skips db, cache, etc.
```

**Disable resources by default (opt-in):**
```python
k8s_resource('expensive-service', auto_init=False, trigger_mode=TRIGGER_MODE_MANUAL)
```

**Conditional image building (CI vs. dev):**
```python
if os.getenv('CI'):
  k8s_resource('api', image='gcr.io/my-project/api:latest')
else:
  docker_build('gcr.io/my-project/api', './api')
```

## CI Integration

```bash
tilt ci           # exits 0 when all resources healthy, non-zero on any failure
tilt ci api tests # run only named resources in CI
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Slow rebuilds for interpreted code | Add `live_update` with `sync()` to skip image rebuilds |
| Services start before dependencies ready | Use `resource_deps=` on dependent resources |
| Deploying to prod cluster by accident | Add `allow_k8s_contexts(['local-context'])` at top of Tiltfile |
| Large Docker build context | Use `only=['./src', './Dockerfile']` in `docker_build()` |
| Tilt rebuilds on every file change | Narrow `deps=` on `local_resource` or `only=` on `docker_build` |

## Extensions

```python
# Load community extensions from tilt-extensions GitHub repo
load('ext://helm_resource', 'helm_resource', 'helm_remote')
load('ext://uibutton', 'cmd_button')       # custom UI buttons
load('ext://restart_process', 'crash_rebuild_only')
```

## Further Reference

- Full Tiltfile API: `references/tiltfile-api.md`
- Docs: https://docs.tilt.dev/
