#!/bin/bash

declare HARDWARE_SUMMARY="generic"

installed_kernel_headers() {
  local kernel
  local found=false
  for kernel in linux linux-lts linux-zen linux-hardened; do
    if command_exists pacman && pacman -Q "$kernel" >/dev/null 2>&1; then
      printf '%s-headers\n' "$kernel"
      found=true
    fi
  done
  [[ $found == true ]] || printf '%s\n' linux-headers
}

add_installed_kernel_headers() {
  local headers
  while IFS= read -r headers; do
    [[ -n $headers ]] && HARDWARE_PACKAGES+=("$headers")
  done < <(installed_kernel_headers)
}

classify_hardware() {
  local pci=${ARCH_SETUP_TEST_PCI:-}
  local cpu_vendor=${ARCH_SETUP_TEST_CPU_VENDOR:-}
  local gpu_driver_selected=false
  if [[ -z $pci ]] && command_exists lspci; then
    pci=$(lspci -nn)
  fi
  if [[ -z $cpu_vendor && -r /proc/cpuinfo ]]; then
    cpu_vendor=$(sed -n 's/^vendor_id[[:space:]]*: //p' /proc/cpuinfo | head -1)
  fi

  case $cpu_vendor in
    AuthenticAMD)
      HARDWARE_PACKAGES+=(amd-ucode)
      HARDWARE_SUMMARY+=" AMD-CPU"
      ;;
    GenuineIntel)
      HARDWARE_PACKAGES+=(intel-ucode)
      HARDWARE_SUMMARY+=" Intel-CPU"
      ;;
  esac

  # xpadneo-dkms is part of the personal base package set, so the running
  # kernels' headers are required even when no other DKMS hardware is found.
  add_installed_kernel_headers

  if grep -qiE '(VGA|Display).*AMD|AMD.*(VGA|Display)' <<<"$pci"; then
    HARDWARE_PACKAGES+=(mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon)
    HARDWARE_SUMMARY+=" AMD-GPU"
    gpu_driver_selected=true
  fi

  if grep -qiE '(VGA|Display).*Intel|Intel.*(VGA|Display)' <<<"$pci"; then
    HARDWARE_PACKAGES+=(vulkan-intel lib32-vulkan-intel intel-media-driver)
    HARDWARE_SUMMARY+=" Intel-GPU"
    gpu_driver_selected=true
  fi

  if grep -qi nvidia <<<"$pci"; then
    if grep -i nvidia <<<"$pci" | grep -qE 'GTX (9[0-9]{2}|10[0-9]{2})|GT 10[0-9]{2}|Quadro [PM][0-9]{3,4}|Quadro GV100|MX *[0-9]+|Titan (X|Xp|V)|Tesla V100'; then
      add_installed_kernel_headers
      HARDWARE_AUR_PACKAGES+=(nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils)
      HARDWARE_SUMMARY+=" legacy-NVIDIA-GPU"
    else
      add_installed_kernel_headers
      HARDWARE_PACKAGES+=(nvidia-open-dkms nvidia-utils lib32-nvidia-utils libva-nvidia-driver)
      HARDWARE_SUMMARY+=" NVIDIA-GPU"
    fi
    gpu_driver_selected=true
  fi

  # Steam requires explicit 64-bit and 32-bit Vulkan providers. Without a
  # recognized physical GPU (for example in the headless VM), pacman otherwise
  # selects the first provider noninteractively, which is currently NVIDIA.
  if [[ $gpu_driver_selected == false ]]; then
    HARDWARE_PACKAGES+=(vulkan-swrast lib32-vulkan-swrast)
    HARDWARE_SUMMARY+=" software-Vulkan"
  fi

  if grep -qi 'Broadcom.*Network' <<<"$pci"; then
    HARDWARE_PACKAGES+=(broadcom-wl-dkms)
    add_installed_kernel_headers
    HARDWARE_SUMMARY+=" Broadcom-WiFi"
  fi

  if grep -qi '1f0a:6801\|YT6801' <<<"$pci"; then
    add_installed_kernel_headers
    HARDWARE_AUR_PACKAGES+=(yt6801-dkms)
    HARDWARE_SUMMARY+=" YT6801-Ethernet"
  fi

  if [[ ${ARCH_SETUP_TEST_DMI_VENDOR:-$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null)} == "Framework" ]]; then
    HARDWARE_AUR_PACKAGES+=(qmk-hid)
    HARDWARE_SUMMARY+=" Framework"
  fi

  if [[ -d /sys/class/power_supply/BAT0 || -d /sys/class/power_supply/BAT1 ]]; then
    HARDWARE_SUMMARY+=" laptop"
  fi

  mapfile -t HARDWARE_PACKAGES < <(printf '%s\n' "${HARDWARE_PACKAGES[@]}" | sed '/^$/d' | sort -u)
  mapfile -t HARDWARE_AUR_PACKAGES < <(printf '%s\n' "${HARDWARE_AUR_PACKAGES[@]}" | sed '/^$/d' | sort -u)
  export HARDWARE_SUMMARY
}

print_hardware_summary() {
  note "Detected hardware:$HARDWARE_SUMMARY"
  if ((${#HARDWARE_PACKAGES[@]})); then
    printf '  %s\n' "${HARDWARE_PACKAGES[@]}"
  fi
  if ((${#HARDWARE_AUR_PACKAGES[@]})); then
    printf '  AUR: %s\n' "${HARDWARE_AUR_PACKAGES[@]}"
  fi
}
