# ethpandaops.general.otelcol_contrib

This role runs [opentelemetry-collector-contrib](https://github.com/open-telemetry/opentelemetry-collector-contrib) inside a docker container.

## Requirements

You'll need docker on the target system. Make sure to install it upfront.

## Role Variables

Default variables are defined in [defaults/main.yaml](defaults/main.yaml). The most useful ones:

- `otelcol_config` — the full collector YAML config (templated as a string)
- `otelcol_container_image` — image and tag (defaults to a pinned `otel/opentelemetry-collector-contrib` version)
- `otelcol_container_networks` — docker networks to attach to (useful when other containers need to push OTLP to the collector by name)
- `otelcol_container_user` — UID:GID to run as. Defaults to `"0:0"` (root) so the filelog receiver can read root-owned container log files. Set to a non-root UID/GID if your host setup permits.
- `otelcol_container_volumes` — defaults mount the collector config, `/var/lib/docker/containers` (read-only, for the `filelog` receiver) and the docker socket.

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
      otelcol_config: |
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
