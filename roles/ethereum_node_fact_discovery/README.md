# ethpandaops.general.ethereum_node_fact_discovery

This role is intended to be used together with the `ethpandaops.general.ethereum_node` role.
The purpose is to try to find and set facts about your running ethereum nodes.

## Requirements

You'll need docker on the ansible controller host. Make sure to install it upfront.

## Role Variables

Default variables are defined in [defaults/main.yaml](defaults/main.yaml)

## Facts

The following facts can be discovered and set when using this role:

- `ethereum_node_fact_el_enode` - Execution client enode
- `ethereum_node_fact_cl_enr` - Consenus client ENR
- `ethereum_node_fact_cl_peer_id` - Consensus client peer id

## Dependencies

You'll need docker installed locally to run this role.
