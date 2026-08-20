#!/bin/bash
set -ouex pipefail

# holo images derive from arch-bootc:stable and do all their work in the system
# stage via build-amd.sh / build-nvidia.sh. This builder-stage script is a
# no-op placeholder so the unified root Containerfile can drive holo uniformly.
true
