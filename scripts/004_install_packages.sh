#!/bin/bash

set -euo pipefail

export HEADFUL_SAFE_FETCH=y
export DEBIAN_FRONTEND=noninteractive

echo "==>: apt-get installs"
apt-get install -yq jq
apt_pkgs="$(jq -r '.apt | join(" ")' /tmp/external-deps-and-pkgs.json)"
apt-get install -yq $apt_pkgs

# If you had generic bins in artifactory:
#echo "==> Artifactory installs (sysdig, logdna, etc)"
#jq -r '.genericbin[]' /tmp/external-deps-and-pkgs.json | while read -r pkg; do
#    /tmp/safe-artifactory-bin-fetcher "${pkg}"
#done
