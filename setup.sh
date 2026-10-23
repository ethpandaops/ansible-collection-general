#!/usr/bin/env bash

set -xe

# Uninstall previous asdf plugins that shouldn't be managed anymore under asdf
asdf uninstall ansible || true
asdf uninstall ansible-lint || true

# Install required tools using asdf

asdf plugin add shellcheck https://github.com/luizm/asdf-shellcheck.git || true
asdf plugin-add python || true

asdf install
asdf reshim

# Install python tools
# Bootstrap pip from a hash-pinned wheel: older pips trust the compromised eMudhra CAs.
pip install "pip @ https://files.pythonhosted.org/packages/3f/06/3e4420302363fbb71be3c7f35ce042f54bfca330e3e66b3a2e3c4cca579f/pip-26.2.2-py3-none-any.whl#sha256=fd7f4dfa8190e014013b9f08f3e973f4e4c26ffd179a204895533a7254813a70"
pip install -r requirements.txt

# Install ansible collection depdendencies
ansible-galaxy install -r requirements.yaml --force
