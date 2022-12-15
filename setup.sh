#!/bin/bash

# Plugin list
ASDF_PYAPP_INCLUDE_DEPS=1 asdf plugin add ansible https://github.com/amrox/asdf-pyapp.git
asdf plugin add ansible-lint https://github.com/amrox/asdf-pyapp.git

asdf install
