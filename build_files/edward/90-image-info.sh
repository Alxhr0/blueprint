#!/usr/bin/env bash
set -xeuo pipefail

IMAGE_REF="ostree-image-signed:docker://ghcr.io/${IMAGE_VENDOR}/${IMAGE_NAME}"
IMAGE_INFO="/usr/share/ublue-os/image-info.json"
IMAGE_FLAVOR="main"
IMAGE_TAG="stable/testing"

tee "$IMAGE_INFO" <<EOF
{
  "image-name": "${IMAGE_NAME}",
  "image-ref": "${IMAGE_REF}",
  "image-flavor": "${IMAGE_FLAVOR}",
  "image-vendor": "${IMAGE_VENDOR}",
  "image-tag": "${IMAGE_TAG}",
  "centos-version": "${MAJOR_VERSION_NUMBER}"
}
EOF
chmod 0644 "${IMAGE_INFO}"

IMAGE_PRETTY_NAME="Edward LTS"
HOME_URL="https://github.com/huntedraven7/blueprint"
DOCUMENTATION_URL="https://github.com/huntedraven7/blueprint"
SUPPORT_URL="https://github.com/huntedraven7/blueprint/issues/"
BUG_SUPPORT_URL="https://github.com/huntedraven7/blueprint/issues/"
CODE_NAME="Kitten"

# OS Release File (structure mirrors bluefin-lts; values are Edward's).
# The base image is bluefin-lts, so its CPE is already cpe:/o:universal-blue:bluefin-lts.
sed -i -f - /usr/lib/os-release <<EOF
s/^NAME=.*/NAME=\"${IMAGE_PRETTY_NAME}\"/
s|^VERSION_CODENAME=.*|VERSION_CODENAME=\"${CODE_NAME}\"/
s/^VARIANT_ID=.*/VARIANT_ID=${IMAGE_NAME}/
s/^PRETTY_NAME=.*/PRETTY_NAME=\"${IMAGE_PRETTY_NAME}\"/
s|^HOME_URL=.*|HOME_URL=\"${HOME_URL}\"/
s|^BUG_REPORT_URL=.*|BUG_REPORT_URL=\"${BUG_SUPPORT_URL}\"/
s|CPE_NAME=\"cpe:/o:universal-blue:bluefin-lts|CPE_NAME=\"cpe:/o:universal-blue:edward|
/^REDHAT_BUGZILLA_PRODUCT=/d
/^REDHAT_BUGZILLA_PRODUCT_VERSION=/d
/^REDHAT_SUPPORT_PRODUCT=/d
/^REDHAT_SUPPORT_PRODUCT_VERSION=/d
EOF

tee -a /usr/lib/os-release <<EOF
DOCUMENTATION_URL="${DOCUMENTATION_URL}"
SUPPORT_URL="${SUPPORT_URL}"
DEFAULT_HOSTNAME="edward"
BUILD_ID="${SHA_HEAD_SHORT:-deadbeef}"
EOF
