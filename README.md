# Ansible Collection - ethpandaops.general

[![Ansible CI](https://github.com/ethpandaops/ansible-collection-general/actions/workflows/ansible_lint.yml/badge.svg)](https://github.com/ethpandaops/ansible-collection-general/actions/workflows/ansible_lint.yml)

A collection of reusable ansible components used by the EthPandaOps team.

## Roles

### Ethereum tooling
- [beaconchain_explorer_aio](roles/beaconchain_explorer_aio/)
- [ethereum_auth_jwt](roles/ethereum_auth_jwt)
- [dshackle](roles/dshackle)

### Ethereum client pair
- [ethereum_node](roles/ethereum_node)
### Ethereum execution clients
- [besu](roles/besu)
- [geth](roles/geth)
- [erigon](roles/erigon)
- [nethermind](roles/nethermind)
- [ethereumjs](roles/ethereumjs)
### Ethereum consensus clients
- [teku](roles/teku)
- [nimbus](roles/nimbus)
- [prysm](roles/prysm)
- [lodestar](roles/lodestar)
- [lighthouse](roles/lighthouse)

### Ethereum L2 clients
- [arbitrum_node](roles/arbitrum_node)

### General purpose tooling
- [k3s](roles/k3s)
- [json_exporter](roles/json_exporter)
- [node_exporter](roles/node_exporter)
- [prometheus](roles/prometheus)
- [docker_cleanup](roles/docker_cleanup)
- [docker_network](roles/docker_network)
- [docker_nginx_proxy](roles/docker_nginx_proxy)
- [bootstrap](roles/bootstrap)
- [oh_my_zsh](roles/oh_my_zsh)
- [litestream](roles/litestream)

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
