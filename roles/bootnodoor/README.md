# ethpandaops.general.bootnodoor

This role will run [bootnodoor](https://github.com/ethpandaops/bootnodoor) within a docker container.

## Requirements

You'll need docker on the target system. Make sure to install it upfront.

## Role Variables

Default variables are defined in [defaults/main.yaml](defaults/main.yaml)

## Facts

This role will set some facts which allow you to access the following data via hostvars:

- `bootnodoor_fact_enr` - Public ENR for the bootnode (CL)
- `bootnodoor_fact_enode` - Public enode for the bootnode (EL)

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
  - role: ethpandaops.general.bootnodoor
```
