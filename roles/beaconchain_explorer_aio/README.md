# ethpandaops.general.beaconchain_explorer_aio

Setup a [beaconchain explorer](https://github.com/gobitfly/eth2-beaconchain-explorer/) and all required database dependencies all in one server.

## Requirements

You'll need docker and docker-compose on the target system. Make sure to install these upfront.

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
- hosts: beaconchain_explorer
  become: true
  roles:
  # Docker. Required dependency
  - role: geerlingguy.docker
    tags: [docker]
  - role: geerlingguy.pip
    pip_install_packages:
    - name: docker
    - name: docker-compose
    tags: [docker]
  # Beaconchain explorer
  - role: beaconchain_explorer_aio
    tags: [beaconchain_explorer_aio]
```
