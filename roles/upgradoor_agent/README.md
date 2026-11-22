# ethpandaops.general.upgradoor_agent

Installs the [upgradoor](https://github.com/ethpandaops/upgradoor) agent on a devnet host. The agent polls the devnet's controller (the `upgradoor` chart of [generate_kubernetes_config](../generate_kubernetes_config)) and rolls containers, upgrades blocked packages and reboots when the controller grants it a slot.

The role:

- verifies the signed release on the Ansible controller and installs the binary to `/usr/local/bin/upgradoor`,
- derives the host key and certificate (ML-DSA-44) from the devnet seed into `/etc/upgradoor/host.{key,crt}` with `upgradoor-controller keygen` from the verified release image; certificates are deterministic, so reruns change nothing,
- writes `/etc/upgradoor/agent.yaml` and links the overrides file (the agent writes it) into the entry user's home,
- creates the non-root user `upgradoor` (member of `docker`) with two sudo rules: `/usr/local/lib/upgradoor/upgrade-packages` (accepts only the blocked packages) and `/usr/bin/systemctl reboot`,
- installs and starts `upgradoor-agent.service` (`KillMode=process`: a running package upgrade survives an agent restart).

## Requirements

- Debian family host with systemd, Docker and sudo.
- On the Ansible controller: Docker (keys are derived in the release's controller image, without network) and `ssh-keygen` from OpenSSH 8.2+.
- `secret_upgradoor_seed` (devnet sops file) and `secret_upgradoor_controller_seed` (devnet group sops file), each at least 32 bytes and different from each other.
- `ethereum_network_name` and `network_subdomain`.

## Role Variables

See [defaults/main.yaml](defaults/main.yaml). The main ones:

| Variable | Default | Description |
|----------|---------|-------------|
| `upgradoor_agent_version` | `v0.1.0` | Release tag, exactly `vX.Y.Z`. |
| `upgradoor_agent_allowed_signers_file` | `files/allowed_signers` | Release keys the manifest signature is checked against. |
| `upgradoor_agent_allow_downgrade` | `false` | Allow a release with a lower seq than the installed one. |
| `upgradoor_agent_binary_local_path` | `""` | Install this local binary instead, **unverified** (testing). |
| `upgradoor_agent_keygen_image` | `""` | Derive keys in this image instead of the verified release's, **unverified** (testing). |
| `upgradoor_agent_extra_groups` | `{}` | Merged over the default `execution`/`consensus` groups, e.g. `{execution: {overrides: [image, flags]}}`. |
| `upgradoor_agent_client_owners` | `{}` | Team names per client, e.g. `{lighthouse: [sigp]}`. |
| `upgradoor_agent_extra_containers` | `{}` | Name map entries, e.g. `{dora: {group: tooling, kind: other}}`. |
| `upgradoor_agent_default_group_roll` | `false` | Let unmapped containers follow new digests of their tag. |
| `upgradoor_agent_default_group_exclude` | `[]` | Names or patterns left out of the default group. |
| `upgradoor_agent_fallback_containers` | `[]` | Containers that follow their tags, unstaggered, while the controller is unreachable. |
| `upgradoor_blocked_packages` | docker packages | Packages only the agent upgrades; shared with [unattended_upgrades](../unattended_upgrades). |
| `upgradoor_deploy` | `soft` | How client roles deploy: `soft`, `force` or `immediate`, see below. |
| `upgradoor_agent_cleanup` | `false` | Remove the agent, its files and state. |

`upgradoor_agent_release` is an output of the role (the verified release, including the controller image by digest); never set it.

## Managed containers and deploy modes

On a host with this agent (`secret_upgradoor_seed` set and `/usr/local/bin/upgradoor` present), the client roles `geth`, `besu`, `nethermind`, `reth`, `lighthouse`, `prysm`, `lodestar` (beacon and validator) and `teku` call `upgradoor deploy <container> --image ... --command ...` before their `docker_container` task. The agent records the image and command in the generated block of the overrides file (`/etc/upgradoor/overrides/overrides.yaml`, linked as `~devops/overrides.yaml`) and answers which comparisons Ansible leaves to it and whether Ansible pulls. New containers get the labels `io.ethpandaops.upgradoor.group` (`<role>_upgradoor_group`, `<role>_validator_upgradoor_group`; empty leaves a container unmanaged) and `io.ethpandaops.upgradoor.kind`; containers deployed before the labels are mapped by name in `agent.yaml`.

- `soft`: overrides stay; a managed container that differs keeps running and the agent rolls it, staggered across the devnet. Other changes are deployed directly.
- `force`: like `soft`, but the container's override entry is dropped (holds stay).
- `immediate`: drops the override entry and Ansible recreates the container now.

Disable watchtower (`ethereum_node_docker_watchtower_enabled: false`) on hosts managed by upgradoor.

## Example Playbook

```yaml
- hosts: all
  become: true
  roles:
    - role: ethpandaops.general.unattended_upgrades
    - role: ethpandaops.general.upgradoor_agent
```

## Testing

```sh
cd roles/upgradoor_agent
UPGRADOOR_AGENT_SOURCE=/path/to/upgradoor molecule test
# or with built binaries
UPGRADOOR_AGENT_BINARY=/path/to/upgradoor UPGRADOOR_KEYGEN_IMAGE=<controller image> molecule test
```
