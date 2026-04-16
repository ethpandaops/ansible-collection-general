# ethpandaops.general.docker_network

This role creates a docker network. When IPv6 is enabled, it automatically installs and configures ndppd (NDP Proxy Daemon) so containers are reachable on their public IPv6 addresses.

## Requirements

You'll need docker on the target system. Make sure to install it upfront.

## Role Variables

Default variables are defined in [defaults/main.yaml](defaults/main.yaml)

### IPv6 with routed mode

To give containers public IPv6 addresses with NDP proxy:

```yaml
docker_network_name: "shared"
docker_network_enable_ipv6: true
docker_network_driver_options:
  com.docker.network.bridge.gateway_mode_ipv6: routed
docker_network_ipam_config:
  - subnet: "2a01:4f8:x:y::/64"
    gateway: "2a01:4f8:x:y::2"
```

When `docker_network_enable_ipv6` is `true`, the role automatically:
- Installs ndppd
- Enables IPv6 forwarding
- Sets `accept_ra=2` so the host keeps its default route
- Configures ndppd to proxy NDP for the IPv6 subnet

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

Your playbook could look like this:

```yaml
- hosts: localhost
  become: true
  roles:
  - role: geerlingguy.docker
  - role: geerlingguy.pip
    pip_install_packages:
    - name: docker
  - role: ethpandaops.general.docker_network
    docker_network_name: "shared"
```
