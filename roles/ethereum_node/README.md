# ethpandaops.general.ethereum_node

This role will allow you to run a ethereum execution and consensus layer node.

You can choose and switch between client you want to run by changing the following variables:

```yaml
 ethereum_node_el: geth
 ethereum_node_cl: lighthouse
```

It uses the following underyling roles:

### Consensus layer clients
- [ethpandaops.general.teku](../teku)
- [ethpandaops.general.prysm](../prysm)
- [ethpandaops.general.nimbus](../nimbus)
- [ethpandaops.general.lodestar](../lodestar)
- [ethpandaops.general.lighthouse](../lighthouse)

### Execution layer clients
- [ethpandaops.general.geth](../geth)
- [ethpandaops.general.nethermind](../nethermind)

## Requirements

You'll need docker on the target system. Make sure to install it upfront.

## Role Variables

Default variables are defined in [defaults/main.yaml](defaults/main.yaml)

You can also overwrite any of the default variables used by the specific EL or CL client roles too.

E.g. For geth that would be [ethpandaops.general.geth/defaults/main.yaml](../geth/defaults/main.yaml).


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

If you would like to run a geth and lighthouse node, then your playbook could look like this:

```yaml
- hosts: localhost
  become: true
  roles:
  - role: geerlingguy.docker
  - role: geerlingguy.pip
    pip_install_packages:
    - name: docker
  - role: ethpandaops.general.ethereum_node
    ethereum_node_el: geth
    ethereum_node_cl: lighthouse
```
