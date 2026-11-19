# Based on https://raw.githubusercontent.com/ansible/ansible/refs/heads/devel/lib/ansible/plugins/lookup/url.py
# Adapted by EthPandaOps to use a local cache directory
# (c) 2015, Brian Coca <bcoca@ansible.com>
# (c) 2012-17 Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

from __future__ import annotations

DOCUMENTATION = """
name: url_cached
author: Rafael Matias (@skylenet) <rafael@skyle.net>
version_added: "0.1.0"
short_description: return contents from URL with local file caching
description:
    - Returns the content of the URL requested to be used as data in play.
    - Caches the content locally to avoid repeated HTTP requests.
    - Retries transient failures (timeouts, connection errors, HTTP 408/429/5xx) with exponential backoff.
    - Falls back to an expired cache entry when the URL can not be fetched.
options:
  _terms:
    description: urls to query
  validate_certs:
    description: Flag to control SSL certificate validation
    type: boolean
    default: True
  split_lines:
    description: Flag to control if content is returned as a list of lines or as a single text blob
    type: boolean
    default: True
  use_proxy:
    description: Flag to control if the lookup will observe HTTP proxy environment variables when present.
    type: boolean
    default: True
  username:
    description: Username to use for HTTP authentication.
    type: string
  password:
    description: Password to use for HTTP authentication.
    type: string
  headers:
    description: HTTP request headers
    type: dictionary
    default: {}
  force:
    description: Whether or not to set "cache-control" header with value "no-cache"
    type: boolean
    default: False
    vars:
        - name: ansible_lookup_url_force
    env:
        - name: ANSIBLE_LOOKUP_URL_FORCE
    ini:
        - section: url_lookup
          key: force
  timeout:
    description: How long to wait for the server to send data before giving up
    type: float
    default: 10
    vars:
        - name: ansible_lookup_url_timeout
    env:
        - name: ANSIBLE_LOOKUP_URL_TIMEOUT
    ini:
        - section: url_lookup
          key: timeout
  http_agent:
    description: User-Agent to use in the request.
    type: string
    default: ansible-httpget
    vars:
        - name: ansible_lookup_url_agent
    env:
        - name: ANSIBLE_LOOKUP_URL_AGENT
    ini:
        - section: url_lookup
          key: agent
  force_basic_auth:
    description: Force basic authentication
    type: boolean
    default: False
    vars:
        - name: ansible_lookup_url_force_basic_auth
    env:
        - name: ANSIBLE_LOOKUP_URL_FORCE_BASIC_AUTH
    ini:
        - section: url_lookup
          key: force_basic_auth
  use_gssapi:
    description:
    - Use GSSAPI handler of requests
    - GSSAPI credentials can be specified with O(username) and O(password).
    type: boolean
    default: False
    vars:
        - name: ansible_lookup_url_use_gssapi
    env:
        - name: ANSIBLE_LOOKUP_URL_USE_GSSAPI
    ini:
        - section: url_lookup
          key: use_gssapi
  use_netrc:
    description:
    - Determining whether to use credentials from ``~/.netrc`` file
    - By default .netrc is used with Basic authentication headers
    - When set to False, .netrc credentials are ignored
    type: boolean
    default: True
    vars:
        - name: ansible_lookup_url_use_netrc
    env:
        - name: ANSIBLE_LOOKUP_URL_USE_NETRC
    ini:
        - section: url_lookup
          key: use_netrc
  unix_socket:
    description: String of file system path to unix socket file to use when establishing connection to the provided url
    type: string
    vars:
        - name: ansible_lookup_url_unix_socket
    env:
        - name: ANSIBLE_LOOKUP_URL_UNIX_SOCKET
    ini:
        - section: url_lookup
          key: unix_socket
  ca_path:
    description: String of file system path to CA cert bundle to use
    type: string
    vars:
        - name: ansible_lookup_url_ca_path
    env:
        - name: ANSIBLE_LOOKUP_URL_CA_PATH
    ini:
        - section: url_lookup
          key: ca_path
  unredirected_headers:
    description: A list of headers to not attach on a redirected request
    type: list
    elements: string
    vars:
        - name: ansible_lookup_url_unredir_headers
    env:
        - name: ANSIBLE_LOOKUP_URL_UNREDIR_HEADERS
    ini:
        - section: url_lookup
          key: unredirected_headers
  ciphers:
    description:
      - SSL/TLS Ciphers to use for the request
      - 'When a list is provided, all ciphers are joined in order with C(:)'
      - See the L(OpenSSL Cipher List Format,https://www.openssl.org/docs/manmaster/man1/openssl-ciphers.html#CIPHER-LIST-FORMAT)
        for more details.
      - The available ciphers is dependent on the Python and OpenSSL/LibreSSL versions
    type: list
    elements: string
    vars:
        - name: ansible_lookup_url_ciphers
    env:
        - name: ANSIBLE_LOOKUP_URL_CIPHERS
    ini:
        - section: url_lookup
          key: ciphers
  cache_dir:
    description: Directory to store cached URL responses
    type: string
    default: /tmp/ansible/url_cache
    vars:
        - name: ansible_lookup_url_cache_dir
    env:
        - name: ANSIBLE_LOOKUP_URL_CACHE_DIR
    ini:
        - section: url_lookup
          key: cache_dir
  cache_ttl:
    description: Time in seconds to consider cached responses valid
    type: int
    default: 600
    vars:
        - name: ansible_lookup_url_cache_ttl
    env:
        - name: ANSIBLE_LOOKUP_URL_CACHE_TTL
    ini:
        - section: url_lookup
          key: cache_ttl
  force_refresh:
    description: Whether to force a refresh of the URL instead of using the cache
    type: boolean
    default: False
    vars:
        - name: ansible_lookup_url_force_refresh
    env:
        - name: ANSIBLE_LOOKUP_URL_FORCE_REFRESH
    ini:
        - section: url_lookup
          key: force_refresh
  retries:
    description:
      - Number of additional attempts after a transient failure (timeout, connection error, HTTP 408/429/5xx).
      - Other HTTP errors and certificate validation errors are never retried.
    type: int
    default: 3
    vars:
        - name: ansible_lookup_url_retries
    env:
        - name: ANSIBLE_LOOKUP_URL_RETRIES
    ini:
        - section: url_lookup
          key: retries
  retry_delay:
    description:
      - Seconds to wait before the first retry.
      - The delay doubles with every further retry and gets a random jitter added.
    type: float
    default: 2
    vars:
        - name: ansible_lookup_url_retry_delay
    env:
        - name: ANSIBLE_LOOKUP_URL_RETRY_DELAY
    ini:
        - section: url_lookup
          key: retry_delay
  stale_if_error:
    description:
      - Return an expired cache entry (with a warning) if the URL still fails with a transient error after all retries.
      - Ignored when O(force_refresh) is set.
    type: boolean
    default: True
    vars:
        - name: ansible_lookup_url_stale_if_error
    env:
        - name: ANSIBLE_LOOKUP_URL_STALE_IF_ERROR
    ini:
        - section: url_lookup
          key: stale_if_error
"""

