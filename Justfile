set dotenv-filename := "images/edward.env"
set dotenv-load

# Primary image config + shared defaults (also sources the shared vars for other variants)
primary_env := "images/edward.env"

export image_name := env_var("IMAGE_NAME")
export repo_organization := env_var("REPO_ORGANIZATION")
export image_desc := env_var("IMAGE_DESC")
export image_keywords := env_var("IMAGE_KEYWORDS")
export image_logo_url := env_var("IMAGE_LOGO_URL")
export default_tag := env_var("DEFAULT_TAG")
export bib_image := env_var("BIB_IMAGE")

alias build-vm := build-qcow2
alias rebuild-vm := rebuild-qcow2
alias run-vm := run-vm-qcow2

[private]
default:
    @just --list

# Check Just Syntax
[group('Just')]
check:
    #!/usr/bin/env bash
    find . -type f -name "*.just" | while read -r file; do
    	echo "Checking syntax: $file"
    	just --unstable --fmt --check -f $file
    done
    echo "Checking syntax: Justfile"
    just --unstable --fmt --check -f Justfile

# Fix Just Syntax
[group('Just')]
fix:
    #!/usr/bin/env bash
    find . -type f -name "*.just" | while read -r file; do
    	echo "Checking syntax: $file"
    	just --unstable --fmt -f $file
    done
    echo "Checking syntax: Justfile"
    just --unstable --fmt -f Justfile || { exit 1; }

# Clean Repo
[group('Utility')]
clean:
    #!/usr/bin/env bash
    set -eoux pipefail
    touch _build
    find *_build* -exec rm -rf {} \;
    rm -f previous.manifest.json
    rm -f changelog.md
    rm -f output.env
    rm -rf output/

# Sudo Clean Repo
[group('Utility')]
[private]
sudo-clean:
    just sudoif just clean

