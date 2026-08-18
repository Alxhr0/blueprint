#!/usr/bin/env bash
set -xeuo pipefail

dnf clean all

rm -f /var/log/dnf*.log /var/log/hawkey.log

bootc container lint
