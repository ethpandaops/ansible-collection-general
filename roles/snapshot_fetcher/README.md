# snapshot_fetcher

This role downloads and extracts Ethereum node snapshots from ethpandaops.io. Supports multiple networks and clients.

## Requirements

- curl
- jq

## Role Variables

Default variables are defined in [defaults/main.yaml](defaults/main.yaml)

## Example Playbook

```yaml
- hosts: localhost
  become: true
  roles:
  - role: snapshot_fetcher
    snapshot_fetcher_block: 17039999
    snapshot_fetcher_client: besu
    snapshot_fetcher_network: mainnet
    snapshot_fetcher_out_dir: /data/besu

```
