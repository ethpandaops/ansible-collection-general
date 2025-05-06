# Ansible Role: Kurtosis

This role installs [Kurtosis](https://kurtosis.com/) on the target machine.

## Requirements

- For MacOS targets: Homebrew should be installed.
- For Linux targets: Root access (`become: true`) is required.

## Role Variables

Available variables are listed below, along with default values:

```yaml
# Whether to install Docker if not already present
kurtosis_install_docker: true

# Whether to install command-line completion
kurtosis_install_completion: true
```

## Dependencies

None.

## Example Playbook

```yaml
- hosts: servers
  roles:
    - role: kurtosis
      vars:
        kurtosis_install_docker: true
        kurtosis_install_completion: true
```

## License

MIT

## Author Information

This role was created based on the [Kurtosis installation guide](https://docs.kurtosis.com/install).