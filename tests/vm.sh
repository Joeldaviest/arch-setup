#!/bin/bash

set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
image_url=${ARCH_SETUP_VM_IMAGE_URL:-https://fastly.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2}
cache_dir=${ARCH_SETUP_VM_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/arch-setup-vm}
memory=${ARCH_SETUP_VM_MEMORY:-8192}
cpus=${ARCH_SETUP_VM_CPUS:-4}
disk_size=${ARCH_SETUP_VM_DISK_SIZE:-80G}
keep=false
run_succeeded=false
vm_pid=

usage() {
  cat <<'EOF'
Usage: ./tests/vm.sh [--keep]

Runs the complete setup twice in a disposable, headless Arch Linux VM.

Options:
  --keep  Preserve the VM, SSH key, and logs after a successful test.
  --help  Show this help.

Environment overrides:
  ARCH_SETUP_VM_MEMORY       Guest RAM in MiB (default: 8192)
  ARCH_SETUP_VM_CPUS         Guest virtual CPUs (default: 4)
  ARCH_SETUP_VM_DISK_SIZE    Guest disk size (default: 80G)
  ARCH_SETUP_VM_CACHE_DIR    Image cache and test-run directory
  ARCH_SETUP_VM_IMAGE_URL    Official-compatible Arch QCOW2 image URL
EOF
}

die() {
  printf 'VM test error: %s\n' "$*" >&2
  exit 1
}

note() {
  printf '==> %s\n' "$*"
}

while (($#)); do
  case $1 in
    --keep) keep=true ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; die "Unknown option: $1" ;;
  esac
  shift
done

[[ $(uname -m) == x86_64 ]] || die 'The VM test requires an x86-64 host'
[[ $memory =~ ^[0-9]+$ && $memory -ge 4096 ]] || die 'ARCH_SETUP_VM_MEMORY must be at least 4096 MiB'
[[ $cpus =~ ^[0-9]+$ && $cpus -ge 1 ]] || die 'ARCH_SETUP_VM_CPUS must be a positive integer'

required_commands=(curl qemu-img qemu-system-x86_64 sha256sum ss ssh ssh-keygen tar xorriso)
for command_name in "${required_commands[@]}"; do
  command -v "$command_name" >/dev/null 2>&1 || die "Missing host command: $command_name"
done

[[ -r /dev/kvm && -w /dev/kvm ]] || die '/dev/kvm is unavailable; enable KVM and ensure your user has read/write access'

ovmf_code=${ARCH_SETUP_VM_OVMF_CODE:-}
if [[ -z $ovmf_code ]]; then
  for candidate in \
    /usr/share/edk2/ovmf/OVMF_CODE.fd \
    /usr/share/OVMF/OVMF_CODE.fd \
    /usr/share/edk2/x64/OVMF_CODE.fd; do
    if [[ -r $candidate ]]; then
      ovmf_code=$candidate
      break
    fi
  done
fi
[[ -n $ovmf_code && -r $ovmf_code ]] || die 'OVMF_CODE.fd was not found; install your distribution OVMF/UEFI package'

ovmf_vars=${ARCH_SETUP_VM_OVMF_VARS:-}
if [[ -z $ovmf_vars ]]; then
  for candidate in \
    /usr/share/edk2/ovmf/OVMF_VARS.fd \
    /usr/share/OVMF/OVMF_VARS.fd \
    /usr/share/edk2/x64/OVMF_VARS.fd; do
    if [[ -r $candidate ]]; then
      ovmf_vars=$candidate
      break
    fi
  done
fi
[[ -n $ovmf_vars && -r $ovmf_vars ]] || die 'OVMF_VARS.fd was not found; install your distribution OVMF/UEFI package'

mkdir -p "$cache_dir/runs"
run_dir=$(mktemp -d "$cache_dir/runs/run.XXXXXX")
base_image="$cache_dir/Arch-Linux-x86_64-cloudimg.qcow2"
overlay="$run_dir/guest.qcow2"
seed="$run_dir/cloud-init.iso"
serial_log="$run_dir/serial.log"
install_log="$run_dir/install.log"
second_install_log="$run_dir/install-second.log"
assertion_log="$run_dir/assertions.log"
pid_file="$run_dir/qemu.pid"

cleanup() {
  status=$?
  if [[ -n ${vm_pid:-} ]] && kill -0 "$vm_pid" 2>/dev/null; then
    kill "$vm_pid" 2>/dev/null || true
    wait "$vm_pid" 2>/dev/null || true
  fi

  if [[ $run_succeeded == true && $keep == false ]]; then
    rm -rf -- "$run_dir"
  else
    printf 'VM test artifacts preserved at: %s\n' "$run_dir" >&2
  fi
  exit "$status"
}
trap cleanup EXIT INT TERM

note 'Checking the latest official Arch cloud image'
checksum_tmp="$run_dir/image.SHA256"
curl -fsSL "$image_url.SHA256" -o "$checksum_tmp"
expected_checksum=$(awk 'NR == 1 {print $1}' "$checksum_tmp")
[[ $expected_checksum =~ ^[[:xdigit:]]{64}$ ]] || die 'The image checksum response was invalid'

cached_checksum=
if [[ -f $base_image ]]; then
  cached_checksum=$(sha256sum "$base_image" | awk '{print $1}')
fi

if [[ $cached_checksum != "$expected_checksum" ]]; then
  note 'Downloading the latest Arch cloud image'
  image_tmp="$run_dir/Arch-Linux-x86_64-cloudimg.qcow2.download"
  curl -fL --retry 3 --retry-delay 2 "$image_url" -o "$image_tmp"
  printf '%s  %s\n' "$expected_checksum" "$image_tmp" | sha256sum --check --status || die 'Arch image checksum verification failed'
  mv "$image_tmp" "$base_image"
else
  note 'Using the checksum-verified cached Arch image'
fi

note 'Creating the disposable VM disk and SSH identity'
qemu-img create -q -f qcow2 \
  -o "backing_file=$base_image,backing_fmt=qcow2" "$overlay" "$disk_size"
cp "$ovmf_vars" "$run_dir/OVMF_VARS.fd"
ssh-keygen -q -t ed25519 -N '' -C arch-setup-vm -f "$run_dir/id_ed25519"
public_key=$(<"$run_dir/id_ed25519.pub")

cat >"$run_dir/user-data" <<EOF
#cloud-config
hostname: arch-setup-test
manage_etc_hosts: true
ssh_pwauth: false
disable_root: true
growpart:
  mode: auto
  devices: ['/']
resize_rootfs: true
users:
  - name: archtest
    groups: [wheel]
    shell: /bin/bash
    lock_passwd: true
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - $public_key
write_files:
  - path: /etc/systemd/network/10-cloud-init-wired.network
    permissions: '0644'
    content: |
      [Match]
      Name=en* eth*

      [Network]
      DHCP=yes
runcmd:
  - [systemctl, restart, systemd-networkd.service]
  - [pacman, -Syu, --noconfirm, sudo, git]
  - [systemctl, enable, --now, sshd.service]
EOF

cat >"$run_dir/meta-data" <<EOF
instance-id: arch-setup-$(basename "$run_dir")
local-hostname: arch-setup-test
EOF

cat >"$run_dir/network-config" <<'EOF'
version: 1
config:
  - type: physical
    name: eth0
    subnets:
      - type: dhcp
EOF

xorriso -as mkisofs -quiet -output "$seed" -volid CIDATA -joliet -rock \
  "$run_dir/user-data" "$run_dir/meta-data" "$run_dir/network-config"

ssh_port=
for ((attempt = 0; attempt < 100; attempt++)); do
  candidate=$((22000 + RANDOM % 20000))
  if ! ss -H -ltn "sport = :$candidate" | grep -q .; then
    ssh_port=$candidate
    break
  fi
done
[[ -n $ssh_port ]] || die 'Could not select a local SSH forwarding port'
printf '%s\n' "$ssh_port" >"$run_dir/ssh-port"

note "Starting the headless VM (SSH port $ssh_port)"
qemu-system-x86_64 \
  -name arch-setup-test \
  -machine q35,accel=kvm \
  -cpu host \
  -smp "$cpus" \
  -m "$memory" \
  -drive if=pflash,format=raw,readonly=on,file="$ovmf_code" \
  -drive if=pflash,format=raw,file="$run_dir/OVMF_VARS.fd" \
  -drive if=virtio,format=qcow2,file="$overlay" \
  -drive if=virtio,format=raw,readonly=on,file="$seed" \
  -device virtio-vga \
  -netdev user,id=net0,hostfwd=tcp:127.0.0.1:"$ssh_port"-:22 \
  -device virtio-net-pci,netdev=net0 \
  -display none \
  -monitor none \
  -serial file:"$serial_log" \
  -daemonize \
  -pidfile "$pid_file"
vm_pid=$(<"$pid_file")

ssh_options=(
  -i "$run_dir/id_ed25519"
  -p "$ssh_port"
  -o BatchMode=yes
  -o ConnectTimeout=2
  -o ServerAliveInterval=30
  -o ServerAliveCountMax=10
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o LogLevel=ERROR
)

guest() {
  # Arguments are intentionally assembled locally and passed as the remote command.
  # shellcheck disable=SC2029
  ssh "${ssh_options[@]}" archtest@127.0.0.1 "$@"
}

wait_for_ssh() {
  local label=$1
  local deadline=$((SECONDS + 600))
  local next_update=$((SECONDS + 30))
  while ((SECONDS < deadline)); do
    if guest true >/dev/null 2>&1; then
      note "$label"
      return 0
    fi
    kill -0 "$vm_pid" 2>/dev/null || die "The VM exited while waiting for SSH; inspect $serial_log"
    if ((SECONDS >= next_update)); then
      note "Still waiting for SSH ($((600 - (deadline - SECONDS)))s elapsed); serial log: $serial_log"
      next_update=$((SECONDS + 30))
    fi
    sleep 2
  done
  die "Timed out waiting for SSH; inspect $serial_log"
}

reboot_guest() {
  local return_label=$1
  local went_down=false

  guest 'sudo systemctl reboot' >/dev/null 2>&1 || true
  for ((attempt = 1; attempt <= 60; attempt++)); do
    if ! guest true >/dev/null 2>&1; then
      went_down=true
      break
    fi
    sleep 1
  done
  [[ $went_down == true ]] || die 'The guest did not disconnect for reboot'
  wait_for_ssh "$return_label"
}

wait_for_ssh 'SSH is available'
note 'Waiting for cloud-init to finish'
guest 'sudo cloud-init status --wait --long'

# cloud-init performs a full system upgrade so the running cloud-image kernel
# can differ from the newly installed kernel. Reboot before setup needs kernel
# modules such as nftables/conntrack for UFW.
note 'Rebooting into the kernel installed by the cloud-image update'
reboot_guest 'SSH returned after the cloud-image update reboot'

# The test harness communicates exclusively over SSH. Seed a VM-only rule
# before setup enables UFW's default-deny policy; real installations do not
# expose SSH unless the user explicitly chooses to do so.
note 'Preserving SSH access for the VM test firewall'
guest "sudo pacman -S --needed --noconfirm ufw && sudo ufw allow 22/tcp comment 'VM test SSH'"

note 'Copying the repository into the guest'
tar --exclude=.git --exclude='.cache' -C "$root" -cf - . | \
  ssh "${ssh_options[@]}" archtest@127.0.0.1 'mkdir -p ~/arch-setup && tar -C ~/arch-setup -xf -'

note 'Running repository and package-source checks in the guest'
guest 'cd ~/arch-setup && ./setup.sh --check'

note 'Running the complete setup; this can take a long time'
guest 'cd ~/arch-setup && TERM=xterm-256color ./setup.sh' 2>&1 | tee "$install_log"

# cloud-init may have installed an earlier networkd file for first boot. Remove
# only that generated file so the reboot specifically exercises this repo's
# 20-wired.network configuration.
guest "sudo find /etc/systemd/network -maxdepth 1 -type f -name '10-cloud-init*.network' -delete"

note 'Rebooting into the configured system'
reboot_guest 'SSH returned after reboot'

note 'Running post-reboot assertions'
guest 'cd ~/arch-setup && ./tests/vm-guest.sh' 2>&1 | tee "$assertion_log"

note 'Running setup a second time to test idempotency'
guest 'cd ~/arch-setup && TERM=xterm-256color ./setup.sh' 2>&1 | tee "$second_install_log"
guest 'cd ~/arch-setup && ./tests/vm-guest.sh' 2>&1 | tee -a "$assertion_log"

note 'Shutting down the guest'
guest 'sudo systemctl poweroff' >/dev/null 2>&1 || true
for ((attempt = 1; attempt <= 60; attempt++)); do
  kill -0 "$vm_pid" 2>/dev/null || break
  sleep 1
done
kill -0 "$vm_pid" 2>/dev/null && die 'The VM did not power off cleanly'
vm_pid=

run_succeeded=true
note 'Headless Arch VM test passed'
if [[ $keep == true ]]; then
  note "Preserved VM and logs at $run_dir"
fi
