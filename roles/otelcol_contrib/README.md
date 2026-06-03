# ethpandaops.general.otelcol_contrib

This role runs [opentelemetry-collector-contrib](https://github.com/open-telemetry/opentelemetry-collector-contrib) inside a docker container.

## Requirements

You'll need docker on the target system. Make sure to install it upfront.

## Role Variables

Default variables are defined in [defaults/main.yaml](defaults/main.yaml). The most useful ones:

- `otelcol_contrib_config` — the full collector YAML config (templated as a string)
- `otelcol_contrib_container_image` — image and tag (defaults to a pinned `otel/opentelemetry-collector-contrib` version)
- `otelcol_contrib_container_networks` — docker networks to attach to (useful when other containers need to push OTLP to the collector by name)
- `otelcol_contrib_container_user` — UID:GID to run as. Defaults to `"0:0"` (root) so the filelog receiver can read root-owned container log files. Set to a non-root UID/GID if your host setup permits.
- `otelcol_contrib_container_volumes` — defaults mount the collector config, `/var/lib/docker/containers` (read-only, for the `filelog` receiver) and the docker socket.

### Docker log collection with per-container metadata

A plain `filelog` receiver tailing `/var/lib/docker/containers/*/*-json.log` only knows the container **id** (the path) — it can't tell you the container name, image or labels. Those live in the Docker daemon, and the role already mounts the socket. The role ships ready-made building blocks that read that metadata live (no container restarts, no log-driver changes):

- `otelcol_contrib_docker_observer` — the `docker_observer` extension that discovers containers via the socket. It sets `include_all_containers: true` so a single port-less endpoint (`port == 0`) is emitted for every running container.
- `otelcol_contrib_docker_logs_receiver` — a `receiver_creator/docker` that spawns one `filelog` receiver per container (its rule matches `port == 0`, so exactly one endpoint per container — covering containers with no published ports and never double-tailing multi-port ones), attaching `container.name`, `container.image.name` and `container.id` as resource attributes, parsing the docker json format and mapping the json `level` field to severity. New containers are picked up automatically.
- `otelcol_contrib_docker_logs_excluded_names` — list of container-name regex fragments to skip (defaults to just the collector's own container; add your own sidecars/tooling).

Interpolate them into your `otelcol_contrib_config` and add `receiver_creator/docker` to the logs pipeline:

```yaml
otelcol_contrib_config: |
  extensions:
{{ otelcol_contrib_docker_observer | to_nice_yaml(indent=2, width=1000) | indent(4, True) }}
  receivers:
{{ otelcol_contrib_docker_logs_receiver | to_nice_yaml(indent=2, width=1000) | indent(4, True) }}
  processors:
    resource:
      attributes:
        # ...any host-level attributes you want on every log (env, region, ...)...
        - {key: deployment.environment, value: "production", action: upsert}
  exporters:
    otlphttp: { endpoint: "https://otlp.example.com" }
  service:
    extensions: [docker_observer]
    pipelines:
      logs:
        receivers: [receiver_creator/docker]
        processors: [resource]
        exporters: [otlphttp]
```

Per-container `container.name` / `container.image.name` / `container.id` come from the Docker socket; any host-level identity is added via the `resource` processor in your own config.

## Dependencies

You'll need docker to run this role. One way of installing docker could be via ansible galaxy with the following dependencies set within `requirements.yaml`:

```yaml
roles:
- src: geerlingguy.docker
  version: latest
- src: geerlingguy.pip
  version: latest
```

## Example Playbook

```yaml
- hosts: localhost
  become: true
  roles:
  - role: geerlingguy.docker
  - role: geerlingguy.pip
    pip_install_packages:
    - name: docker
  - role: ethpandaops.general.otelcol_contrib
    vars:
      otelcol_contrib_config: |
        receivers:
          filelog:
            include: [/var/lib/docker/containers/*/*-json.log]
            include_file_path: true
            start_at: end
            operators:
              - type: container
                format: docker
                add_metadata_from_filepath: true
        exporters:
          otlphttp:
            endpoint: https://otlp.example.com
        service:
          pipelines:
            logs:
              receivers: [filelog]
              exporters: [otlphttp]
```
