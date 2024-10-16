export SHELL := /usr/bin/env TZ=UTC bash

all: artifacts

artifacts:
	./install_packer_and_build.sh

build-and-publish:
	PUBLISH_IMG=1 ./install_packer_and_build.sh

# these targets are declared "phony" so that make won't skip them if a
# file named after the target exists
.PHONY: all artifacts build-and-publish
