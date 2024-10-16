#!/bin/bash

set -euo pipefail

echo "==> Removing curl..."
apt-get -y autoremove --purge curl

echo "==> Cleaning cloud init logs..."
/usr/bin/cloud-init clean --logs
rm -rf /var/lib/cloud/
