# ethpandaops.general.blockscout

Setup [blockscout](https://github.com/blockscout/blockscout/) and all required dependencies all in one server.

## Requirements

You'll need docker on the target system. Make sure to install it upfront.

## Role Variables

Default variables are defined in [defaults/main.yaml](defaults/main.yaml)

## Dependencies

You'll need docker and docker-compose to run this role. One way of installing docker could be via ansible galaxy with the following dependencies set within `requirements.yaml`:

```yaml
roles:
- src: geerlingguy.docker
  version: 6.0.3
- src: geerlingguy.pip
  version: 2.2.0
```

## Example Playbook

Your playbook could look like this:

```yaml
- hosts: blockscout
  become: true
  roles:
  # Docker. Required dependency
  - role: geerlingguy.docker
    tags: [docker]
  - role: geerlingguy.pip
    pip_install_packages:
    - name: docker
    tags: [docker]
  # Blockscout explorer
  - role: blockscout
    blockscout_container_env:
      ETHEREUM_JSONRPC_VARIANT: geth
      ETHEREUM_JSONRPC_HTTP_URL: http://your-geth-node:8545/
    tags: [blockscout]
```
