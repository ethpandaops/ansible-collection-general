# ethpandaops.general.observoor

This role will run [observoor](https://github.com/ethpandaops/observoor) within a docker container.

Observoor is an eBPF agent that monitors Ethereum EL/CL processes at the kernel level. It requires privileged access and host PID namespace for eBPF program loading and process discovery.

## Requirements

You'll need docker on the target system. Make sure to install it upfront.

The target host must be running Linux with kernel headers and BTF support.

## Role Variables

Default variables are defined in [defaults/main.yaml](defaults/main.yaml)

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

Your playbook could look like this:

```yaml
- hosts: localhost
  become: true
  roles:
  - role: geerlingguy.docker
  - role: geerlingguy.pip
    pip_install_packages:
    - name: docker
  - role: ethpandaops.general.observoor
    observoor_cl_endpoint: "http://localhost:5052"
    observoor_meta_client_name: "my-node"
    observoor_meta_network_name: "mainnet"
```

## Usage with ethereum_node

When used as an addon within `ethpandaops.general.ethereum_node`, the beacon endpoint and docker networks are mapped automatically:

```yaml
- hosts: localhost
  become: true
  roles:
  - role: ethpandaops.general.ethereum_node
    ethereum_node_observoor_enabled: true
```

The observoor config (ClickHouse endpoint, meta labels, etc.) can be customized by setting `observoor_*` variables directly in your inventory.
