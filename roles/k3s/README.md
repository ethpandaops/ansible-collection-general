# ethpandaops.general.k3s

This role is based on https://github.com/k3s-io/k3s-ansible/ and will install [k3s](https://github.com/k3s-io/k3s) on your system.

## Requirements

None

## Role Variables

Default variables are defined in [defaults/main.yaml](defaults/main.yaml)

To clean up the installation you can use the `k3s_cleanup=true` variable.
If you also want to remove the `local-path` provisioned volumes, you also need to set `k3s_cleanup_localpath_persistent_volumes=true`.

## Dependencies

None

## Example Playbook

Your playbook could look like this:

```yaml
- hosts: k3s_cluster
  become: true
  roles:
    - role: ethpandaops.general.k3s
```

With an inventory like:

```yaml
all:
  children:
    k3s_cluster:
      children:
        k3s_server:
        k3s_agent:
    k3s_server:
      vars:
        k3s_node_type: server
      hosts:
        berlin-k3s-server-001:
          ansible_host: 10.10.10.10
    k3s_agent:
      vars:
        k3s_node_type: agent
      hosts:
        berlin-k3s-agent-001:
          ansible_host: 10.10.10.11
        berlin-k3s-agent-002:
          ansible_host: 10.10.10.12

```
