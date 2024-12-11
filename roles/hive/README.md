# ethpandaops.general.hive

This role will run [hive](https://github.com/ethereum/hive).

## Requirements

You'll need docker and golang on the target system. Make sure to install it upfront.

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
- src: gantsign.golang
  version: latest
```

## Example Playbook

Your playbook could look like this:

```yaml
- hosts: localhost
  become: true
  roles:
  # Golang
  - role: gantsign.golang
    golang_gopath: '/data/workspace-go'
    golang_version: '1.21.13'
  # Docker
  - role: geerlingguy.docker
  - role: geerlingguy.pip
    pip_install_packages:
    - name: docker
  # Hive
  - role: ethpandaops.general.hive
```
