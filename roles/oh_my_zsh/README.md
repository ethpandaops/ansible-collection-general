# ethpandaops.general.bootstrap

This role allows to install oh-my-zsh and customize it.

## Requirements

None

## Role Variables

Default variables are defined in [defaults/main.yaml](defaults/main.yaml)

## Dependencies

Check the [`meta/requirements.yml`](meta/requirements.yml) file and add the dependencies to your own requirements file.

## Example Playbook

Your playbook could look like this:

```yaml
- hosts: all
  become: true
  roles:
    - role: ethpandaops.general.oh_my_zsh
```
