#!/usr/bin/env bash
set -euo pipefail

STREAM="stable"
ARCH="amd64"
IMAGE_REF=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --stream=*)  STREAM="${1#--stream=}"; shift ;;
        --stream)    STREAM="$2"; shift 2 ;;
        --arch=*)    ARCH="${1#--arch=}"; shift ;;
        --arch)      ARCH="$2"; shift 2 ;;
        --image=*)   IMAGE_REF="${1#--image=}"; shift ;;
        --image)     IMAGE_REF="$2"; shift 2 ;;
        stable|testing|next) STREAM="$1"; shift ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

case "$STREAM" in
    stable|testing|next) ;;
    *) echo "error: --stream must be stable, testing, or next (got '$STREAM')" >&2; exit 1 ;;
esac
case "$ARCH" in
    amd64|arm64) ;;
    *) echo "error: --arch must be amd64 or arm64 (got '$ARCH')" >&2; exit 1 ;;
esac

case "$ARCH" in
    amd64) COREOS_ARCH="x86_64" ;;
    arm64) COREOS_ARCH="aarch64" ;;
esac

for cmd in coreos-installer python3; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Missing: $cmd" >&2
        exit 1
    fi
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.fcos-iso-build"
OUTPUT_DIR="$ROOT_DIR/output"

if [[ -z "$IMAGE_REF" ]]; then
    IMAGE_REF="${INSTALL_IMAGE:-ghcr.io/huntedraven7/blueprint:server}"
fi

echo "=== Building Blueprint CoreOS installer ISO ==="
echo "  stream : $STREAM"
echo "  arch   : $ARCH"
echo "  image  : $IMAGE_REF"

mkdir -p "$BUILD_DIR"
echo "[1/3] Downloading FCOS live ISO (stream: $STREAM, arch: $COREOS_ARCH)..."

ISO_CACHE_DIR="$BUILD_DIR/iso-cache-${STREAM}-${ARCH}"
mkdir -p "$ISO_CACHE_DIR"

LIVE_ISO=""
EXISTING_ISO="$(ls "$ISO_CACHE_DIR"/*.iso 2>/dev/null | head -1 || true)"
if [[ -n "$EXISTING_ISO" ]]; then
    echo "  Using cached FCOS ISO: $(basename "$EXISTING_ISO")"
    LIVE_ISO="$EXISTING_ISO"
else
    echo "  Fetching from builds.coreos.fedoraproject.org..."
    coreos-installer download \
        --stream "$STREAM" \
        --platform metal \
        --format iso \
        --architecture "$COREOS_ARCH" \
        --directory "$ISO_CACHE_DIR"
    LIVE_ISO="$(ls "$ISO_CACHE_DIR"/*.iso | head -1)"
    echo "  Downloaded: $(basename "$LIVE_ISO") ($(du -h "$LIVE_ISO" | cut -f1))"
fi

echo "[2/3] Generating live Ignition config..."

IGN_FILE="$BUILD_DIR/live-ignition.ign"

INSTALLER_SCRIPT="$SCRIPT_DIR/install-server.sh"
if [[ ! -f "$INSTALLER_SCRIPT" ]]; then
    echo "error: installer script not found: $INSTALLER_SCRIPT" >&2
    exit 1
fi

SCRIPT_B64="$(base64 -w0 "$INSTALLER_SCRIPT")"
SCRIPT_SIZE="$(stat -c%s "$INSTALLER_SCRIPT")"

python3 - "$IGN_FILE" "$SCRIPT_B64" "$SCRIPT_SIZE" "$IMAGE_REF" <<'PYEOF'
import json, sys, os

ign_file    = sys.argv[1]
script_b64  = sys.argv[2]
script_size = int(sys.argv[3])
image_ref   = sys.argv[4]

service_unit = """\
[Unit]
Description=Blueprint Server Installer
After=multi-user.target network-online.target
Wants=network-online.target
Conflicts=getty@tty1.service
Before=getty@tty1.service
ConditionPathExists=/opt/install-server

[Service]
Type=idle
ExecStart=/opt/install-server
StandardInput=tty
StandardOutput=tty
StandardError=tty
Environment=TERM=xterm
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
Restart=no

[Install]
WantedBy=multi-user.target"""

config = {
    "ignition": {"version": "3.3.0"},
    "storage": {
        "files": [
            {
                "path": "/opt/install-server",
                "mode": 0o755,
                "contents": {
                    "source": f"data:;base64,{script_b64}",
                    "verification": {}
                }
            }
        ]
    },
    "systemd": {
        "units": [
            {"name": "sshd.service", "enabled": True},
            {
                "name": "install-server.service",
                "enabled": True,
                "contents": service_unit
            }
        ]
    }
}

with open(ign_file, "w") as f:
    json.dump(config, f, indent=2)

print(f"  Ignition: {ign_file}")
print(f"  installer size: {script_size} bytes embedded")
print(f"  image ref: {image_ref}")
PYEOF

echo "[3/3] Customizing FCOS live ISO with coreos-installer..."

mkdir -p "$OUTPUT_DIR"
ISO_OUT="$OUTPUT_DIR/blueprint-coreos-installer-${STREAM}-${ARCH}.iso"
rm -f "$ISO_OUT"

coreos-installer iso customize \
    --force \
    --live-ignition "$IGN_FILE" \
    --output "$ISO_OUT" \
    "$LIVE_ISO"

echo ""
echo "ISO built: $ISO_OUT ($(du -h "$ISO_OUT" | cut -f1))"
echo ""
echo "Test with QEMU (UEFI, amd64):"
echo "  OVMF=/usr/share/OVMF/OVMF_CODE.fd"
echo "  qemu-system-x86_64 -m 4096 -enable-kvm \\"
echo "    -drive if=pflash,format=raw,readonly=on,file=\$OVMF \\"
echo "    -cdrom $ISO_OUT \\"
echo "    -drive if=virtio,file=target.qcow2,format=qcow2 \\"
echo "    -nographic"
echo ""
echo "Test with QEMU (UEFI, arm64):"
echo "  OVMF=/usr/share/AAVMF/AAVMF_CODE.fd"
echo "  qemu-system-aarch64 -m 4096 -cpu cortex-a57 -M virt \\"
echo "    -drive if=pflash,format=raw,readonly=on,file=\$OVMF \\"
echo "    -cdrom $ISO_OUT \\"
echo "    -drive if=virtio,file=target.qcow2,format=qcow2 \\"
echo "    -nographic"
echo ""
echo "Write to USB:"
echo "  sudo dd if=$ISO_OUT of=/dev/sdX bs=4M status=progress"
