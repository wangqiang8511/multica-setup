# Tiltfile API Reference

Source: https://docs.tilt.dev/api.html

## Image Building

### docker_build
```python
docker_build(ref, context, 
  dockerfile='Dockerfile',
  build_args={},
  target='',
  ssh='',
  cache_from=[],
  pull=False,
  platform='',
  only=[],              # limit build context
  ignore=[],            # exclude from context
  live_update=[],       # live update steps
  match_in_env_vars=False,
  extra_tag='',
  container_args=None,
  entrypoint=None,
  secret=None)
```

### custom_build
```python
custom_build(ref, command, deps,
  tag='',
  disable_push=False,
  skips_local_docker=False,
  live_update=[],
  ignore=[])
```

## Live Update Steps

```python
sync(local_path, remote_path)          # copy files into container
run(cmd, trigger=[])                   # run command; trigger=paths to watch
restart_container()                    # restart container entrypoint
restart_process(process='/path/bin')   # restart specific process (needs ext)
```

## Kubernetes

### k8s_yaml
```python
k8s_yaml(config)    # str, blob, or list; also accepts kustomize(), helm()
kustomize(fileobj, kustomize_bin='kustomize', flags=[])
helm(pathToChartDir, name='', namespace='', values=[], set=[], 
     kube_version='', output_dir='')
```

### k8s_resource
```python
k8s_resource(workload,
  new_name='',
  port_forwards=[],         # int, 'host:container', or PortForward()
  extra_pod_selectors={},
  trigger_mode=TRIGGER_MODE_AUTO,
  resource_deps=[],
  pod_readiness='wait',     # 'wait' | 'ignore'
  objects=[],
  auto_init=True,
  labels=[])
```

### port_forward
```python
port_forward(local_port, container_port=0, name='', host='localhost')
```

### k8s_custom_deploy
```python
k8s_custom_deploy(name,
  deploy_cmd, delete_cmd,
  deps=[],
  image_deps=[],
  image_maps=[],
  pod_readiness='wait',
  resource_deps=[],
  auto_init=True,
  labels=[])
```

## Docker Compose

```python
docker_compose(configPaths,          # str or list of str
  env_file='',
  project_name='',
  profiles=[],
  wait=False)

dc_resource(name,
  new_name='',
  trigger_mode=TRIGGER_MODE_AUTO,
  resource_deps=[],
  port_forwards=[],
  auto_init=True,
  labels=[])
```

## Local Resources

```python
local_resource(name, cmd='', serve_cmd='',
  deps=[],
  trigger_mode=TRIGGER_MODE_AUTO,
  resource_deps=[],
  auto_init=True,
  labels=[],
  allow_parallel=False,
  env={},
  dir='',
  readiness_probe=None)

local(cmd, quiet=False, echo_off=False, env={}, dir='', stdin='')
```

## Configuration

```python
allow_k8s_contexts(contexts)          # str or list; restrict deployment contexts
default_registry(host, single_name='', host_from_cluster='')
update_settings(
  max_parallel_updates=3,
  k8s_upsert_timeout_secs=300,
  suppress_unused_image_warnings=None)
trigger_mode(mode)                    # TRIGGER_MODE_AUTO | TRIGGER_MODE_MANUAL
config.define_string(name, args=False, usage='')
config.parse()
```

## Reading Files / Data

```python
read_file(path, default=None)         # returns blob
read_yaml(path, default=None)         # returns parsed object
read_json(path, default=None)
decode_yaml(yaml_str)
decode_json(json_str)
encode_yaml(obj)
encode_json(obj)
listdir(path, recursive=False)
blob(contents)                        # create a blob from string
```

## Extensions

```python
load('ext://extension-name', 'function1', 'function2')
# Extensions pulled from github.com/tilt-dev/tilt-extensions
```

Common extensions:
- `ext://helm_resource` — `helm_resource`, `helm_remote`
- `ext://uibutton` — `cmd_button`, `text_input`
- `ext://restart_process` — `crash_rebuild_only`
- `ext://git_resource` — `git_checkout`
- `ext://dotenv` — `dotenv`
- `ext://nix` — `nix_flake_resource`

## Trigger Modes

```python
TRIGGER_MODE_AUTO    # rebuild on file change (default)
TRIGGER_MODE_MANUAL  # only rebuild when manually triggered
```

## Readiness Probes

```python
probe(
  initial_delay_secs=0,
  timeout_secs=1,
  period_secs=10,
  success_threshold=1,
  failure_threshold=3,
  http_get=http_get_action(port, host='', path='/'),
  tcp_socket=tcp_socket_action(port),
  exec=exec_action(command))
```

## Useful Builtins

```python
os.environ         # dict of env vars
os.getenv(key, default='')
os.path.exists(path)
os.path.join(*args)
str(x), int(x), bool(x)
fail(msg)          # stop Tiltfile evaluation with error message
print(msg)         # log to Tilt output
```