EXAMPLES = """
- name: url lookup with caching
  ansible.builtin.debug: msg="{{item}}"
  loop: "{{ lookup('ethpandaops.general.url_cached', 'https://github.com/gremlin.keys', wantlist=True) }}"

- name: url lookup with caching and custom TTL
  ansible.builtin.debug:
    msg: "{{ lookup('ethpandaops.general.url_cached', 'https://ip-ranges.amazonaws.com/ip-ranges.json', split_lines=False, cache_ttl=3600) }}"

- name: url lookup with forced refresh
  ansible.builtin.debug:
    msg: "{{ lookup('ethpandaops.general.url_cached', 'https://some.private.site.com/file.txt',
             username='bob', password='hunter2', force_refresh=True) }}"

- name: url lookup with custom cache directory
  ansible.builtin.debug:
    msg: "{{ lookup('ethpandaops.general.url_cached', 'https://some.private.site.com/api/service',
             cache_dir='/tmp/my_url_cache') }}"
"""

RETURN = """
  _list:
    description: list of list of lines or content of url(s)
    type: list
    elements: str
"""

import os
import time
import random
import hashlib
import tempfile
import pathlib
import fcntl  # Add fcntl for file locking

from http.client import HTTPException
from urllib.error import HTTPError, URLError

from ansible.errors import AnsibleError
from ansible.module_utils.common.text.converters import to_text, to_native
from ansible.module_utils.urls import open_url, ConnectionError, SSLValidationError
from ansible.plugins.lookup import LookupBase
from ansible.utils.display import Display

