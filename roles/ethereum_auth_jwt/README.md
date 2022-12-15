# ethpandaops.general.ethereum_auth_jwt

This role allows you to easily generate a JWT to be used  when setting up connectivity between execution and consensus layer clients of the Ethereum network.

## Requirements

The `openssl` package needs to be installed on the underlying system.

## Role Variables

By default the role will generate a random JWT. You can overwrite this behaviour. Check possible configuration options in [defaults/main.yaml](defaults/main.yaml)

## Dependencies

None

## Example Playbook

Your playbook could look like this:

```yaml
- hosts: localhost
  become: true
  roles:
  - role: ethpandaops.general.ethereum_auth_jwt
```
