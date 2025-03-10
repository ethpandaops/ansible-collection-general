# snapshot_fetcher

This role downloads and extracts Ethereum node snapshots from ethpandaops.io. Supports multiple networks and clients.

## Requirements

- curl
- tar
- zstd
- jq

## Role Variables

Default variables are defined in [defaults/main.yaml](defaults/main.yaml)

## Example Playbook

```yaml
- hosts: localhost
  become: true
  roles:
  - role: snapshot_fetcher
``` 