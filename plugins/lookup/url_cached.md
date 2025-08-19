# Lookup plugin: url_cached

The `url_cached` lookup plugin is an enhancement to Ansible's built-in `url` lookup. It adds robust local file caching to reduce network traffic and improve playbook execution times by avoiding redundant HTTP requests for the same URL.

## Features

- **Local file caching**: Stores URL responses in a local cache directory
- **Configurable TTL**: Control how long cached responses remain valid
- **Thread-safe**: Uses file locking to prevent race conditions when multiple tasks request the same URL simultaneously
- **Force refresh**: Option to bypass cache and force a fresh request
- **Custom cache directory**: Configure where cached responses are stored
- **Full HTTP options**: Supports all the same options as Ansible's standard URL lookup

## Usage

Basic usage involves specifying a URL to retrieve:

```yaml
- name: Get content from URL with caching
  debug:
    msg: "{{ lookup('ethpandaops.general.url_cached', 'https://api.example.com/data.json') }}"
```

### Options

The plugin supports several options to customize behavior:

| Option | Default | Description |
|--------|---------|-------------|
| `cache_dir` | `/tmp/ansible/url_cache` | Directory to store cached responses |
| `cache_ttl` | 600 | Time in seconds to consider cached responses valid |
| `force_refresh` | False | Whether to bypass cache and force a new request |
| `split_lines` | True | Return content as line-by-line list or as a single string |

Additionally, all standard URL lookup options are supported:

- `validate_certs`: Control SSL certificate validation
- `username`/`password`: HTTP Basic Authentication
- `headers`: Custom HTTP headers
- And many more (see Ansible URL lookup documentation)

### Examples

**Basic usage:**

```yaml
- name: Get GitHub keys with caching
  debug:
    msg: "{{ item }}"
  loop: "{{ lookup('ethpandaops.general.url_cached', 'https://github.com/gremlin.keys', wantlist=True) }}"
```

**Return JSON response as a single string with longer TTL:**

```yaml
- name: Get AWS IP ranges with longer cache TTL
  debug:
    msg: "{{ lookup('ethpandaops.general.url_cached', 'https://ip-ranges.amazonaws.com/ip-ranges.json', split_lines=False, cache_ttl=3600) }}"
```

**Force a refresh, ignoring cached content:**

```yaml
- name: Force refresh cached content
  debug:
    msg: "{{ lookup('ethpandaops.general.url_cached', 'https://some.private.site.com/file.txt',
            username='bob', password='hunter2', force_refresh=True) }}"
```

**Custom cache directory:**

```yaml
- name: Use custom cache directory
  debug:
    msg: "{{ lookup('ethpandaops.general.url_cached', 'https://some.private.site.com/api/service',
            cache_dir='/tmp/my_url_cache') }}"
```

## Thread Safety

The plugin implements file-based locking to prevent race conditions in multi-threaded environments. When multiple Ansible tasks attempt to access the same URL simultaneously:

1. The first thread to acquire the lock makes the HTTP request
2. Other threads wait for the lock to be released
3. Once the cache file is populated, subsequent threads use the cached data instead of making redundant requests

This ensures that even when running Ansible with high parallelism or using `async` tasks, each unique URL is only requested once during the cache TTL period.

## Configuration

You can configure defaults using Ansible variables, environment variables, or ansible.cfg:

```yaml
# In a playbook or vars file
ansible_lookup_url_cache_dir: "/path/to/cache"
ansible_lookup_url_cache_ttl: 3600
ansible_lookup_url_force_refresh: False
```

Or in your environment:

```bash
export ANSIBLE_LOOKUP_URL_CACHE_DIR="/path/to/cache"
export ANSIBLE_LOOKUP_URL_CACHE_TTL=3600
export ANSIBLE_LOOKUP_URL_FORCE_REFRESH=False
```

Or in ansible.cfg:

```ini
[url_lookup]
cache_dir = /path/to/cache
cache_ttl = 3600
force_refresh = False
```

## Requirements

- Python `fcntl` module (standard on most Unix-like systems)
- Standard Ansible URL lookup dependencies
