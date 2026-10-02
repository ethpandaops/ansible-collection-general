# snapshot_fetcher

This role downloads and extracts Ethereum node snapshots from ethpandaops.io. Supports multiple networks and clients.

The snapshot is streamed straight into `tar`, resuming by byte offset if the
connection drops, so only the extracted datadir needs disk space. A snapshot
server that does not support HTTP range requests cannot be resumed and the
download fails with that message rather than retrying indefinitely.

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
