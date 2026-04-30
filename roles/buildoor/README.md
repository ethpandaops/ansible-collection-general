# ethpandaops.general.buildoor

This role will run [buildoor](https://github.com/ethpandaops/buildoor) within a docker container.

Buildoor is an Ethereum block builder for testing/devnets that supports both ePBS
(Gloas) and the legacy MEV-Boost Builder API. It connects to a beacon node, an
execution Engine API and an execution JSON-RPC. It needs a builder BLS key plus
a pre-funded ECDSA wallet key for on-chain lifecycle operations.

The role wires up all prerequisites (CL/EL endpoints, JWT, keys, ports) but
leaves ePBS and the Builder API disabled at startup. Toggle them at runtime via
the WebUI or by appending `--epbs-enabled` / `--builder-api-enabled` /
`--lifecycle` to `buildoor_container_command_extra_args`.

## Requirements

You'll need docker on the target system. Make sure to install it upfront.

## Role Variables

Default variables are defined in [defaults/main.yml](defaults/main.yml).

The following variables MUST be set by the caller (no sensible defaults):

| Variable | Description |
|----------|-------------|
| `buildoor_builder_privkey` | Builder BLS private key (32 bytes hex) |
| `buildoor_wallet_privkey` | Wallet ECDSA private key (must be pre-funded for lifecycle deposits) |
| `buildoor_cl_client` | Beacon node URL |
| `buildoor_el_engine_api` | Execution Engine API URL |
| `buildoor_el_rpc` | Execution JSON-RPC URL |
| `buildoor_jwt_path` | Host path to the JWT secret used by the EL Engine API |

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

```yaml
- hosts: localhost
  become: true
  roles:
  - role: geerlingguy.docker
  - role: geerlingguy.pip
    pip_install_packages:
    - name: docker
  - role: ethpandaops.general.buildoor
    vars:
      buildoor_builder_privkey: "0x..."
      buildoor_wallet_privkey: "0x..."
      buildoor_cl_client: "http://beacon:5052"
      buildoor_el_engine_api: "http://execution:8551"
      buildoor_el_rpc: "http://execution:8545"
      buildoor_jwt_path: "/data/execution-auth.secret"
```
