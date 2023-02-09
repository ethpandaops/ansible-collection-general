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
- [ethpandaops.general.besu](../besu)
- [ethpandaops.general.geth](../geth)
- [ethpandaops.general.erigon](../erigon)
- [ethpandaops.general.nethermind](../nethermind)
- [ethpandaops.general.ethereumjs](../ethereumjs)

### Facts discovery
- [ethpandaops.general.ethereum_node_fact_discovery](../ethereum_node_fact_discovery)

### Metrics/Events collection
- [ethpandaops.general.ethereum_metrics_exporter](../ethereum_metrics_exporter)
- [ethpandaops.general.xatu_sentry](../xatu_sentry)

## Requirements

You'll need docker on the target system. Make sure to install it upfront.

## Role Variables

Default variables are defined in [defaults/main.yaml](defaults/main.yaml)

You can also overwrite any of the default variables used by the specific EL or CL client roles too.

E.g. For geth that would be [ethpandaops.general.geth/defaults/main.yaml](../geth/defaults/main.yaml).

To enable the `ethereum-metrics-exporter` you need to set `ethereum_node_metrics_exporter_enabled: true`. By default it's disabled.


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

If you want to set client specific configuration you could do it by overwriting the the client specific default variables. For example, if you want to provide extra arguments to your lighthouse command and run a specific version of geth, then you could do it like this:

```yaml
  - role: ethpandaops.general.ethereum_node
    # Define which clients you want to use
    ethereum_node_el: geth
    ethereum_node_cl: lighthouse
    # Overwrite a specific lighthouse variable. Check lighthouse/defaults/main.yaml
    lighthouse_container_command_extra_args:
      - --checkpoint-sync-url=http://your-other-node
    # Overwrite a specific geth variable. Check geth/defaults/main.yaml
    geth_container_image: ethereum/client-go:latest
```
