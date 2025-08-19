# ethpandaops.general.wildcard_cert_issuer

Request wildcard certificates using DNS challenges via the acme protocol.

This role also includes an optional ACME retry monitor that watches for specific ACME failure patterns and automatically cleans up certificates and restarts the ACME container when needed.

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
  roles:
  - role: geerlingguy.docker
  - role: geerlingguy.pip
    pip_install_packages:
    - name: docker
  - role: ethpandaops.general.geth
  - role: ethpandaops.general.wildcard_cert_issuer
```
