# Migration Guide: cl_bootnode → lighthouse_bootnode

This guide explains how to migrate from `ethpandaops.general.cl_bootnode` to `ethpandaops.general.lighthouse_bootnode`.

## Why Migrate?

The `lighthouse_bootnode` role uses Lighthouse's built-in `boot_node` subcommand, which:
- Has a reduced attack surface compared to a full beacon node
- Is officially supported by the Lighthouse team
- Provides the same bootnode functionality with better integration
- Eliminates dependency on the external `protolambda/eth2-bootnode` tool

## Quick Migration (Drop-in Replacement)

The `lighthouse_bootnode` role is designed as a **drop-in replacement** for `cl_bootnode`.

### Step 1: Update Playbook

```yaml
# Before
- role: ethpandaops.general.cl_bootnode
  tags: [cl_bootnode]

# After
- role: ethpandaops.general.lighthouse_bootnode
  tags: [lighthouse_bootnode, bootnode]
```

### Step 2: No Variable Changes Required!

If you're using the standard variables, **no changes are needed**:

```yaml
# This works with both roles (backward compatible)
cl_bootnode_privkey: "{{ secret_bootnode_privkey }}"
```

The `lighthouse_bootnode` role automatically recognizes `cl_bootnode_privkey` and maps it to `lighthouse_bootnode_privkey`.

## Compatibility Matrix

| Old Variable (`cl_bootnode`) | New Variable (`lighthouse_bootnode`) | Auto-mapped? |
|------------------------------|-------------------------------------|--------------|
| `cl_bootnode_privkey` | `lighthouse_bootnode_privkey` | ✅ Yes |
| `cl_bootnode_set_facts` | `lighthouse_bootnode_set_facts` | ✅ Yes |
| `cl_bootnode_p2p_port` | `lighthouse_bootnode_p2p_port` | ⚠️ Use new name |
| `cl_bootnode_api_port` | `lighthouse_bootnode_api_port` | ⚠️ Use new name |
| `cl_bootnode_datadir` | `lighthouse_bootnode_datadir` | ⚠️ Use new name |

### Facts Set

Both roles set the same facts:
- `cl_bootnode_fact_enr` - ✅ Available in both roles
- `lighthouse_bootnode_fact_enr` - ✅ New fact (only in lighthouse_bootnode)

## Complete Migration Example

### Before (using cl_bootnode)

**playbook.yaml:**
```yaml
- hosts: bootnode
  become: true
  roles:
    - role: ethpandaops.general.cl_bootnode
      tags: [cl_bootnode]
```

**group_vars/bootnode.yaml:**
```yaml
cl_bootnode_privkey: "{{ secret_cl_bootnode_privkey }}"
```

**Usage in other files:**
```yaml
ethereum_cl_bootnodes:
  - "{{ hostvars['bootnode-1']['cl_bootnode_fact_enr'] }}"
```

### After (using lighthouse_bootnode with backward compatibility)

**playbook.yaml:**
```yaml
- hosts: bootnode
  become: true
  roles:
    - role: ethpandaops.general.lighthouse_bootnode  # Just change the role name
      tags: [lighthouse_bootnode, bootnode]
```

**group_vars/bootnode.yaml:**
```yaml
# Option 1: Keep using old variable name (backward compatible)
cl_bootnode_privkey: "{{ secret_cl_bootnode_privkey }}"

# Option 2: Use new variable name (recommended for new deployments)
lighthouse_bootnode_privkey: "{{ secret_lighthouse_bootnode_privkey }}"
lighthouse_bootnode_container_image: "{{ default_ethereum_client_images.lighthouse }}"
lighthouse_bootnode_container_pull: true
lighthouse_bootnode_container_volumes:
  - "{{ lighthouse_bootnode_datadir }}:/data"
  - "{{ eth_testnet_config_dir }}:/network-config:ro"
lighthouse_bootnode_container_command_extra_args:
  - --testnet-dir=/network-config
```

**Usage in other files:**
```yaml
# No changes needed - still works!
ethereum_cl_bootnodes:
  - "{{ hostvars['bootnode-1']['cl_bootnode_fact_enr'] }}"
```

## Testing the Migration

After updating your playbook:

1. **Run the playbook:**
   ```bash
   ansible-playbook -i inventories/devnet-0/inventory.ini playbook.yaml --tags lighthouse_bootnode
   ```

2. **Verify the bootnode is running:**
   ```bash
   ssh bootnode-1 "docker ps | grep lighthouse-bootnode"
   ```

3. **Check the ENR fact is set:**
   ```bash
   ansible -i inventories/devnet-0/inventory.ini bootnode-1 -m debug -a "var=cl_bootnode_fact_enr"
   ```

4. **Verify peers can connect:**
   Check your beacon nodes' logs for successful bootnode connections.

## Rollback Plan

If you need to rollback to `cl_bootnode`:

1. **Stop the lighthouse bootnode:**
   ```bash
   ssh bootnode-1 "docker stop lighthouse-bootnode && docker rm lighthouse-bootnode"
   ```

2. **Revert playbook changes:**
   ```yaml
   - role: ethpandaops.general.cl_bootnode
     tags: [cl_bootnode]
   ```

3. **Run the playbook:**
   ```bash
   ansible-playbook -i inventories/devnet-0/inventory.ini playbook.yaml --tags cl_bootnode
   ```

## Advanced: Custom Testnet Configuration

For custom testnets (like devnets), you need to mount the testnet config:

```yaml
lighthouse_bootnode_container_volumes:
  - "{{ lighthouse_bootnode_datadir }}:/data"
  - "{{ eth_testnet_config_dir }}:/network-config:ro"

lighthouse_bootnode_container_command_extra_args:
  - --testnet-dir=/network-config
```

This ensures the bootnode uses the correct network configuration.

## FAQ

**Q: Do I need to change my secret variables?**
A: No, you can keep using `cl_bootnode_privkey` or rename to `lighthouse_bootnode_privkey`.

**Q: Will my existing ENR change?**
A: Only if you change the private key. Using the same key will produce the same ENR.

**Q: What if I want to use a different port?**
A: Override `lighthouse_bootnode_p2p_port` (default: 9010).

**Q: Can I run both roles simultaneously for testing?**
A: Yes, they use different container names and can coexist.

## Support

For issues or questions, refer to:
- [lighthouse_bootnode README](README.md)
- [Lighthouse documentation](https://lighthouse-book.sigmaprime.io/)
