#!/bin/bash

set -Eeuo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/scripts/lib/common.sh"

backup_root="$HOME/.local/state/arch-setup/backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup_root"

backup_conflicts() {
  local package=$1 source_file relative target backup
  while IFS= read -r -d '' source_file; do
    relative=${source_file#"$SETUP_ROOT/dotfiles/$package/"}
    target="$HOME/$relative"
    local parent="$HOME" component
    IFS=/ read -ra components <<<"$(dirname "$relative")"
    for component in "${components[@]}"; do
      [[ -n $component && $component != "." ]] || continue
      parent="$parent/$component"
      if [[ -L $parent ]]; then
        backup="$backup_root/${parent#"$HOME/"}"
        mkdir -p "$(dirname "$backup")"
        mv "$parent" "$backup"
        mkdir -p "$parent"
        note "Backed up linked directory $parent"
      fi
    done
    [[ -e $target || -L $target ]] || continue
    [[ -L $target && $(readlink -f "$target") == $(readlink -f "$source_file") ]] && continue
    backup="$backup_root/$relative"
    mkdir -p "$(dirname "$backup")"
    mv "$target" "$backup"
    note "Backed up $target"
  done < <(find "$SETUP_ROOT/dotfiles/$package" -type f -print0)
}

note "Backing up dotfile conflicts"
for package_dir in "$SETUP_ROOT"/dotfiles/*; do
  package=$(basename "$package_dir")
  backup_conflicts "$package"
done

note "Linking dotfiles with Stow"
for package_dir in "$SETUP_ROOT"/dotfiles/*; do
  stow --no-folding --restow --dir="$SETUP_ROOT/dotfiles" --target="$HOME" "$(basename "$package_dir")"
done

local_dir="$HOME/.config/hypr/local"
mkdir -p "$local_dir"
for file in monitors.lua input.lua environment.lua autostart.lua; do
  [[ -e $local_dir/$file ]] || touch "$local_dir/$file"
done

wallpaper_dir="$HOME/.config/wallpapers"
mkdir -p "$wallpaper_dir"
rsync -a "$SETUP_ROOT/assets/wallpapers/" "$wallpaper_dir/"
ARCH_SETUP_WALLPAPER_DIR="$wallpaper_dir" \
  "$SETUP_ROOT/dotfiles/bin/.local/bin/wallpaper-start" --set-only

if [[ -z $(find "$backup_root" -type f -o -type l | head -1) ]]; then
  rmdir -p "$backup_root" 2>/dev/null || true
fi