# sudoif bash function
[group('Utility')]
[private]
sudoif command *args:
    #!/usr/bin/env bash
    function sudoif(){
        if [[ "${UID}" -eq 0 ]]; then
            "$@"
        elif [[ "$(command -v sudo)" && -n "${SSH_ASKPASS:-}" ]] && [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
            sudo --askpass "$@" || exit 1
        elif [[ "$(command -v sudo)" ]]; then
            sudo "$@" || exit 1
        else
            exit 1
        fi
    }
    sudoif {{ command }} {{ args }}

# This Justfile recipe builds a container image using Podman.
#
# Arguments:
#   $target_image - The tag you want to apply to the image (default: $image_name).
#   $tag - The tag for the image (default: $default_tag).
#
# The script constructs the version string using the tag and the current date.
# If the git working directory is clean, it also includes the short SHA of the current HEAD.
#
# just build $target_image $tag
#
# Example usage:
#   just build myimage mytag
#
# This will build an image 'myimage:mytag'
#

[private]
_ensure-yq:
    #!/usr/bin/env bash
    if ! command -v yq &> /dev/null && ! /home/linuxbrew/.linuxbrew/bin/yq --version &> /dev/null; then
        echo "Missing requirement: 'yq' is not installed."
        echo "Please install yq (e.g. 'brew install yq')"
        exit 1
    fi

# Build the image using the specified parameters
build $target_image="" $tag="" $dx="0" $nvidia="1" $kernel_pin="" $gnome_version="50" $almalinux_version="10": _ensure-yq
    #!/usr/bin/env bash

    set -euo pipefail
    export PATH="/home/linuxbrew/.linuxbrew/bin:${PATH}"

    PRIMARY_STEM="$(basename "{{ primary_env }}" .env)"
    if [[ -z "${target_image}" ]]; then
        target_image="${PRIMARY_STEM}"
    fi

    set -a
    source "{{ primary_env }}"
    if [[ -f "images/${target_image}.env" && "images/${target_image}.env" != "{{ primary_env }}" ]]; then
        source "images/${target_image}.env"
    fi
    set +a

    CONTAINERFILE="containerfiles/Containerfile.${PRIMARY_STEM}"
    if [[ -f "containerfiles/Containerfile.${target_image}" ]]; then
        CONTAINERFILE="containerfiles/Containerfile.${target_image}"
    fi

    TAG="${DEFAULT_TAG}"
    if [[ -n "${tag}" ]]; then
        TAG="${tag}"
    fi

    ver="${tag}.$(date +%Y%m%d)"

    brew_image_sha=$(yq -r '.images[] | select(.name == "brew") | .digest' image-versions.yaml)
    brew_image_ref="ghcr.io/ublue-os/brew:latest@${brew_image_sha}"

    BUILD_ARGS=()
    BUILD_ARGS+=("--build-arg" "BREW_IMAGE_REF=${brew_image_ref}")
    BUILD_ARGS+=("--build-arg" "MAJOR_VERSION={{ almalinux_version }}")
    BUILD_ARGS+=("--build-arg" "IMAGE_NAME=${IMAGE_NAME}")
    BUILD_ARGS+=("--build-arg" "IMAGE_VENDOR=${REPO_ORGANIZATION}")
    BUILD_ARGS+=("--build-arg" "ENABLE_DX={{ dx }}")
    BUILD_ARGS+=("--build-arg" "ENABLE_NVIDIA={{ nvidia }}")
    BUILD_ARGS+=("--build-arg" "GNOME_VERSION={{ gnome_version }}")

    # Build custom akmods image for NVIDIA if enabled
    if [ "{{ nvidia }}" = "1" ] && grep -q "AKMODS_IMAGE_REF" "${CONTAINERFILE}" 2>/dev/null; then
        echo "Building custom NVIDIA akmods image..."
        KERNEL_VERSION=$(podman run --rm --pull=newer "quay.io/almalinuxorg/almalinux-bootc:10-kitten" rpm -qa --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' kernel 2>/dev/null | tail -1 || echo "")
        if [ -n "$KERNEL_VERSION" ]; then
            podman build \
                --build-arg "KERNEL_VERSION=${KERNEL_VERSION}" \
                --tag "blueprint:akmods-edward" \
                --tag "ghcr.io/huntedraven7/blueprint:akmods-edward" \
                --file "containerfiles/Containerfile.akmods-edward" \
                .
            BUILD_ARGS+=("--build-arg" "AKMODS_IMAGE_REF=blueprint:akmods-edward")
        else
            echo "WARNING: Could not detect kernel version, skipping custom akmods build"
            BUILD_ARGS+=("--build-arg" "AKMODS_IMAGE_REF=ghcr.io/huntedraven7/blueprint:akmods-edward")
        fi
    elif grep -q "AKMODS_IMAGE_REF" "${CONTAINERFILE}" 2>/dev/null; then
        BUILD_ARGS+=("--build-arg" "AKMODS_IMAGE_REF=ghcr.io/huntedraven7/blueprint:akmods-edward")
    fi
    if [[ -z "$(git status -s)" ]]; then
        BUILD_ARGS+=("--build-arg" "SHA_HEAD_SHORT=$(git rev-parse --short HEAD)")
    fi

    LABELS=()
    if [[ -z "$(git status -s)" ]]; then
        GIT_SHA=$(git rev-parse --short HEAD)
        LABELS+=("--label" "io.artifacthub.package.readme-url=https://raw.githubusercontent.com/${REPO_ORGANIZATION}/${IMAGE_NAME}/${GIT_SHA}/README.md")
        LABELS+=("--label" "org.opencontainers.image.documentation=https://raw.githubusercontent.com/${REPO_ORGANIZATION}/${IMAGE_NAME}/${GIT_SHA}/README.md")
        LABELS+=("--label" "org.opencontainers.image.source=https://github.com/${REPO_ORGANIZATION}/${IMAGE_NAME}/blob/${GIT_SHA}/containerfiles/Containerfile")
        LABELS+=("--label" "org.opencontainers.image.url=https://github.com/${REPO_ORGANIZATION}/${IMAGE_NAME}/tree/${GIT_SHA}")
        LABELS+=("--label" "org.opencontainers.image.version=${DEFAULT_TAG}.$(date +%Y%m%d)-${GIT_SHA}")
    fi
    LABELS+=("--label" "io.artifacthub.package.deprecated=false")
    LABELS+=("--label" "io.artifacthub.package.keywords=${IMAGE_KEYWORDS}")
    LABELS+=("--label" "io.artifacthub.package.license=Apache-2.0")
    LABELS+=("--label" "io.artifacthub.package.logo-url=${IMAGE_LOGO_URL}")
    LABELS+=("--label" "io.artifacthub.package.prerelease=false")
    LABELS+=("--label" "org.opencontainers.image.created=$(date -u +%Y\-%m\-%d\T%H\:%M\:%S\Z)")
    LABELS+=("--label" "org.opencontainers.image.description=${IMAGE_DESC}")
    LABELS+=("--label" "org.opencontainers.image.title=${IMAGE_NAME}")
    LABELS+=("--label" "org.opencontainers.image.vendor=${REPO_ORGANIZATION}")

    PODMAN_BUILD_ARGS=("${BUILD_ARGS[@]}" "${LABELS[@]}" "--pull=newer" "--tag" "${IMAGE_NAME}:${TAG}" "--file" "${CONTAINERFILE}")

    podman build "${PODMAN_BUILD_ARGS[@]}" .

# Build custom NVIDIA akmods image for AlmaLinux + CoreOS kernel
[group('Build')]
build-akmods:
    #!/usr/bin/env bash
    set -euo pipefail

    set -a
    source "images/akmods-edward.env"
    set +a

    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    CONTEXT_DIR="$(dirname "$SCRIPT_DIR")"

    echo "Building akmods image using AlmaLinux bootc base (kernel auto-detected inside container)..."

    podman build \
        --tag "${IMAGE_NAME}:${DEFAULT_TAG}" \
        --tag "ghcr.io/${REPO_ORGANIZATION}/${IMAGE_NAME}:${DEFAULT_TAG}" \
        --file "containerfiles/Containerfile.akmods-edward" \
        "${CONTEXT_DIR}"

    echo "Akmods image built: ${IMAGE_NAME}:${DEFAULT_TAG}"

# Build the fsdk image using BuildStream (pure FSDK composition, no apt)
[group('Build')]
build-fsdk $tag="fsdk":
    #!/usr/bin/env bash
    set -euo pipefail
    cd buildstream && just build

# Build all images in the repo
[group('Build')]
build-all:
    #!/usr/bin/env bash
    set -euo pipefail
    just build edward
    just build aira
    just build server
    just build ai
    just build debian
    just build gentoo
    just build opensuse
    just build ubuntu
    just build nixos
    just build holo-amd
    just build holo-nvidia
    just build-fsdk

# Split the image for smaller updates (New)!
rechunk $target_image=image_name $tag=default_tag:
    #!/usr/bin/env bash

    set -xeuo pipefail

    # TODO: pin chunkah image to hash once mature enough
    # You may run into space issues on github runners as we are making a
    # complete copy of the image, which likely has no shared layers, unless your
    # base image is also using chunkah
    CHUNKAH_CONFIG_FILE="$(mktemp)"

    # You may omit the current directory here if you are confident that you
    # won't run out of space on /tmp for your image
    CHUNKAH_OUTPUT_DIR="$(mktemp -d ./"${target_image}"_chunkah_XXXXXX)"

    trap 'rm -f "${CHUNKAH_CONFIG_FILE}"; rm -rf "${CHUNKAH_OUTPUT_DIR}"' EXIT
    podman inspect "${target_image}:${tag}" > "${CHUNKAH_CONFIG_FILE}"

    podman run --rm \
      --mount=type=image,src="${target_image}:${tag}",target=/chunkah \
      -v "${CHUNKAH_CONFIG_FILE}:/chunkah-config.json:ro,Z" \
      -v "${CHUNKAH_OUTPUT_DIR}:/run/out:Z" \
      quay.io/coreos/chunkah:latest \
      build \
      --verbose \
      --compressed \
      --max-layers 128 \
      --prune /sysroot/ \
      --label ostree.commit- --label ostree.final-diffid- \
      --config /chunkah-config.json \
      --output oci:/run/out/chunked

    CHUNKED_IMAGE="$(podman pull "oci:${CHUNKAH_OUTPUT_DIR}/chunked")"
    podman tag "${CHUNKED_IMAGE}" "${target_image}:${tag}"

# Split the image for smaller updates (Classical)!
ostree-rechunk $target_image=image_name $tag=default_tag:
    #!/usr/bin/env bash

    set -xeuo pipefail

    # TODO: This is the only blocker for rootless CI
    # https://github.com/coreos/rpm-ostree/issues/5346
    if [[ ! "${UID}" -eq "0" ]]; then
      echo "This needs to run as root."
      exit 1
    fi

    # Use the already-built local image to avoid pulling from a remote registry
    RPM_OSTREE_CHUNKER_IMAGE="localhost/${target_image}:${tag}"

    podman run --rm \
      --pull=never \
      --privileged \
      -v "/var/lib/containers:/var/lib/containers" \
      --entrypoint /usr/bin/rpm-ostree \
      "${RPM_OSTREE_CHUNKER_IMAGE}" \
      compose build-chunked-oci \
      --max-layers 127 \
      --format-version=2 \
      --bootc \
      --from "localhost/${target_image}:${tag}" \
      --output containers-storage:"localhost/${target_image}:${tag}"

# Generate Default Tag
[group('Utility')]
generate-default-tag $tag=default_tag:
    #!/usr/bin/env bash
    set -eoux pipefail

    echo "${tag}"

# Generate Tags
[group('Utility')]
generate-build-tags $target_image=image_name $tag=default_tag:
    #!/usr/bin/env bash
    set -eoux pipefail

    # All alias tags are prefixed with the variant tag so variants sharing an
    # image name (e.g. blueprint:latest, blueprint:aira) never overwrite each other
    DATE=$(date +%Y%m%d)
    BUILD_TAGS=()
    if [[ -z "$(git status -s)" ]]; then
        GIT_SHA=$(git rev-parse --short HEAD)
        BUILD_TAGS+=("${tag}-${GIT_SHA}")
        BUILD_TAGS+=("${tag}-${DATE}-${GIT_SHA}")
    fi

    BUILD_TAGS+=("${tag}-${DATE}")
    BUILD_TAGS+=("${tag}")

    echo "${BUILD_TAGS[@]}"

# Tag Images
[group('Utility')]
tag-images $target_image=image_name $tag=default_tag tags="":
    #!/usr/bin/env bash
    set -eoux pipefail

    # Get Image, and untag
    IMAGE=$(podman inspect ${target_image}:${tag} | jq -r .[].Id)
    podman untag ${IMAGE}

    # Tag Image
    for tag in {{ tags }}; do
        podman tag $IMAGE "${target_image}:${tag}"
    done

    # Show Images
    podman images

# Image Name
[group('Utility')]
[private]
image_name $target_image=image_name:
    #!/usr/bin/env bash
    set -eoux pipefail

    echo "${image_name}"

# List all variant keys defined in this repo (env files with a matching containerfiles/Containerfile.<name>)
[group('Utility')]
list-images:
    #!/usr/bin/env bash
    set -eoux pipefail

    IMAGES=()
    for env in images/*.env; do
        [[ -f "${env}" ]] || continue
        stem="${env#images/}"
        stem="${stem%.env}"
        if [[ -f "containerfiles/Containerfile.${stem}" ]] || [[ -f "buildstream/Containerfile.${stem}" ]]; then
            case "${stem}" in
                arch|holo-amd|holo-nvidia|ai|debian|gentoo|opensuse|ubuntu|nixos|fsdk|akmods-edward) continue ;;
            esac
            IMAGES+=("${stem}")
        fi
    done

    printf '%s\n' "${IMAGES[@]}"

# Print IMAGE_NAME and DEFAULT_TAG for a variant key
[group('Utility')]
[private]
variant-env $target_image=image_name:
    #!/usr/bin/env bash
    set -eoux pipefail

    set -a
    source "{{ primary_env }}"
    if [[ -f "images/${target_image}.env" ]]; then
        source "images/${target_image}.env"
    fi
    set +a

    echo "IMAGE_NAME=${IMAGE_NAME}"
    echo "DEFAULT_TAG=${DEFAULT_TAG}"

# Command: _rootful_load_image
# Description: This script checks if the current user is root or running under sudo. If not, it attempts to resolve the image tag using podman inspect.
#              If the image is found, it loads it into rootful podman. If the image is not found, it pulls it from the repository.
#
# Parameters:
#   $target_image - The name of the target image to be loaded or pulled.
#   $tag - The tag of the target image to be loaded or pulled. Default is 'default_tag'.
#
# Example usage:
#   _rootful_load_image my_image latest
#
# Steps:
# 1. Check if the script is already running as root or under sudo.
# 2. Check if target image is in the non-root podman container storage)
# 3. If the image is found, load it into rootful podman using podman scp.
# 4. If the image is not found, pull it from the remote repository into reootful podman.

_rootful_load_image $target_image=image_name $tag=default_tag:
    #!/usr/bin/env bash
    set -eoux pipefail

    # Check if already running as root or under sudo
    if [[ -n "${SUDO_USER:-}" || "${UID}" -eq "0" ]]; then
        echo "Already root or running under sudo, no need to load image from user podman."
        exit 0
    fi

    # Try to resolve the image tag using podman inspect
    set +e
    resolved_tag=$(podman inspect -t image "${target_image}:${tag}" | jq -r '.[].RepoTags.[0]')
    return_code=$?
    set -e

    USER_IMG_ID=$(podman images --filter reference="${target_image}:${tag}" --format "'{{ '{{.ID}}' }}'")

    if [[ $return_code -eq 0 ]]; then
        # If the image is found, load it into rootful podman
        ID=$(just sudoif podman images --filter reference="${target_image}:${tag}" --format "'{{ '{{.ID}}' }}'")
        if [[ "$ID" != "$USER_IMG_ID" ]]; then
            # If the image ID is not found or different from user, copy the image from user podman to root podman
            COPYTMP=$(mktemp -p "${PWD}" -d -t _build_podman_scp.XXXXXXXXXX)
            just sudoif TMPDIR=${COPYTMP} podman image scp ${UID}@localhost::"${target_image}:${tag}" root@localhost::"${target_image}:${tag}"
            rm -rf "${COPYTMP}"
        fi
    else
        # If the image is not found, pull it from the repository
        just sudoif podman pull "${target_image}:${tag}"
    fi

# Build a bootc bootable image using Bootc Image Builder (BIB)
# Converts a container image to a bootable image
# Parameters:
#   target_image: The name of the image to build (ex. localhost/fedora)
#   tag: The tag of the image to build (ex. latest)
#   type: The type of image to build (ex. qcow2, raw, iso)
#   config: The configuration file to use for the build (default: disk_config/disk.toml)

# Example: just _rebuild-bib localhost/fedora latest qcow2 disk_config/disk.toml
_build-bib $target_image $tag $type $config: (_rootful_load_image target_image tag)
    #!/usr/bin/env bash
    set -euo pipefail

    args="--type ${type} "
    args+="--use-librepo=True "
    args+="--rootfs=btrfs"

    BUILDTMP=$(mktemp -p "${PWD}" -d -t _build-bib.XXXXXXXXXX)

    sudo podman run \
      --rm \
      -it \
      --privileged \
      --pull=newer \
      --net=host \
      --security-opt label=type:unconfined_t \
      -v $(pwd)/${config}:/config.toml:ro \
      -v $BUILDTMP:/output \
      -v /var/lib/containers/storage:/var/lib/containers/storage \
      "${bib_image}" \
      ${args} \
      "${target_image}:${tag}"

    mkdir -p output
    sudo mv -f $BUILDTMP/* output/
    sudo rmdir $BUILDTMP
    sudo chown -R $USER:$USER output/

# Podman builds the image from the Containerfile and creates a bootable image
# Parameters:
#   target_image: The name of the image to build (ex. localhost/fedora)
#   tag: The tag of the image to build (ex. latest)
#   type: The type of image to build (ex. qcow2, raw, iso)
#   config: The configuration file to use for the build (deafult: disk_config/disk.toml)

# Example: just _rebuild-bib localhost/fedora latest qcow2 disk_config/disk.toml
_rebuild-bib $target_image $tag $type $config: (build target_image tag) && (_build-bib target_image tag type config)

# Build a QCOW2 virtual machine image
[group('Build Virtal Machine Image')]
build-qcow2 $target_image=("localhost/" + image_name) $tag=default_tag: && (_build-bib target_image tag "qcow2" "disk_config/disk.toml")

# Build a RAW virtual machine image
[group('Build Virtal Machine Image')]
build-raw $target_image=("localhost/" + image_name) $tag=default_tag: && (_build-bib target_image tag "raw" "disk_config/disk.toml")

# Build an ISO virtual machine image
[group('Build Virtal Machine Image')]
build-iso $target_image=("localhost/" + image_name) $tag=default_tag: && (_build-bib target_image tag "iso" "disk_config/iso.toml")

# Build a GNOME installer ISO using bootc-installer
[group('Build Virtal Machine Image')]
build-gnome-iso: && (_rebuild-bib "ghcr.io/huntedraven7/blueprint" "edward" "iso" "disk_config/iso-gnome.toml")

# Build a server installer ISO using BIB (Anaconda-based)
[group('Build Virtal Machine Image')]
build-server-iso: && (_build-bib "ghcr.io/huntedraven7/blueprint" "server" "iso" "disk_config/iso-server.toml")

# Rebuild a QCOW2 virtual machine image
[group('Build Virtal Machine Image')]
rebuild-qcow2 $target_image=("localhost/" + image_name) $tag=default_tag: && (_rebuild-bib target_image tag "qcow2" "disk_config/disk.toml")

# Rebuild a RAW virtual machine image
[group('Build Virtal Machine Image')]
rebuild-raw $target_image=("localhost/" + image_name) $tag=default_tag: && (_rebuild-bib target_image tag "raw" "disk_config/disk.toml")

# Rebuild an ISO virtual machine image
[group('Build Virtal Machine Image')]
rebuild-iso $target_image=("localhost/" + image_name) $tag=default_tag: && (_rebuild-bib target_image tag "iso" "disk_config/iso.toml")

# Run a virtual machine with the specified image type and configuration
_run-vm $target_image $tag $type $config:
    #!/usr/bin/env bash
    set -eoux pipefail

    # Determine the image file based on the type
    image_file="output/${type}/disk.${type}"
    if [[ $type == iso ]]; then
        image_file="output/bootiso/install.iso"
    fi

    # Build the image if it does not exist
    if [[ ! -f "${image_file}" ]]; then
        just "build-${type}" "$target_image" "$tag"
    fi

    # Determine an available port to use
    port=8006
    while grep -q :${port} <<< $(ss -tunalp); do
        port=$(( port + 1 ))
    done
    echo "Using Port: ${port}"
    echo "Connect to http://localhost:${port}"

    # Set up the arguments for running the VM
    run_args=()
    run_args+=(--rm --privileged)
    run_args+=(--pull=newer)
    run_args+=(--publish "127.0.0.1:${port}:8006")
    run_args+=(--env "CPU_CORES=4")
    run_args+=(--env "RAM_SIZE=8G")
    run_args+=(--env "DISK_SIZE=64G")
    run_args+=(--env "TPM=Y")
    run_args+=(--env "GPU=Y")
    run_args+=(--device=/dev/kvm)
    run_args+=(--volume "${PWD}/${image_file}":"/boot.${type}")
    run_args+=(docker.io/qemux/qemu)

    # Run the VM and open the browser to connect
    (sleep 30 && xdg-open http://localhost:"$port") &
    podman run "${run_args[@]}"

# Run a virtual machine from a QCOW2 image
[group('Run Virtal Machine')]
run-vm-qcow2 $target_image=("localhost/" + image_name) $tag=default_tag: && (_run-vm target_image tag "qcow2" "disk_config/disk.toml")

# Run a virtual machine from a RAW image
[group('Run Virtal Machine')]
run-vm-raw $target_image=("localhost/" + image_name) $tag=default_tag: && (_run-vm target_image tag "raw" "disk_config/disk.toml")

# Run a virtual machine from an ISO
[group('Run Virtal Machine')]
run-vm-iso $target_image=("localhost/" + image_name) $tag=default_tag: && (_run-vm target_image tag "iso" "disk_config/iso.toml")

# Run the server installer ISO in a VM
[group('Run Virtal Machine')]
run-server-iso: && (_run-vm "localhost/blueprint" "server" "iso" "disk_config/iso-server.toml")

# Run a virtual machine using systemd-vmspawn
[group('Run Virtal Machine')]
spawn-vm rebuild="0" type="qcow2" ram="6G":
    #!/usr/bin/env bash

    set -euo pipefail

    [ "{{ rebuild }}" -eq 1 ] && echo "Rebuilding the ISO" && just build-vm {{ rebuild }} {{ type }}

    systemd-vmspawn \
      -M "bootc-image" \
      --console=gui \
      --cpus=2 \
      --ram=$(echo {{ ram }}| numfmt --from=iec) \
      --network-user-mode \
      --vsock=false --pass-ssh-key=false \
      -i ./output/**/*.{{ type }}

# Runs shell check on all Bash scripts
lint:
    #!/usr/bin/env bash
    set -eoux pipefail
    # Check if shellcheck is installed
    if ! command -v shellcheck &> /dev/null; then
        echo "shellcheck could not be found. Please install it."
        exit 1
    fi
    # Run shellcheck on all Bash scripts
    find . -iname "*.sh" -type f -exec shellcheck "{}" ';'

# Runs shfmt on all Bash scripts
format:
    #!/usr/bin/env bash
    set -eoux pipefail
    # Check if shfmt is installed
    if ! command -v shfmt &> /dev/null; then
        echo "shfmt could not be found. Please install it."
        exit 1
    fi
    # Run shfmt on all Bash scripts
    find . -iname "*.sh" -type f -exec shfmt --write "{}" ';'
