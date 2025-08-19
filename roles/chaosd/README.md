# ethpandaops.general.chaosd

This role installs and configures [Chaosd](https://chaos-mesh.org/docs/chaosd-overview/), a physical node chaos engineering tool for simulating chaos scenarios on physical machines.

Chaosd is a chaos engineering tool that can inject various types of faults into physical nodes:
- Process chaos (kill processes, stop processes)
- Network chaos (network delay, packet loss, network partition)
- Stress chaos (CPU stress, memory stress)
- Disk chaos (disk read/write errors, disk fill)
- Host chaos (shutdown, time chaos)

## Requirements

- Linux system (x86_64 or ARM64)
- Root privileges (chaosd requires root access for most chaos experiments)
- Systemd for service management

## Role Variables

Default variables are defined in [defaults/main.yaml](defaults/main.yaml)

### Core Configuration

- `chaosd_version`: Version of chaosd to install (default: `v1.4.0`)
- `chaosd_install_dir`: Installation directory (default: `/opt/chaosd`)
- `chaosd_port`: Port for chaosd HTTP server (default: `31767`)
- `chaosd_state`: Whether chaosd should be present or absent (default: `present`)

### Service Configuration

- `chaosd_service_enabled`: Enable chaosd service on boot (default: `true`)
- `chaosd_service_restart_sec`: Restart delay in seconds (default: `5`)

### Network Configuration

- `chaosd_iface`: Primary network interface for network chaos experiments (default: `eth0`)

### Security Configuration

- `chaosd_sha256`: SHA256 checksum for download verification (default: `auto_fill_sha256_here`)

### Docker Nginx Proxy Integration

- `chaosd_nginx_proxy_enabled`: Enable integration with docker_nginx_proxy role (default: `false`)
- `chaosd_nginx_proxy_hostname`: Hostname for proxy routing (default: `"chaos.{{ inventory_hostname }}"`)

**Note**: This integration adds nginx configuration files directly to the existing `docker_nginx_proxy` infrastructure to route traffic to the chaosd systemd service. The `docker_nginx_proxy` role must be deployed first.

## Dependencies

None

## Example Playbook

### Basic Installation

```yaml
- hosts: chaos_nodes
  become: true
  roles:
    - role: ethpandaops.general.chaosd
```

### Custom Configuration

```yaml
- hosts: chaos_nodes
  become: true
  roles:
    - role: ethpandaops.general.chaosd
      vars:
        chaosd_port: 8080
        chaosd_iface: ens3
        chaosd_version: v1.4.0
```

### With Docker Nginx Proxy Integration

First deploy the docker_nginx_proxy role, then chaosd:

```yaml
- hosts: chaos_nodes
  become: true
  roles:
    - role: ethpandaops.general.docker_nginx_proxy
      vars:
        docker_nginx_proxy_default_email: "admin@yourdomain.com"
    - role: ethpandaops.general.chaosd
      vars:
        chaosd_nginx_proxy_enabled: true
        chaosd_nginx_proxy_hostname: "chaos.{{ inventory_hostname }}.yourdomain.com"
        chaosd_nginx_proxy_container_env:
          VIRTUAL_HOST: "chaos.{{ inventory_hostname }}.yourdomain.com"
          VIRTUAL_PORT: "80"
          VIRTUAL_PROTO: "http"
          LETSENCRYPT_HOST: "chaos.{{ inventory_hostname }}.yourdomain.com"
          LETSENCRYPT_EMAIL: "admin@yourdomain.com"
```

### Removal

```yaml
- hosts: chaos_nodes
  become: true
  roles:
    - role: ethpandaops.general.chaosd
      vars:
        chaosd_state: absent
```

## Usage

After installation, chaosd will be running as a systemd service on the configured port. You can interact with it using:

### Command Line Interface

```bash
# Show chaosd status
sudo systemctl status chaosd

# View chaosd logs
sudo journalctl -u chaosd -f

# Execute chaos experiments directly
{{ chaosd_install_dir }}/chaosd attack process kill --process nginx
```

### HTTP API

Chaosd exposes a REST API on the configured port:

```bash
# Get chaosd status
curl http://localhost:31767/api/experiments

# Create a process chaos experiment
curl -X POST http://localhost:31767/api/attack/process \
  -H "Content-Type: application/json" \
  -d '{"action": "kill", "process": "nginx"}'
```

## Security Considerations

- Chaosd runs with root privileges as it needs system-level access for chaos experiments
- The HTTP API is exposed without authentication by default - consider firewall rules
- Only run chaosd in controlled environments as it can disrupt system operations
- Be cautious with disk and network chaos experiments as they can cause data loss or network partitions

## License

This role is part of the ethpandaops.general collection.