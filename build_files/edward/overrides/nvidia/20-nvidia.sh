#!/usr/bin/env bash
set -xeuo pipefail

# Get qualified kernel version
KERNEL_SUFFIX=""
QUALIFIED_KERNEL="$(rpm -qa | grep -P 'kernel-(|'"${KERNEL_SUFFIX}"'-)(\d+\.\d+\.\d+)' | sed -E 's/kernel-(|'"${KERNEL_SUFFIX}"'-)//' | tail -n 1)"

ARCH="$(uname -m)"
if [ "$ARCH" = "aarch64" ]; then
    NVIDIA_ARCH="sbsa"
else
    NVIDIA_ARCH="$ARCH"
fi

FEDORA_VERSION="${FEDORA_AKMODS_VERSION:-43}"
AKMODS_FEDORA_VERSION="$(
    find /tmp/akmods-nvidia-open-rpms -name '*.rpm' -print \
        | grep -oPm1 '(?<=\.fc)\d+' \
        | head -n1 || true
)"
if [[ -n "${AKMODS_FEDORA_VERSION}" ]]; then
    FEDORA_VERSION="${AKMODS_FEDORA_VERSION}"
fi

NVIDIA_REPO_URL="https://negativo17.org/repos/nvidia/fedora-${FEDORA_VERSION}/${ARCH}/"
NVIDIA_DNF_ARGS=(
    "--repofrompath=fedora-nvidia-lts-install,${NVIDIA_REPO_URL}"
    '--setopt=fedora-nvidia-lts-install.gpgcheck=1'
    '--setopt=fedora-nvidia-lts-install.gpgkey=https://negativo17.org/repos/RPM-GPG-KEY-slaanesh'
    '--setopt=retries=10'
    '--setopt=timeout=60'
    '--enablerepo=fedora-nvidia-lts-install'
)
NVIDIA_DNF_DRIVER_ARGS=(
    "--repofrompath=fedora-nvidia-lts-driver,${NVIDIA_REPO_URL}"
    '--setopt=fedora-nvidia-lts-driver.gpgcheck=1'
    '--setopt=fedora-nvidia-lts-driver.gpgkey=https://negativo17.org/repos/RPM-GPG-KEY-slaanesh'
    '--setopt=retries=10'
    '--setopt=timeout=60'
    '--enablerepo=fedora-nvidia-lts-driver'
)

# Install kmod RPMs that match the running kernel
NVIDIA_KMOD_RPMS=()
while IFS= read -r rpm_file; do
    rpm_name="$(rpm -qp --qf '%{NAME}' "${rpm_file}")"
    if [[ "${rpm_name}" == kmod-* ]] && ! rpm -qp --requires "${rpm_file}" \
        | grep -Fqx "kernel-uname-r = ${QUALIFIED_KERNEL}"; then
        continue
    fi
    NVIDIA_KMOD_RPMS+=("${rpm_file}")
done < <(find /tmp/akmods-nvidia-open-rpms/kmods -type f -name '*.rpm' -print)

mapfile -t NVIDIA_UBLUE_RPMS < <(
    find /tmp/akmods-nvidia-open-rpms/ublue-os -maxdepth 1 -type f -name '*.rpm' -print
)

if ((${#NVIDIA_KMOD_RPMS[@]} == 0)); then
    echo "ERROR: no NVIDIA kmod RPMs match kernel ${QUALIFIED_KERNEL}" >&2
    exit 1
fi

dnf -y "${NVIDIA_DNF_ARGS[@]}" install \
    "${NVIDIA_KMOD_RPMS[@]}" "${NVIDIA_UBLUE_RPMS[@]}"

sed -i 's/^enabled=0/enabled=1/' /etc/yum.repos.d/*nvidia-container-toolkit*.repo 2>/dev/null || true

KMOD_VERSION="$(rpm -q --queryformat '%{VERSION}' kmod-nvidia)"
NVIDIA_PKG_VERSION="3:${KMOD_VERSION}"

dnf install -y "${NVIDIA_DNF_DRIVER_ARGS[@]}" \
    "libnvidia-fbc-${NVIDIA_PKG_VERSION}" \
    "nvidia-driver-${NVIDIA_PKG_VERSION}" \
    "nvidia-driver-cuda-${NVIDIA_PKG_VERSION}" \
    "nvidia-settings-${NVIDIA_PKG_VERSION}" \
    nvidia-container-toolkit

DRIVER_VERSION="$(rpm -q --queryformat '%{VERSION}' nvidia-driver)"
if [ "$KMOD_VERSION" != "$DRIVER_VERSION" ]; then
    echo "Error: kmod-nvidia version ($KMOD_VERSION) does not match nvidia-driver version ($DRIVER_VERSION)"
    exit 1
fi

tee /usr/lib/modprobe.d/00-nouveau-blacklist.conf <<'EOF'
blacklist nouveau
options nouveau modeset=0
EOF

bootc kargs append -- \
    rd.driver.blacklist=nouveau \
    modprobe.blacklist=nouveau \
    nvidia-drm.modeset=1

sed -i 's/^enabled=1/enabled=0/' /etc/yum.repos.d/*nvidia-container-toolkit*.repo 2>/dev/null || true

systemctl enable ublue-nvctk-cdi.service

if [[ -f /etc/modprobe.d/nvidia-modeset.conf ]]; then
    cp /etc/modprobe.d/nvidia-modeset.conf /usr/lib/modprobe.d/nvidia-modeset.conf
fi

DRACUT_NVIDIA_CONFIG=/usr/lib/dracut/dracut.conf.d/99-nvidia.conf
DRACUT_NVIDIA_TMP="${DRACUT_NVIDIA_CONFIG}.tmp"
awk '{ gsub(/omit_drivers/, "force_drivers"); gsub(/ nvidia /, " i915 amdgpu nvidia "); print }' \
    "${DRACUT_NVIDIA_CONFIG}" > "${DRACUT_NVIDIA_TMP}"
mv "${DRACUT_NVIDIA_TMP}" "${DRACUT_NVIDIA_CONFIG}"

/usr/bin/dracut --no-hostonly --kver "$QUALIFIED_KERNEL" --reproducible --tmpdir /boot --zstd -v --add ostree -f "/lib/modules/$QUALIFIED_KERNEL/initramfs.img"

nvidia-ctk config --set nvidia-container-cli.no-cgroups --in-place

if [ -x /usr/libexec/ublue-nvidia-flatpak-runtime-sync ]; then
    /usr/libexec/ublue-nvidia-flatpak-runtime-sync || true
fi
