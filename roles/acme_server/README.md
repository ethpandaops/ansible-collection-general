# ethpandaops.general.acme_server

Setup [step-ca](https://smallstep.com/docs/step-ca/), an acme-compatible certificate authority.

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
  - role: ethpandaops.general.dns_server
    vars:
      dns_server_is_master: true
      dns_server_zones:
        - zone: "example.ethpandaops.io"
  - role: ethpandaops.general.acme_server
 ```
