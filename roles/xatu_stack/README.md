# ethpandaops.general.xatu_stack

This role will run the [xatu stack](https://github.com/ethpandaops/xatu) using Docker Compose, deploying the following containers:

- `xatu-grafana`
- `xatu-server`
- `xatu-nginx`
- `xatu-postgres`
- `xatu-kafka`
- `xatu-vector-http-kafka`
- `xatu-vector-kafka-clickhouse`
- `xatu-vector-kafka-clickhouse-libp2p`
- `xatu-clickhouse-01`
- `xatu-clickhouse-02`

## Requirements

You'll need Docker and Docker Compose on the target system. Make sure to install them upfront.

## Role Variables

Default variables are defined in [defaults/main.yaml](defaults/main.yaml). Some key variables include:

- `xatu_stack_user`: The user under which the xatu stack will run (default: "xatu-stack")
- `xatu_stack_repo_url`: The URL of the xatu repository (default: "https://github.com/ethpandaops/xatu")
- `xatu_stack_repo_version`: The version/branch of the xatu repository to use (default: "master")
- `xatu_stack_repo_path`: The local path where the xatu repository will be cloned (default: "/data/xatu-stack")

## Dependencies

You'll need docker to run this role. One way of installing docker could be via ansible galaxy with the following dependencies set within `requirements.yaml`:

```yaml
collections:
- name: community.docker

roles:
- src: geerlingguy.docker
  version: latest
- src: geerlingguy.pip
  version: latest
```

## Example Playbook

Your playbook could look like this:

```yaml
- hosts: localhost
  become: true
  roles:
  - role: geerlingguy.docker
  - role: geerlingguy.pip
    pip_install_packages:
    - name: docker
    
  - role: ethpandaops.general.xatu_stack
```