display = Display()

# HTTP status codes that are worth retrying
RETRYABLE_HTTP_CODES = frozenset({408, 425, 429, 500, 502, 503, 504})


class _FetchError(AnsibleError):
    """Fetch failure, flagged with whether it was transient (worth a retry / stale fallback)."""

    def __init__(self, message, transient):
        super().__init__(message)
        self.transient = transient


class LookupModule(LookupBase):

    def _get_cache_file_path(self, url, cache_dir):
        """Generate a cache file path based on the URL."""
        # Create hash of the URL to use as filename
        url_hash = hashlib.sha256(url.encode('utf-8')).hexdigest()
        return os.path.join(cache_dir, url_hash)

    def _get_lock_file_path(self, cache_file):
        """Generate a lock file path based on the cache file."""
        return f"{cache_file}.lock"

    def _read_cache(self, cache_file, ttl):
        """Read content from cache file if valid. A ttl of None ignores the age."""
        if not os.path.exists(cache_file):
            return None

        try:
            # Check if cache is still valid (ttl=None accepts entries of any age)
            if ttl is not None and time.time() - os.path.getmtime(cache_file) > ttl:
                display.vvvv(f"Cache expired for {cache_file}")
                return None

            with open(cache_file, 'rb') as f:
                display.vvvv(f"Using cached content from {cache_file}")
                return f.read()
        except Exception as e:
            display.warning(f"Error reading cache file {cache_file}: {e}")
            return None

    def _write_cache(self, cache_file, content):
        """Write content to cache file."""
        # Ensure cache directory exists
        cache_dir = os.path.dirname(cache_file)

        try:
            pathlib.Path(cache_dir).mkdir(parents=True, exist_ok=True)

            # Write to a temporary file first, then rename to avoid race conditions
            with tempfile.NamedTemporaryFile(dir=cache_dir, delete=False) as tmp_file:
                tmp_file.write(content)
                tmp_path = tmp_file.name

            os.replace(tmp_path, cache_file)
            display.vvvv(f"Cached URL content to {cache_file}")
        except Exception as e:
            display.warning(f"Error writing to cache file {cache_file}: {e}")

    def _acquire_lock(self, lock_file):
        """Acquire a lock file for the cache entry."""
        try:
            # Ensure parent directory exists
            lock_dir = os.path.dirname(lock_file)
            pathlib.Path(lock_dir).mkdir(parents=True, exist_ok=True)

            # Open or create the lock file
            fd = open(lock_file, 'w+')

            # Try to acquire an exclusive lock, non-blocking
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            display.vvvv(f"Acquired lock for {lock_file}")
            return fd
        except IOError:
            # Lock is held by another process
            display.vvvv(f"Waiting for lock on {lock_file}")
            # Open or create the lock file
            fd = open(lock_file, 'w+')
            # Wait for the lock (blocking)
            fcntl.flock(fd, fcntl.LOCK_EX)
            display.vvvv(f"Acquired lock for {lock_file} after waiting")
            return fd
        except Exception as e:
            display.warning(f"Error acquiring lock for {lock_file}: {e}")
            return None

    def _release_lock(self, fd, lock_file):
        """Release a lock file for the cache entry."""
        if fd is not None:
            try:
                fcntl.flock(fd, fcntl.LOCK_UN)
                fd.close()
                display.vvvv(f"Released lock for {lock_file}")
            except Exception as e:
                display.warning(f"Error releasing lock for {lock_file}: {e}")

    def _get_option_with_default(self, option_name, default_value):
        """Get option with fallback to default value if not found."""
        try:
            value = self.get_option(option_name)
            if value is None:
                return default_value
            return value
        except (KeyError, TypeError):
            return default_value

    def _fetch_once(self, term):
        """Fetch the URL once, raising _FetchError on failure."""
        try:
            response = open_url(
                term, validate_certs=self.get_option('validate_certs'),
                use_proxy=self.get_option('use_proxy'),
                url_username=self.get_option('username'),
                url_password=self.get_option('password'),
                headers=self.get_option('headers'),
                force=self.get_option('force'),
                timeout=self.get_option('timeout'),
                follow_redirects='urllib2',
                http_agent=self.get_option('http_agent'),
                force_basic_auth=self.get_option('force_basic_auth'),
                use_gssapi=self.get_option('use_gssapi'),
                unix_socket=self.get_option('unix_socket'),
                ca_path=self.get_option('ca_path'),
                unredirected_headers=self.get_option('unredirected_headers'),
                ciphers=self.get_option('ciphers'),
                use_netrc=self.get_option('use_netrc')
            )
            return response.read()
        except HTTPError as e:
            raise _FetchError(f"Received HTTP error for {term} : {to_native(e)}", e.code in RETRYABLE_HTTP_CODES)
        except SSLValidationError as e:
            raise _FetchError(f"Error validating the server's certificate for {term}: {to_native(e)}", False)
        except URLError as e:
            raise _FetchError(f"Failed lookup url for {term} : {to_native(e)}", True)
        except ConnectionError as e:
            raise _FetchError(f"Error connecting to {term}: {to_native(e)}", True)
        except (OSError, HTTPException) as e:
            # e.g. read timeouts or connections dropped while reading the body
            raise _FetchError(f"Failed lookup url for {term} : {to_native(e)}", True)

    def _fetch(self, term, retries, retry_delay):
        """Fetch the URL, retrying transient failures with exponential backoff."""
        attempt = 0
        while True:
            try:
                return self._fetch_once(term)
            except _FetchError as e:
                if not e.transient or attempt >= retries:
                    raise
                delay = retry_delay * (2 ** attempt)
                delay += random.uniform(0, delay / 2)
                attempt += 1
                display.vvv(f"{to_native(e)} - retry {attempt}/{retries} in {delay:.1f}s")
                time.sleep(delay)

    def run(self, terms, variables=None, **kwargs):
        self.set_options(var_options=variables, direct=kwargs)

        # Get cache settings
        cache_dir = self._get_option_with_default('cache_dir', '/tmp/ansible/url_cache')
        cache_ttl = self._get_option_with_default('cache_ttl', 600)
        force_refresh = self._get_option_with_default('force_refresh', False)
        retries = max(0, int(self._get_option_with_default('retries', 3)))
        retry_delay = max(0.0, float(self._get_option_with_default('retry_delay', 2)))
        stale_if_error = self._get_option_with_default('stale_if_error', True)

        ret = []
        for term in terms:
            display.vvvv(f"url_cached lookup connecting to {term}")

            # Generate cache file path
            cache_file = self._get_cache_file_path(term, cache_dir)
            lock_file = self._get_lock_file_path(cache_file)
            lock_fd = None

            try:
                content = None
                if not force_refresh:
                    # Try to get content from cache without a lock first
                    content = self._read_cache(cache_file, cache_ttl)

                # If cache miss or forced refresh, we need to fetch or wait for another thread to fetch
                if content is None:
                    # Acquire lock before checking again and potentially making HTTP request
                    lock_fd = self._acquire_lock(lock_file)

                    # After acquiring the lock, check cache again
                    # (another thread might have fetched while we were waiting)
                    if not force_refresh:
                        content = self._read_cache(cache_file, cache_ttl)

                    # Still no content, now we can safely fetch
                    if content is None:
                        try:
                            content = self._fetch(term, retries, retry_delay)
                        except _FetchError as e:
                            if not (e.transient and stale_if_error and not force_refresh):
                                raise
                            content = self._read_cache(cache_file, None)
                            if content is None:
                                raise
                            display.warning(f"{to_native(e)} - using expired cache entry instead")
                        else:
                            # Cache the response
                            self._write_cache(cache_file, content)

                # Process the content similar to original url plugin
                if self.get_option('split_lines'):
                    for line in content.splitlines():
                        ret.append(to_text(line))
                else:
                    ret.append(to_text(content))
            finally:
                # Always release lock if we acquired it
                if lock_fd is not None:
                    self._release_lock(lock_fd, lock_file)

        return ret
