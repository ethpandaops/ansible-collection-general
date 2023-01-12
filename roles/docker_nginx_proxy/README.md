# ethpandaops.general.docker_nginx_proxy

Setup [nginx-proxy](https://github.com/nginx-proxy/nginx-proxy), [docker-gen](https://github.com/nginx-proxy/docker-gen) and [acme-companion](https://github.com/nginx-proxy/acme-companion) to handles the automated creation, renewal and use of SSL certificates for proxied Docker containers through the ACME protocol.

## Requirements

You'll need docker on the target system. Make sure to install it upfront.

## Role Variables

Default variables are defined in [defaults/main.yaml](defaults/main.yaml)

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
  - role: ethpandaops.general.geth
  - role: ethpandaops.general.docker_nginx_proxy
```

Once you have the setup deployed, you can start any arbitrary webapp container with the `VIRTUAL_HOST`, `VIRTUAL_PORT`, `LETSENCRYPT_HOST` and `LETSENCRYPT_EMAIL` env vars.

See the example below:

```bash
$ docker run --detach \
    --name grafana \
    --env "VIRTUAL_HOST=othersubdomain.yourdomain.tld" \
    --env "VIRTUAL_PORT=3000" \
    --env "LETSENCRYPT_HOST=othersubdomain.yourdomain.tld" \
    --env "LETSENCRYPT_EMAIL=mail@yourdomain.tld" \
    grafana/grafana
```
