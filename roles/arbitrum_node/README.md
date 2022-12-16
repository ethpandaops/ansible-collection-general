# ethpandaops.general.arbitrum_node

Setup a [Arbitrum Nitro Node](https://github.com/OffchainLabs/nitro), a ethereum L2 client.

## Requirements

You'll need docker on the target system. Make sure to install it upfront.

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
  vars:
    docker_network_name: shared
    geth_container_networks:
    - name: "{{ docker_network_name }}"
    teku_container_networks:
    - name: "{{ docker_network_name }}"
    arbitrum_node_container_networks:
    - name: "{{ docker_network_name }}"
  roles:
  - role: geerlingguy.docker
  - role: geerlingguy.pip
    pip_install_packages:
    - name: docker
  - role: ethpandaops.general.docker_network
  - role: ethpandaops.general.geth
  - role: ethpandaops.general.teku
  - role: ethpandaops.general.arbitrum_node
```
