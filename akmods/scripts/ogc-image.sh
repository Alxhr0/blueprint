#!/usr/bin/bash
set -euo pipefail

# Print the pinned OGC kernel OCI artifact as image:tag, read from
# akmods/images.yaml (single source of truth, same file resolve-kernel.sh and
# the Justfile build recipe read). Mirrors resolve-kernel.sh's yaml reading.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
python3 - "${SCRIPT_DIR}/../images.yaml" <<'PY'
import sys, yaml

c = yaml.safe_load(open(sys.argv[1]))
print(c["ogc"]["image"] + ":" + c["ogc"]["tag"])
PY
