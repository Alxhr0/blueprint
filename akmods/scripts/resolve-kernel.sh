#!/usr/bin/bash
set -euo pipefail

# Resolve the exact linux-ogc kernel version from a pinned OGC Arch kernel OCI
# artifact, for CI tags/labels. Prints the version string, e.g.
#   7.2.1.ogc2-1-x86_64
#
# Usage: resolve-kernel.sh <ogc-image>   # ghcr.io/.../kernel-packages-arch:latest

OGC_IMAGE="${1:-}"

# No arg: read the pinned OGC artifact from akmods/images.yaml (single source
# of truth, same file the Justfile builds from). With an arg: use it directly.
if [ -z "${OGC_IMAGE}" ]; then
	SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
	OGC_IMAGE="$(
		python3 - "${SCRIPT_DIR}/../images.yaml" <<'PY'
import sys, yaml
c = yaml.safe_load(open(sys.argv[1]))
print(c["ogc"]["image"] + ":" + c["ogc"]["tag"])
PY
	)"
fi

command -v skopeo >/dev/null || {
	echo "error: skopeo not found" >&2
	exit 1
}
command -v jq >/dev/null || {
	echo "error: jq not found" >&2
	exit 1
}

skopeo inspect --raw "docker://${OGC_IMAGE}" | jq -r '
    [ .layers[].annotations["org.opencontainers.image.title"]
      | select(startswith("linux-ogc-")) ]
    | map(select(contains("headers") | not))
    | first
    | ltrimstr("linux-ogc-")
    | rtrimstr(".pkg.tar.zst")
'
