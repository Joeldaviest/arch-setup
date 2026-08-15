#!/bin/bash

declare -a HARDWARE_PACKAGES=()
declare -a HARDWARE_AUR_PACKAGES=()

check_package_manifests() {
  local manifest package
  for manifest in official multilib aur-preinstall aur npm; do
    while IFS= read -r package; do
      [[ $package =~ ^[a-zA-Z0-9@._+-]+$ ]] || die "Invalid $manifest package name: $package"
    done < <(read_manifest "$SETUP_ROOT/packages/$manifest.txt")
  done

  if command_exists pacman; then
    while IFS= read -r package; do
      pacman -Si "$package" >/dev/null 2>&1 || die "Official package is unavailable: $package"
    done < <(read_manifest "$SETUP_ROOT/packages/official.txt")

    if pacman-conf --repo-list | grep -qx multilib; then
      while IFS= read -r package; do
        pacman -Si "$package" >/dev/null 2>&1 || die "Multilib package is unavailable: $package"
      done < <(read_manifest "$SETUP_ROOT/packages/multilib.txt")
    else
      note "multilib is disabled; its package resolution will be verified by pacman after setup enables it"
    fi
  else
    note "pacman unavailable; official package resolution deferred to Arch"
  fi

  if [[ -f /etc/arch-release ]] && command_exists curl; then
    for manifest in aur-preinstall aur; do
      while IFS= read -r package; do
        local count
        count=$(curl -fsSLG 'https://aur.archlinux.org/rpc/v5/info' --data-urlencode "arg[]=$package" | sed -n 's/.*"resultcount":\([0-9]*\).*/\1/p')
        [[ $count == "1" ]] || die "AUR package is unavailable: $package"
      done < <(read_manifest "$SETUP_ROOT/packages/$manifest.txt")
    done
  else
    note "AUR resolution deferred to an Arch host with curl"
  fi
}

bootstrap_yay() {
  command_exists yay && return
  note "Bootstrapping yay-bin from the AUR"
  local build_dir
  build_dir=$(mktemp -d)
  git clone https://aur.archlinux.org/yay-bin.git "$build_dir/yay-bin"
  (cd "$build_dir/yay-bin" && makepkg -si --noconfirm)
  rm -rf "$build_dir"
}

install_packages() {
  local -a official multilib aur_preinstall aur npm
  mapfile -t official < <(read_manifest "$SETUP_ROOT/packages/official.txt")
  mapfile -t multilib < <(read_manifest "$SETUP_ROOT/packages/multilib.txt")
  mapfile -t aur_preinstall < <(read_manifest "$SETUP_ROOT/packages/aur-preinstall.txt")
  mapfile -t aur < <(read_manifest "$SETUP_ROOT/packages/aur.txt")
  mapfile -t npm < <(read_manifest "$SETUP_ROOT/packages/npm.txt")

  if ((${#multilib[@]})) && ! pacman-conf --repo-list | grep -qx multilib; then
    note "Enabling the Arch multilib repository for Steam and 32-bit graphics"
    if grep -q '^#\[multilib\]' /etc/pacman.conf; then
      sudo sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
    else
      printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' | sudo tee -a /etc/pacman.conf >/dev/null
    fi
  fi

  note "Updating Arch and installing official packages"
  sudo pacman -Syu --needed --noconfirm "${official[@]}" "${multilib[@]}" "${HARDWARE_PACKAGES[@]}"
  bootstrap_yay

  if ((${#aur_preinstall[@]})); then
    note "Installing AUR dependency providers"
    yay -S --needed --noconfirm --answerclean None --answerdiff None "${aur_preinstall[@]}"
  fi

  note "Installing AUR packages"
  yay -S --needed --noconfirm --answerclean None --answerdiff None "${aur[@]}" "${HARDWARE_AUR_PACKAGES[@]}"

  if ((${#npm[@]})); then
    note "Installing npm command-line applications"
    mise use --global node@lts
    mise exec node@lts -- npm install --global "${npm[@]}"
  fi
}

print_dry_run() {
  note "Official packages"
  read_manifest "$SETUP_ROOT/packages/official.txt"
  note "Official multilib packages"
  read_manifest "$SETUP_ROOT/packages/multilib.txt"
  note "AUR packages"
  read_manifest "$SETUP_ROOT/packages/aur-preinstall.txt"
  read_manifest "$SETUP_ROOT/packages/aur.txt"
  printf '  %s\n' "${HARDWARE_AUR_PACKAGES[@]}"
  note "npm packages"
  read_manifest "$SETUP_ROOT/packages/npm.txt"
  print_hardware_summary
  note "Would back up conflicting dotfiles, stow configs, install system files, enable services, and create web apps"
}
