#!/usr/bin/env bash
set -xeuo pipefail

VERSIONS="/run/context/image-versions.yaml"

REVIEW_REF="$(awk '/review-launcher:/{f=1; next} f && /ref:/{print $2; exit}' "${VERSIONS}" | tr -d '"')"
GOOSE_CHANNEL="$(awk '/^  goose:/{f=1; next} f && /channel:/{print $2; exit}' "${VERSIONS}" | tr -d '"')"
GOOSE_X86_64_SHA256="$(awk '/^  goose:/{f=1; next} f && /x86_64_sha256:/{print $2; exit}' "${VERSIONS}" | tr -d '"')"
GOOSE_AARCH64_SHA256="$(awk '/^  goose:/{f=1; next} f && /aarch64_sha256:/{print $2; exit}' "${VERSIONS}" | tr -d '"')"
REVIEW_IMAGE="$(awk '/- name: review/{f=1; next} f && /image:/{print $2; exit}' "${VERSIONS}")"
REVIEW_TAG="$(awk '/- name: review/{f=1; next} f && /tag:/{print $2; exit}' "${VERSIONS}")"

install -d -m 0755 /usr/share/ublue-os/just
curl --fail --silent --show-error --location \
	--retry 5 --retry-all-errors --retry-delay 5 \
	-o /usr/share/ublue-os/just/review.just \
	"https://raw.githubusercontent.com/projectbluefin/review/${REVIEW_REF}/justfile"

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT
case "$(uname -m)" in
	x86_64)
		goose_arch=x86_64
		goose_sha="${GOOSE_X86_64_SHA256}"
		;;
	aarch64)
		goose_arch=aarch64
		goose_sha="${GOOSE_AARCH64_SHA256}"
		;;
	*)
		echo "review setup: unsupported architecture $(uname -m), skipping host Goose install" >&2
		goose_arch=""
		;;
esac

if [[ -n "${goose_arch}" ]]; then
	curl --fail --silent --show-error --location \
		--retry 5 --retry-all-errors --retry-delay 5 \
		-o "${workdir}/goose.tar.gz" \
		"https://github.com/aaif-goose/goose/releases/download/${GOOSE_CHANNEL}/goose-${goose_arch}-unknown-linux-musl.tar.gz"
	printf '%s  %s\n' "${goose_sha}" "${workdir}/goose.tar.gz" | sha256sum -c -
	python3 -m gzip -d < "${workdir}/goose.tar.gz" > "${workdir}/goose.tar"
	tar -xOf "${workdir}/goose.tar" --occurrence=1 ./goose > /usr/local/bin/goose
	chmod 0755 /usr/local/bin/goose
	/usr/local/bin/goose --version
fi

podman pull "${REVIEW_IMAGE}:${REVIEW_TAG}"
