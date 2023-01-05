# ethpandaops.general.bootstrap

This role is does some basic server bootstraping and hardening.

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
    - role: ethpandaops.general.bootstrap
```

### Enable reboot if required
If you would like to enable the machines to reboot during bootstrap, then it can be set as an option.
```sh
ansible-playbook playbook.yaml -i inventory.yaml -e bootstrap_reboot_if_required=true
```