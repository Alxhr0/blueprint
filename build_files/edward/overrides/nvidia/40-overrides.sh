#!/usr/bin/env bash
set -xeuo pipefail

sed -i "/experimental-features/ s/\]/, 'kms-modifiers'&/" /usr/share/glib-2.0/schemas/zz0-bluefin-modifications.gschema.override 2>/dev/null || true
glib-compile-schemas /usr/share/glib-2.0/schemas
