# ethpandaops.general.wildcard_cert_issuer

Request and automatically renew wildcard certificates using DNS challenges via the ACME protocol with RFC2136 (BIND TSIG) DNS updates.

This role creates a Docker container running Certbot that:
- Issues wildcard certificates for your domain
- Automatically renews certificates every 12 hours (configurable)
- Uses RFC2136 DNS updates with TSIG authentication for DNS challenges
- Optionally publishes encrypted certificates via HTTP for secure distribution

## Requirements

You'll need docker on the target system. Make sure to install it upfront.

## Role Variables

Default variables are defined in [defaults/main.yaml](defaults/main.yaml)

### Key Variables

- `wildcard_cert_issuer_base_domain`: The base domain to request certificates for (e.g., "example.com")
- `wildcard_cert_issuer_email`: Email address for ACME registration
- `wildcard_cert_issuer_rfc2136_server`: DNS server address for RFC2136 updates
- `wildcard_cert_issuer_tsig_keyfile`: Path to BIND TSIG key file for DNS authentication
- `wildcard_cert_issuer_publish_enabled`: Enable encrypted certificate publishing (default: true)
- `wildcard_cert_issuer_publish_psk`: Pre-shared key for certificate encryption (use Ansible Vault)

### Certificate Publishing

When publishing is enabled, the role:
1. Packages issued certificates into a tar.gz archive
2. Encrypts the archive using OpenSSL with a pre-shared key
3. Serves the encrypted files via HTTP on a configurable port
4. Updates a "latest" symlink for easy retrieval

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
  vars:
    wildcard_cert_issuer_base_domain: "example.com"
    wildcard_cert_issuer_email: "admin@example.com"
    wildcard_cert_issuer_rfc2136_server: "10.0.0.1"
    wildcard_cert_issuer_tsig_keyfile: "/data/dns_server/keys/acme-wildcard.key"
    wildcard_cert_issuer_publish_psk: !vault |
      $ANSIBLE_VAULT;1.1;AES256
      66383439383...
  roles:
  - role: geerlingguy.docker
  - role: geerlingguy.pip
    pip_install_packages:
    - name: docker
  - role: ethpandaops.general.wildcard_cert_issuer
```

## How it Works

1. The role creates a Certbot container configured for DNS-01 challenges
2. On first run, it requests certificates for the base domain and wildcard subdomain
3. The container runs a renewal loop, checking for certificate renewal every 12 hours
4. When certificates are issued or renewed, a deploy hook packages and encrypts them
5. If publishing is enabled, encrypted certificates are served via HTTP

## Retrieving Published Certificates

To download and decrypt published certificates:

```bash
# Download the encrypted certificate
curl -O http://your-server/example.com-latest.tar.enc

# Decrypt with your PSK
echo -n "YOUR_PSK" | openssl enc -aes-256-cbc -d -salt -pass stdin \
  -in example.com-latest.tar.enc -out example.com.tar.gz

# Extract certificates
tar -xzf example.com.tar.gz
```