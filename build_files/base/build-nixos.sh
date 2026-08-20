#!/bin/bash
set -ouex pipefail

# The NixOS build is fully performed in the builder stage (builder-nixos.sh
# runs /ctx/nixos/build.sh and populates /output). This system-stage script is
# intentionally a no-op; the unified root Containerfile still runs it.
true
