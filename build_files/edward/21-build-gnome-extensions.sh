#!/usr/bin/bash

set -eoux pipefail

echo "::group:: $(basename "$0")"

# GNOME Shell extensions are no longer installed by this image.
# The upstream bluefin-lts-nvidia base already enables the extensions
# we want via its gschema override, so we skip re-downloading and
# re-installing them here.

echo "::endgroup::"
