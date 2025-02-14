.PHONY: lint lint-roles lint-playbooks sanity setup

setup:
	./setup.sh

lint: lint-roles lint-playbooks sanity

lint-roles:
	ansible-lint roles

lint-playbooks:
	ansible-lint playbooks

sanity:
	ansible-test sanity
