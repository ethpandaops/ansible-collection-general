# ethpandaops.general.k3s

This role is based on https://github.com/k3s-io/k3s-ansible/ and will install [k3s](https://github.com/k3s-io/k3s) on your system.

## Requirements

None

## Role Variables

Default variables are defined in [defaults/main.yaml](defaults/main.yaml)

Agents read their join token from `k3s_agent_token_file`, a root-only file, instead of the unit file.
By default that is the server token. With `k3s_agent_bootstrap_token: true` the role instead mints a
bootstrap token (`k3s token create --ttl k3s_agent_bootstrap_token_ttl`) on the server for each agent
that has not joined yet, and deletes it once the agent's Node exists. Joined agents authenticate with
their kubelet client certificate, so their token file holds only a placeholder with the cluster CA hash,
and restarts and reboots need no token. An agent whose Node object was deleted needs another run of the
role to rejoin. The role reads the agent's node name and certificate expiry with `openssl` on the agent,
so it follows `--node-name` and `--with-node-id`. A join that doesn't finish within `k3s_agent_join_timeout`
seconds fails the run, and the next run starts it again with a fresh token. This needs k3s v1.26.2 or
newer; it was tested on v1.28.13 (the role's default) and v1.32.6.

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
