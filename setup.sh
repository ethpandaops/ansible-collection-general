#!/usr/bin/env bash

# Install required tools using asdf

asdf plugin add shellcheck https://github.com/luizm/asdf-shellcheck.git
asdf plugin-add python

asdf install

# Install python tools
pip install -r requirements.txt

# Install ansible collection depdendencies
ansible-galaxy install -r requirements.yaml --force
