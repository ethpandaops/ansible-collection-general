# ethpandaops.general.beaconlight_explorer

Setup [light-beaconchain-explorer](https://github.com/pk910/light-beaconchain-explorer) and all required dependencies all in one server.

## Requirements

You'll need docker on the target system. Make sure to install it upfront.

## Role Variables

Default variables are defined in [defaults/main.yaml](defaults/main.yaml)

## Dependencies

You'll need docker to run this role. One way of installing docker could be via ansible galaxy with the following dependencies set within `requirements.yaml`:

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
- hosts: beaconlight
  become: true
  roles:
  # Docker. Required dependency
  - role: geerlingguy.docker
    tags: [docker]
  - role: geerlingguy.pip
    pip_install_packages:
    - name: docker
    tags: [docker]
  # light-beaconchain-explorer
  - role: beaconlight_explorer
    tags: [beaconlight]
```
