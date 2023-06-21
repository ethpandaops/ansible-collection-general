# ethpandaops.general.hetzner_vswitch

This role modifies the network configuration of a Hetzner dedicated server to use a [vSwitch](https://docs.hetzner.com/robot/dedicated-server/network/vswitch/#how-do-i-setup-a-vswitch).

## Requirements

None

## Role Variables

Default variables are defined in [defaults/main.yaml](defaults/main.yaml)

To clean up the installation you can use the `hetzner_vswitch_cleanup=true` variable.

## Dependencies

None

## Example Playbook

Your playbook could look like this:

```yaml
- hosts: dedicated_servers
  become: true
  roles:
    - role: hetzner_vswitch
      vars:
        interface_name: enp0s31f6 # This is the name of the interface to be used
        vlan_id: 4000 # This is the VLAN ID of the vSwitch
        ip_address: 10.0.0.2 # This is the IP of the server
        netmask: 255.255.255.0
        gateway: 10.0.0.1 # This is the IP of the vSwitch gateway
        mtu: 1400
        network: 10.0.0.0/16 # This is the network subnet of the vSwitch
```
