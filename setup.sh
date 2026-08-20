#!/bin/bash

set -Eeuo pipefail

SETUP_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
export SETUP_ROOT

source "$SETUP_ROOT/scripts/lib/common.sh"
source "$SETUP_ROOT/scripts/lib/packages.sh"
source "$SETUP_ROOT/scripts/lib/hardware.sh"

mode=apply
case ${1:-} in
  --check) mode=check ;;
  --dry-run) mode=dry-run ;;
  "") ;;
  *) die "Usage: ./setup.sh [--check|--dry-run]" ;;
esac
export SETUP_MODE=$mode

check_host
classify_hardware

if [[ $mode == "check" ]]; then
  check_repository
  check_package_manifests
  print_hardware_summary
  success "Repository and host checks passed"
  exit 0
fi

if [[ $mode == "dry-run" ]]; then
  print_dry_run
  exit 0
fi

sudo -v
install_packages
"$SETUP_ROOT/scripts/configure-dotfiles.sh"
"$SETUP_ROOT/scripts/configure-system.sh"
"$SETUP_ROOT/scripts/configure-user.sh"

success "Setup complete"
note "Log out and back in (or reboot) before starting the Hyprland session."
note "Launch Floorp, sign into Firefox Sync, quit Floorp, then run ./scripts/configure-floorp.sh"

