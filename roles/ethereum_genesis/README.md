# ethpandaops.general.ethereum_genesis

This role will generate a Ethereum genesis network configuration and required validator keys.
It uses the [`ethereum-genesis-generator`](https://github.com/ethpandaops/ethereum-genesis-generator)

## Requirements

You'll need docker on the ansible controller host. Make sure to install it upfront.

## Role Variables

Default variables are defined in [defaults/main.yaml](defaults/main.yaml)

## Dependencies

You'll need docker installed locally to run this role.

## Example Playbook

Your playbook could look like this:

```yaml
- hosts: localhost
  roles:
  - role: ethpandaops.general.ethereum_genesis
```
