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
- Installs ndppd, enables IPv6 forwarding, sets `accept_ra=2` so the host keeps
  its default route, configures ndppd to proxy NDP for the public IPv6 subnet.
- Creates the bridge with a ULA private subnet only
  (`docker_network_ipv6_private_subnet`, default `fde7:f00d::/64`). Docker's
  bridge driver allows only one IPv6 subnet per network, so the public subnet
  passed via `docker_network_ipam_config` is **not** added to the bridge.
- Adds an on-link bridge route for the public pool and an `ip6tables`
  MASQUERADE rule for ULA egress, so ULA-only containers reach the internet
  via the host's own public IPv6.
- Installs `docker-public-ipv6-injector.service`: a host-side daemon that
  watches Docker `start` events and runs `nsenter -t <pid> -n ip -6 addr add
  <addr>/128 dev eth0` for every container carrying the
  `org.ethpandaops.public_ipv6=<addr>` label. Containers tagged this way get
  their public IPv6 directly on `eth0` alongside the auto-assigned ULA — no
  `iproute2` needed in the image, and no Docker IPAM clash.

Set `docker_network_ipv6_private_subnet: ""` to disable the hybrid setup and
fall back to the legacy single-subnet behaviour (public IPv6 via the bridge's
own IPAM).

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
