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
pip install -r requirements.txt

# Install ansible collection depdendencies
ansible-galaxy install -r requirements.yaml --force
