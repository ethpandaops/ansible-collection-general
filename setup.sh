#!/usr/bin/env bash

# Install required tools using asdf

ASDF_PYAPP_INCLUDE_DEPS=1 asdf plugin add ansible https://github.com/amrox/asdf-pyapp.git
asdf plugin add ansible-lint https://github.com/amrox/asdf-pyapp.git
asdf plugin add shellcheck https://github.com/luizm/asdf-shellcheck.git

asdf install

# Install ansible collection depdendencies
ansible-galaxy collection install -r requirements.yaml --force
