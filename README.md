# Ansible Collection - ethpandaops.general

[![Lint](https://github.com/ethpandaops/ansible-collection-general/actions/workflows/lint.yaml/badge.svg)](https://github.com/ethpandaops/ansible-collection-general/actions/workflows/lint.yaml)
[![Integration](https://github.com/ethpandaops/ansible-collection-general/actions/workflows/integration.yaml/badge.svg)](https://github.com/ethpandaops/ansible-collection-general/actions/workflows/integration.yaml)
[![Integration (ethereum_node)](https://github.com/ethpandaops/ansible-collection-general/actions/workflows/integration.ethereum_node.yaml/badge.svg)](https://github.com/ethpandaops/ansible-collection-general/actions/workflows/integration.ethereum_node.yaml)

A collection of reusable ansible components used by the EthPandaOps team.

## Roles

### Ethereum tooling
- [beaconchain_explorer_aio](roles/beaconchain_explorer_aio)
- [blockscout](roles/blockscout)
- [cl_bootnode](roles/cl_bootnode)
- [dshackle](roles/dshackle)
- [dugtrio](roles/dugtrio)
- [ethereum_auth_jwt](roles/ethereum_auth_jwt)
- [ethereum_genesis](roles/ethereum_genesis)
- [ethereum_metrics_exporter](roles/ethereum_metrics_exporter)
- [ethstats](roles/ethstats)
- [goomy](roles/goomy)
- [mev_boost](roles/mev_boost)
- [mev_relay](roles/mev_relay)
- [mev_rs](roles/mev_rs)
- [powfaucet](roles/powfaucet)
- [snapshotter](roles/snapshotter)
- [xatu_sentry](roles/xatu_sentry)

### Ethereum client pair
- [ethereum_node](roles/ethereum_node)
- [ethereum_node_fact_discovery](roles/ethereum_node_fact_discovery)

### Ethereum execution clients
- [besu](roles/besu)
- [erigon](roles/erigon)
- [ethereumjs](roles/ethereumjs)
- [geth](roles/geth)
- [nethermind](roles/nethermind)
- [reth](roles/reth)

### Ethereum consensus clients
- [grandine](roles/grandine)
- [lighthouse](roles/lighthouse)
- [lodestar](roles/lodestar)
- [nimbus](roles/nimbus)
- [prysm](roles/prysm)
- [teku](roles/teku)

### Ethereum L2 clients
- [arbitrum_node](roles/arbitrum_node)

### General purpose tooling
- [bootstrap](roles/bootstrap)
- [docker_cleanup](roles/docker_cleanup)
- [docker_network](roles/docker_network)
- [docker_nginx_proxy](roles/docker_nginx_proxy)
- [firewall](roles/firewall)
- [json_rpc_snooper](roles/json_rpc_snooper)
- [k3s](roles/k3s)
- [litestream](roles/litestream)
- [logsprout](roles/logsprout)
- [oh_my_zsh](roles/oh_my_zsh)
- [prometheus](roles/prometheus)
- [s3_cron_backup](roles/s3_cron_backup)
- [traffic_control](roles/traffic_control)
- [vector](roles/vector)

### Prometheus exporters
- [cloudwatch_exporter](roles/cloudwatch_exporter)
- [json_exporter](roles/json_exporter)
- [node_exporter](roles/node_exporter)

### Hetzner
- [hetzner_vswitch](roles/hetzner_vswitch)

## Usage

Currently we're not publishing the collection to Ansible Galaxy. We'll do that once it grows bigger.

To install the collection directly from our git repository you can do the following:

```sh
ansible-galaxy collection install git+https://github.com/ethpandaops/ansible-collection-general.git,master
```

Or using a `requirements.yml` file that looks like:

```yaml
collections:
  - name: ethpandaops.general
    source: https://github.com/ethpandaops/ansible-collection-general.git,master
    type: git
```

Then run the following command:

```sh
ansible-galaxy install -r requirements.yml
```



## Local testing and development

Clone the repository. Make sure that you follow that directory structure, otherwise `ansible test` won't work:

```sh
git clone git@github.com:ethpandaops/ansible-collection-general.git ansible_collections/ethpandaops/general
```

If you want to test and develop on this ansible collection you'll need some tools. We're using [`asdf`](https://asdf-vm.com/) to commit to certain [versions](.tool-versions) of those tools. Some additional python specific tools are defined in the [`requirements.txt`](requirements.txt).

Make sure you have `asdf` installed and then you can run the `./setup.sh` script which will install all required tools. Alternatively you can run `make setup` which will do the same thing.

For linting and sanity checks you can run the following commands:

```sh
ansible-lint
ansible-test sanity --exclude .ansible/
```

Alternatively you can run `make lint` which will run the linting and sanity checks.

Some roles have [molecule](https://ansible.readthedocs.io/projects/molecule/) tests inside. You can check this if a role has a `molecule` directory within. To run molecule ona given role you can do the following:

```sh
cd roles/blockscout
molecule test
```

If you want to test the [`ethereum_node`](roles/ethereum_node) role with molecule, you can pass it the specific execution and consensus clients via ENV vars:
```sh
cd roles/ethereum_node
EXECUTION_CLIENT=geth CONSENSUS_CLIENT=lighthouse molecule test
```

## License

[MIT License](LICENSE)
