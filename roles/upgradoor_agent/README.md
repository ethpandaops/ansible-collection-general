# ethpandaops.general.upgradoor_agent

Installs the [upgradoor](https://github.com/ethpandaops/upgradoor) agent on a devnet host. The agent polls the devnet's controller (the `upgradoor` chart of [generate_kubernetes_config](../generate_kubernetes_config)) and rolls containers, upgrades blocked packages and reboots when the controller grants it a slot.

The role:

- copies `files/install.sh` to the host, which downloads the release's manifest, signature and binary from GitHub, verifies them against the pinned `files/allowed_signers`, refuses downgrades and installs the binary to `/usr/local/bin/upgradoor`,
- lets the host create its own key (ML-DSA-44, `/etc/upgradoor/host.key`, `upgradoor key`); only when the host has no certificate for that key and hostname, issues one on the Ansible controller with `upgradoor-controller keygen host-cert` in the verified release image (by digest, without network) and installs it as `/etc/upgradoor/host.crt`,
- writes `/etc/upgradoor/agent.yaml` (roles, probes, host actions) and, with `upgradoor_agent_overrides`, links the overrides file (the agent writes it) into the entry user's home,
- creates the non-root user `upgradoor` (member of `docker`, state in `/data/upgradoor`) with sudo rules for `/usr/local/lib/upgradoor/upgrade-packages` (accepts only the blocked packages), `/usr/bin/systemctl reboot` and each host action script (`security-upgrades`),
- installs and starts `upgradoor-agent.service` (`KillMode=process`: a running package upgrade survives an agent restart).

## Requirements

- Debian family host with systemd, Docker and sudo; install.sh installs `curl` and `openssh-client` when missing.
- On the Ansible controller: Docker, to issue host certificates in the release image.
- `secret_upgradoor_seed` (devnet sops file). The signer and controller public keys are the same for all devnets and default in the role; `upgradoor_signer_public_key` / `upgradoor_controller_public_key` override them.
- `ethereum_network_name` and `network_subdomain`.

## Role Variables

See [defaults/main.yaml](defaults/main.yaml). The main ones:

| Variable | Default | Description |
|----------|---------|-------------|
| `upgradoor_enabled` | `false` | Global switch: installs the agent and enables the `upgradoor deploy` hook and container labels in the client roles. |
| `upgradoor_agent_version` | `latest` | Release tag `vX.Y.Z`, or `latest` (the latest published release). Only signed releases are installed, never a lower one than a host has. |
| `upgradoor_agent_allowed_signers_file` | `files/allowed_signers` | Release keys the manifest signature is checked against. |
| `upgradoor_agent_reissue` | `false` | Issue the host certificate even when the installed one is current. |
| `upgradoor_agent_roles` | inventory groups out of `upgradoor_agent_role_groups` | The host's roles, reported by the agent. |
| `upgradoor_agent_overrides` | `false` | Opt-in overrides file (`/etc/upgradoor/overrides/overrides.yaml`, linked as `~devops/overrides.yaml`). |
| `upgradoor_agent_default_policy` | `ignore` | Unlabelled containers: `ignore`, or `roll` them when their tag moves. |
| `upgradoor_agent_kind_policies` | `{}` | Per kind `roll`/`ignore`, used only while the controller is unreachable. |
| `upgradoor_agent_state_dir` | `/data/upgradoor` | Agent state (holds, open work) and audit log; wiped with the data dirs. |
| `upgradoor_agent_security_upgrades_action` | `true` | Offer the `security-upgrades` host action (needs unattended-upgrades). |
| `upgradoor_agent_actions` | security-upgrades | Host actions: name -> `{description, command, impact, timeout, feature, teams, when}`. |
| `upgradoor_blocked_packages` | docker packages | Packages only the agent upgrades; shared with [unattended_upgrades](../unattended_upgrades). |
| `upgradoor_deploy` | `soft` | How client roles deploy: `soft`, `force` or `immediate`, see below. |
| `upgradoor_agent_cleanup` | `false` | Remove the agent, its files and state. |

A release older than the installed one (`/etc/upgradoor/release-seq`) is refused; remove that file to downgrade.

## Managed containers and deploy modes

On a host with this agent (`secret_upgradoor_seed` set and `/usr/local/bin/upgradoor` present), the client roles `geth`, `besu`, `nethermind`, `reth`, `lighthouse`, `prysm`, `lodestar` (beacon and validator) and `teku` call `upgradoor deploy <container> --image ... --command ...` before their `docker_container` task. The agent records the image and command in `/etc/upgradoor/managed.yaml` and answers which comparisons Ansible leaves to it and whether Ansible pulls. The containers get the labels `io.ethpandaops.upgradoor.kind` (el, cl, vc, snooper) and `io.ethpandaops.upgradoor.team` (`<role>_upgradoor_team`, `<role>_validator_upgradoor_team`); `<role>_upgradoor_enabled` (default `upgradoor_enabled`) turns hook and labels off per role.

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
```

The scenario builds the binaries and the image from that checkout, pushes the image to a local registry and serves fake releases signed with a throwaway key.
