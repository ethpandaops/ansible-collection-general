# ethpandaops.general.dns_server

Setup a BIND9 DNS server with support for primary/secondary configurations, TSIG-authenticated dynamic updates for ACME DNS-01 challenges, and custom zone management.

## Requirements

You'll need docker on the target system. Make sure to install it upfront.

## Role Variables

Default variables are defined in [defaults/main.yaml](defaults/main.yaml)

### Key Variables

- `dns_server_zones`: List of DNS zones to serve. Each zone should have a `zone` key with the domain name and a `content` key with the zone file content.
- `dns_server_is_master`: Set to `true` for primary (master) servers, `false` for secondary (slave) servers.
- `dns_server_master`: List of primary server IPs (for secondaries to pull zones from).
- `dns_server_slave`: List of secondary server IPs (for primaries to notify and allow zone transfers to).
- `dns_server_acme_zone`: The zone to permit dynamic ACME DNS-01 updates for wildcard certificates (e.g., "s.example.ethpandaops.io").
- `dns_server_tsig_enabled`: Enable TSIG authentication for secure dynamic updates (default: `true`).
- `dns_server_tsig_key_name`: Name of the TSIG key for ACME updates (default: "acme-wildcard").
- `dns_server_disable_systemd_resolved`: Disable systemd-resolved stub listener on port 53 (default: `false`).

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

### Primary DNS Server

```yaml
- hosts: dns_primary
  become: true
  roles:
  - role: geerlingguy.docker
  - role: geerlingguy.pip
    pip_install_packages:
    - name: docker
  - role: ethpandaops.general.dns_server
    vars:
      dns_server_is_master: true
      dns_server_slave:
        - "10.0.0.11"
        - "10.0.0.12"
      dns_server_acme_zone: "s.example.ethpandaops.io"
      dns_server_zones:
        - zone: "example.ethpandaops.io"
          content: |
            $TTL 86400
            @       IN      SOA     ns1.example.ethpandaops.io. admin.example.ethpandaops.io. (
                                    000000000000      ; Serial
                                    3600              ; Refresh
                                    1800              ; Retry
                                    604800            ; Expire
                                    86400 )           ; Negative Cache TTL
            @       IN      NS      ns1.example.ethpandaops.io.
            @       IN      NS      ns2.example.ethpandaops.io.
            ns1     IN      A       10.0.0.10
            ns2     IN      A       10.0.0.11
        - zone: "s.example.ethpandaops.io"
          content: |
            $TTL 86400
            @       IN      SOA     ns1.example.ethpandaops.io. admin.example.ethpandaops.io. (
                                    000000000000      ; Serial
                                    3600              ; Refresh
                                    1800              ; Retry
                                    604800            ; Expire
                                    86400 )           ; Negative Cache TTL
            @       IN      NS      ns1.example.ethpandaops.io.
            @       IN      NS      ns2.example.ethpandaops.io.
```

### Secondary DNS Server

```yaml
- hosts: dns_secondary
  become: true
  roles:
  - role: geerlingguy.docker
  - role: geerlingguy.pip
    pip_install_packages:
    - name: docker
  - role: ethpandaops.general.dns_server
    vars:
      dns_server_is_master: false
      dns_server_master:
        - "10.0.0.10"
      dns_server_zones:
        - zone: "example.ethpandaops.io"
        - zone: "s.example.ethpandaops.io"
```

## Features

- **Primary/Secondary Architecture**: Supports both primary (master) and secondary (slave) DNS servers with automatic zone transfers and NOTIFY.
- **TSIG Authentication**: Secure dynamic updates using TSIG keys, perfect for ACME DNS-01 challenges.
- **Dynamic Updates**: Allows automated updates to `_acme-challenge` records for wildcard certificate issuance.
- **Zone Validation**: Optional zone checking before deployment to ensure valid DNS records.
- **Automatic Serial Management**: Monotonically increasing zone serials based on date and existing serial numbers.
- **systemd-resolved Compatibility**: Can disable systemd-resolved stub listener when needed.

## ACME DNS-01 Integration

This role is designed to work with ACME clients for DNS-01 challenges. When `dns_server_acme_zone` is configured:

1. The role generates a TSIG key for secure updates
2. Only the `_acme-challenge.<acme_zone>` TXT record can be updated
3. The TSIG key is stored at `{{ dns_server_tsig_keysdir }}/{{ dns_server_tsig_key_name }}.key`
4. Use this key with your ACME client to perform DNS-01 challenges

Example with certbot:
```bash
certbot certonly \
  --dns-rfc2136 \
  --dns-rfc2136-credentials /path/to/rfc2136.ini \
  -d "*.s.example.ethpandaops.io"
```