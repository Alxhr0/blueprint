#!/usr/bin/env bash
set -euo pipefail

DEFAULT_IMAGE="ghcr.io/huntedraven7/blueprint:server"
DEFAULT_USERNAME="core"
INSTALL_LOG="/tmp/install-server.log"

exec > >(tee -a "$INSTALL_LOG") 2>&1

probe_disks() {
    mapfile -t DISKS < <(
        lsblk -dno NAME,TYPE,SIZE,MODEL \
        | awk '$2 == "disk" && !/loop|sr|ram/ { print "/dev/" $1, $3, $4 }'
    )
    if [[ ${#DISKS[@]} -eq 0 ]]; then
        whiptail --title "Error" --msgbox "No disks found." 8 40
        exit 1
    fi
}

probe_interfaces() {
    mapfile -t IFACES < <(
        ip -o link show \
        | awk -F': ' '$2 != "lo" { print $2 }'
    )
}

get_ip() {
    local iface="$1"
    ip -4 addr show dev "$iface" 2>/dev/null \
        | awk '/inet / { split($2, a, "/"); print a[1]; exit }'
}

step_welcome() {
    whiptail --title "Blueprint Server Installer" --msgbox \
        "Welcome to the Blueprint Server Installer.\n\n\
This will install a custom bootc-based server image to disk.\n\
All data on the target disk will be erased.\n\n\
Press OK to continue." 12 60
}

step_disk() {
    local choices=()
    for entry in "${DISKS[@]}"; do
        read -r dev size model <<< "$entry"
        choices+=("$dev" "${size} ${model}")
    done

    TARGET_DISK=$(whiptail --title "Target Disk" --menu \
        "Select the disk to install to. ALL DATA WILL BE ERASED." \
        16 60 8 "${choices[@]}" 3>&1 1>&2 2>&3) || exit 0

    whiptail --title "Confirm" --yesno \
        "WARNING: All data on ${TARGET_DISK} will be destroyed.\n\nProceed?" 8 50 || exit 0
}

step_hostname() {
    HOSTNAME=$(whiptail --title "Hostname" --inputbox \
        "Enter the hostname for this server:" 8 50 "blueprint-server" 3>&1 1>&2 2>&3) || exit 0
    [[ -z "$HOSTNAME" ]] && HOSTNAME="blueprint-server"
}

step_user() {
    USERNAME=$(whiptail --title "User" --inputbox \
        "Enter the username for the primary user:" 8 50 "$DEFAULT_USERNAME" 3>&1 1>&2 2>&3) || exit 0
    [[ -z "$USERNAME" ]] && USERNAME="$DEFAULT_USERNAME"
}

step_ssh() {
    SSH_KEY=""
    if whiptail --title "SSH Key" --yesno \
        "Do you want to add an SSH public key for ${USERNAME}?" 8 50; then
        SSH_KEY=$(whiptail --title "SSH Public Key" --inputbox \
            "Paste your SSH public key:" 10 80 3>&1 1>&2 2>&3) || exit 0
    fi
}

step_network() {
    local net_choices=()
    for iface in "${IFACES[@]}"; do
        local ip
        ip=$(get_ip "$iface")
        if [[ -n "$ip" ]]; then
            net_choices+=("$iface" "$ip")
        else
            net_choices+=("$iface" "(no address)")
        fi
    done

    NET_MODE=$(whiptail --title "Network" --menu \
        "Select network configuration mode:" \
        12 50 2 \
        "dhcp" "Automatic (DHCP)" \
        "static" "Static IP" 3>&1 1>&2 2>&3) || exit 0

    if [[ "$NET_MODE" == "static" ]]; then
        NET_IFACE=$(whiptail --title "Network Interface" --menu \
            "Select the network interface:" \
            12 50 4 "${net_choices[@]}" 3>&1 1>&2 2>&3) || exit 0
        NET_ADDR=$(whiptail --title "Static IP" --inputbox \
            "IP address (CIDR, e.g. 192.168.1.100/24):" 8 60 3>&1 1>&2 2>&3) || exit 0
        NET_GW=$(whiptail --title "Gateway" --inputbox \
            "Default gateway:" 8 50 3>&1 1>&2 2>&3) || exit 0
        NET_DNS=$(whiptail --title "DNS" --inputbox \
            "DNS server:" 8 50 "1.1.1.1" 3>&1 1>&2 2>&3) || exit 0
    fi
}

step_image() {
    IMAGE_REF=$(whiptail --title "Container Image" --inputbox \
        "Bootc container image to install:" 8 80 "$DEFAULT_IMAGE" 3>&1 1>&2 2>&3) || exit 0
    [[ -z "$IMAGE_REF" ]] && IMAGE_REF="$DEFAULT_IMAGE"
}

step_review() {
    local net_detail="DHCP"
    if [[ "$NET_MODE" == "static" ]]; then
        net_detail="${NET_ADDR} gw=${NET_GW}"
    fi

    local ssh_detail="none"
    [[ -n "$SSH_KEY" ]] && ssh_detail="(key provided)"

    whiptail --title "Review" --msgbox \
        "Installation summary:\n\n\
  Target disk:  ${TARGET_DISK}\n\
  Hostname:     ${HOSTNAME}\n\
  Username:     ${USERNAME}\n\
  SSH key:      ${ssh_detail}\n\
  Network:      ${NET_MODE} ${net_detail}\n\
  Image:        ${IMAGE_REF}\n\n\
Press OK to begin installation." 18 70
}

generate_ignition() {
    local ign_file="/tmp/blueprint-install.ign"

    local user_block
    if [[ -n "$SSH_KEY" ]]; then
        user_block=$(python3 -c "
import json, sys
user = {'name': sys.argv[1], 'groups': ['wheel']}
if sys.argv[2]:
    user['sshAuthorizedKeys'] = [sys.argv[2]]
print(json.dumps(user))
" "$USERNAME" "$SSH_KEY")
    else
        user_block=$(python3 -c "
import json, sys
user = {'name': sys.argv[1], 'groups': ['wheel']}
print(json.dumps(user))
" "$USERNAME")
    fi

    local networkd_files="[]"
    if [[ "$NET_MODE" == "static" ]]; then
        networkd_files=$(python3 -c "
import json, sys
unit = {
    'path': '/etc/systemd/network/10-static.network',
    'mode': 0o644,
    'contents': {
        'source': 'data:,%5BNetwork%5D%0AName=' + sys.argv[1] + '%0AAddress=' + sys.argv[2] + '%0AGateway=' + sys.argv[3] + '%0ADNS=' + sys.argv[4],
        'verification': {}
    }
}
print(json.dumps([unit]))
" "$NET_IFACE" "$NET_ADDR" "$NET_GW" "$NET_DNS")
    fi

    python3 - "$ign_file" "$HOSTNAME" "$user_block" "$networkd_files" <<'PYEOF'
import json, sys

ign_file     = sys.argv[1]
hostname     = sys.argv[2]
user_block   = json.loads(sys.argv[3])
networkd     = json.loads(sys.argv[4])

storage_files = [
    {
        "path": "/etc/hostname",
        "mode": 0o644,
        "contents": {"source": "data:,hostname", "verification": {}}
    }
]
storage_files[0]["contents"]["source"] = "data:," + hostname

passwd = {"users": [user_block]}

config = {
    "ignition": {"version": "3.3.0"},
    "passwd": passwd,
    "storage": {"files": storage_files}
}

if networkd:
    config["storage"]["files"].extend(networkd)

with open(ign_file, "w") as f:
    json.dump(config, f, indent=2)

print(f"  Ignition config: {ign_file}")
PYEOF

    echo "$ign_file"
}

run_install() {
    local ign_file
    ign_file=$(generate_ignition)

    whiptail --title "Installing" --msgbox \
        "Installing ${IMAGE_REF}\n\
to ${TARGET_DISK}.\n\n\
This may take several minutes. Watch the log:\n\
${INSTALL_LOG}" 14 70

    echo "=== Pulling container image: ${IMAGE_REF} ==="
    podman pull "$IMAGE_REF"

    echo "=== Running bootc install ==="
    local bootc_args=(
        run --privileged --pid=host --network=host
        --volume /var/lib/containers:/var/lib/containers
        --volume /dev:/dev
        --volume "${ign_file}:/config.ign:ro"
    )

    podman "${bootc_args[@]}" \
        "$IMAGE_REF" \
        bootc install \
            --target-device "$TARGET_DISK" \
            --transport registry \
            --image-ref "$IMAGE_REF"

    return $?
}

main() {
    if [[ "$(id -u)" -ne 0 ]]; then
        echo "This installer must be run as root." >&2
        exit 1
    fi

    step_welcome
    probe_disks
    probe_interfaces
    step_disk
    step_hostname
    step_user
    step_ssh
    step_network
    step_image
    step_review

    echo "=== Starting installation ==="
    if run_install; then
        whiptail --title "Complete" --msgbox \
            "Installation complete!\n\n\
Remove the installation media and press Enter to reboot." 10 50
        reboot
    else
        whiptail --title "Error" --msgbox \
            "Installation failed. Check the log:\n${INSTALL_LOG}" 10 60
        exit 1
    fi
}

main "$@"
