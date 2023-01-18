# Ansible Collection - ethpandaops.general

[![Ansible CI](https://github.com/ethpandaops/ansible-collection-general/actions/workflows/ansible_lint.yml/badge.svg)](https://github.com/ethpandaops/ansible-collection-general/actions/workflows/ansible_lint.yml)

A collection of reusable ansible components used by the EthPandaOps team.

## Roles

### Ethereum tooling
- [beaconchain_explorer_aio](roles/beaconchain_explorer_aio/)
- [dshackle](roles/dshackle)
- [ethereum_auth_jwt](roles/ethereum_auth_jwt)

### Ethereum client pair
- [ethereum_node](roles/ethereum_node)
### Ethereum execution clients
- [besu](roles/besu)
- [erigon](roles/erigon)
- [ethereumjs](roles/ethereumjs)
- [geth](roles/geth)
- [nethermind](roles/nethermind)
### Ethereum consensus clients
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
- [json_exporter](roles/json_exporter)
- [k3s](roles/k3s)
- [litestream](roles/litestream)
- [node_exporter](roles/node_exporter)
- [oh_my_zsh](roles/oh_my_zsh)
- [prometheus](roles/prometheus)
- [s3_cron_backup](roles/s3_cron_backup)

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

If you want to test and develop on this ansible collection you'll need some tools. We're using [`asdf`](https://asdf-vm.com/) to commit to certain [versions](.tool-versions) of those tools.

Make sure you have `asdf` installed and then you can run the `./setup.sh` script which will install all required tools.

For linting and sanity checks you can run the following commands:

```sh
ansible-lint --exclude .github --profile production
ansible-test sanity
```

## License

[MIT License](LICENSE)
