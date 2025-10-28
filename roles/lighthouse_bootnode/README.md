# ethpandaops.general.lighthouse_bootnode

This role runs a Lighthouse bootnode within a Docker container using Lighthouse's built-in `boot_node` subcommand. This is a reduced attack surface alternative to running a full beacon node as a bootnode.

## Requirements

You'll need Docker on the target system. Make sure to install it upfront.

## Role Variables

Default variables are defined in [defaults/main.yaml](defaults/main.yaml)

### Key Variables

- `lighthouse_bootnode_enabled`: Enable/disable the bootnode (default: `true`)
- `lighthouse_bootnode_cleanup`: When set to true, removes the container (default: `false`)
- `lighthouse_bootnode_privkey`: The secp256k1 private key for the bootnode (hex-encoded, without 0x prefix)
- `lighthouse_bootnode_container_image`: Docker image for the bootnode (default: `sigp/lighthouse:latest`)
- `lighthouse_bootnode_lcli_image`: Docker image for lcli tool (default: `sigp/lcli:latest`)
- `lighthouse_bootnode_p2p_port`: P2P port for the bootnode (default: `9010`)
- `lighthouse_bootnode_announced_ip`: The IP address to broadcast to peers (default: `{{ ansible_host }}`)
- `lighthouse_bootnode_datadir`: Data directory path (default: `/data/lighthouse-bootnode`)
- `lighthouse_bootnode_boot_nodes`: Comma-separated list of initial boot nodes (ENR/multiaddr format)
- `lighthouse_bootnode_genesis_fork_version`: Genesis fork version for ENR generation (default: `0x00000000` for mainnet)
- `lighthouse_bootnode_testnet_config_dir`: Path to testnet config directory to auto-detect genesis fork version
- `lighthouse_bootnode_container_command_extra_args`: Additional CLI arguments to pass to lighthouse boot_node

## Drop-in Replacement for cl_bootnode

This role is designed as a drop-in replacement for the `ethpandaops.general.cl_bootnode` role. It maintains backward compatibility by:

- **Setting the same facts**: Both `cl_bootnode_fact_enr` and `lighthouse_bootnode_fact_enr` are set
- **Using the same ports**: Defaults to ports 9010 (P2P) and 8002 (API), matching cl_bootnode
- **Supporting old variable names**:
  - `cl_bootnode_privkey` → automatically mapped to `lighthouse_bootnode_privkey`
  - `cl_bootnode_set_facts` → automatically mapped to `lighthouse_bootnode_set_facts`

To migrate from `cl_bootnode` to `lighthouse_bootnode`, simply replace the role name in your playbook:

```yaml
# Old
- role: ethpandaops.general.cl_bootnode

# New
- role: ethpandaops.general.lighthouse_bootnode
```

No other configuration changes are required if you're using the standard `cl_bootnode_privkey` variable.

## Facts

This role will set some facts which allow you to access the following data via hostvars:

- `cl_bootnode_fact_enr` - Public ENR for the bootnode (for backward compatibility with cl_bootnode)
- `lighthouse_bootnode_fact_enr` - Public ENR for the bootnode

## Dependencies

You'll need Docker to run this role. One way of installing Docker could be via Ansible Galaxy with the following dependencies set within `requirements.yaml`:

```yaml
roles:
- src: geerlingguy.docker
  version: latest
- src: geerlingguy.pip
  version: latest
```

## Example Playbook

Your playbook could look like this:

```yaml
- hosts: bootnode
  become: true
  vars:
    lighthouse_bootnode_privkey: "your_private_key_here"
  roles:
  - role: geerlingguy.docker
  - role: geerlingguy.pip
    pip_install_packages:
    - name: docker
  - role: ethpandaops.general.lighthouse_bootnode
```

## How it Works

1. Creates a data directory for the bootnode at `/data/lighthouse-bootnode`
2. Writes the private key to `/data/lighthouse-bootnode/beacon/network/key`
3. **Pre-generates the ENR** using Lighthouse's `--dump-config` and `--immediate-shutdown` flags:
   - Runs `lighthouse boot_node --datadir=/data --dump-config=/data/config.json --immediate-shutdown`
   - Lighthouse generates ENR deterministically from the private key
   - Creates `/data/lighthouse-bootnode/beacon/network/enr.dat` (base64 ENR)
   - Writes full configuration to `/data/lighthouse-bootnode/config.json` (JSON with `local_enr` field)
   - Process exits immediately without starting the bootnode
4. Extracts the ENR from `config.json` using JSON parsing
5. Sets the ENR as Ansible facts (`cl_bootnode_fact_enr` and `lighthouse_bootnode_fact_enr`)
6. Runs Lighthouse in `boot_node` mode using the generated network directory

### ENR Generation

The role uses Lighthouse's hidden `--dump-config` and `--immediate-shutdown` flags to generate ENRs from known private keys. This approach:
- **Generates deterministic ENRs** (same key + same IP/port = same ENR)
- **Uses your provided private key** (from `lighthouse_bootnode_privkey` variable)
- **Creates both `enr.dat` and `config.json`** for easy parsing and verification
- **Exits immediately** after generation (no bootnode started)
- **No external tools required** (no need for `lcli`)

**Directory Structure:**
```
/data/lighthouse-bootnode/
├── beacon/
│   └── network/
│       ├── key         # Your private key (64 hex chars)
│       └── enr.dat     # Generated ENR (auto-created)
└── config.json         # Full config with ENR (auto-created)
```

### Genesis Fork Version

The genesis fork version is used during ENR generation. The role automatically detects it in this order:

1. **Auto-detection from testnet config** (if `lighthouse_bootnode_testnet_config_dir` is set):
   - Reads `GENESIS_FORK_VERSION` from `config.yaml`
   - Example: `lighthouse_bootnode_testnet_config_dir: "{{ eth_testnet_config_dir }}"`

2. **Explicit configuration**:
   - Set `lighthouse_bootnode_genesis_fork_version: "0x12345678"`

3. **Default value**: `0x00000000` (Ethereum mainnet)

Common values:
- Mainnet: `0x00000000`
- Sepolia: `0x90000069`
- Holesky: `0x01017000`
- Custom networks: Check your `config.yaml`

### Lighthouse boot_node CLI Flags Used

**For ENR Generation:**
- `--datadir=/data` - Data directory containing the private key
- `--enr-address=<IP>` - Public IP address to advertise
- `--port=<PORT>` - UDP/TCP port for P2P
- `--dump-config=/data/config.json` - Write config with ENR to JSON file
- `--immediate-shutdown` - Exit immediately after generating ENR

**For Running the Bootnode:**
- `--network-dir=/data/beacon/network` - Directory containing generated ENR and network key
- `--listen-address=0.0.0.0` - Listen on all interfaces
- `--port=9010` - UDP port for P2P (configurable via `lighthouse_bootnode_p2p_port`)
- `--disable-packet-filter` - Useful for testing in smaller/private networks

Additional flags can be added via `lighthouse_bootnode_container_command_extra_args`.

### Custom Networks

For custom testnets, simply point to your testnet config directory:

```yaml
lighthouse_bootnode_testnet_config_dir: "{{ eth_testnet_config_dir }}"
```

The role will automatically:
- Read the `GENESIS_FORK_VERSION` from `config.yaml`
- Generate the ENR with the correct fork version
- Start the bootnode with the appropriate configuration

No additional flags or volume mounts are needed!
