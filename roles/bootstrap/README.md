# ethpandaops.general.bootstrap

This role is does some basic server bootstraping and hardening.

## Requirements

None

## Role Variables

Default variables are defined in [defaults/main.yaml](defaults/main.yaml)

## Dependencies

None

## Example Playbook

Your playbook could look like this:

```yaml
- hosts: all
  become: true
  roles:
    - role: ethpandaops.general.bootstrap
```
