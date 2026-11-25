# ethpandaops.general.unattended_upgrades

Configures [unattended-upgrades](https://wiki.debian.org/UnattendedUpgrades) on Debian family hosts: security updates only, never the blocked packages, never an automatic reboot. Reboots and the blocked packages are handled by [upgradoor](../upgradoor_agent).

## Requirements

A Debian or Ubuntu host with gathered facts.

## Role Variables

See [defaults/main.yaml](defaults/main.yaml).

| Variable | Default | Description |
|----------|---------|-------------|
| `unattended_upgrades_origins` | security archive of the distribution | `Origins-Pattern` entries. |
| `unattended_upgrades_extra_origins` | `[]` | More `Origins-Pattern` entries. |
| `unattended_upgrades_blocked_packages` | `upgradoor_blocked_packages`, else docker packages | Exact names never upgraded. |
| `unattended_upgrades_blocked_package_patterns` | `[]` | Raw `Package-Blacklist` regular expressions. |
| `unattended_upgrades_keep_conffiles` | `false` | Keep installed conffiles (applies to every apt run). |
| `unattended_upgrades_manage_timers` | `true` | Enable the apt systemd timers. |

## Example Playbook

```yaml
- hosts: all
  become: true
  roles:
    - role: ethpandaops.general.unattended_upgrades
```
