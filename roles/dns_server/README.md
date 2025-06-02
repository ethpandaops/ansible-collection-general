# ethpandaops.general.dns_server

Setup [bind9](https://hub.docker.com/r/ubuntu/bind9) dns server and and serve a custom dns zone.

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
- hosts: dns_server
  become: true
  roles:
  # Docker. Required dependency
  - role: geerlingguy.docker
    tags: [docker]
  - role: geerlingguy.pip
    pip_install_packages:
    - name: docker
    tags: [docker]
  # dns_server
  - role: dns_server
    tags: [dns_server]
```
