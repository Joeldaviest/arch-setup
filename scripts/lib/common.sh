#!/bin/bash

if [[ -z ${SETUP_ROOT:-} ]]; then
  SETUP_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fi

color_blue=$'\e[34m'
color_green=$'\e[32m'
color_red=$'\e[31m'
color_reset=$'\e[0m'

note() { printf '%s==>%s %s\n' "$color_blue" "$color_reset" "$*"; }
success() { printf '%s==>%s %s\n' "$color_green" "$color_reset" "$*"; }
die() { printf '%sError:%s %s\n' "$color_red" "$color_reset" "$*" >&2; exit 1; }
command_exists() { command -v "$1" >/dev/null 2>&1; }

read_manifest() {
  sed -E 's/[[:space:]]+#.*$//' "$1" | sed -E '/^[[:space:]]*(#|$)/d'
}

check_host() {
  (( EUID != 0 )) || die "Run setup as a normal user, not root"
  [[ $(uname -m) == "x86_64" ]] || die "Only x86-64 is supported"

  if [[ ${SETUP_MODE:-apply} != "check" || -f /etc/arch-release ]]; then
    [[ -f /etc/arch-release ]] || die "This setup requires vanilla Arch Linux"
  else
    note "Non-Arch host: repository checks only; installation is disabled"
  fi

  command_exists bash || die "bash is required"
  command_exists git || note "git will be installed during bootstrap"
  command_exists sudo || [[ ${SETUP_MODE:-} == "check" ]] || die "sudo is required"
}

check_repository() {
  local required=(setup.sh packages/official.txt packages/multilib.txt packages/aur-preinstall.txt packages/aur.txt packages/npm.txt scripts/configure-dotfiles.sh scripts/configure-system.sh system/20-wired.network)
  local path
  for path in "${required[@]}"; do
    [[ -f $SETUP_ROOT/$path ]] || die "Missing repository file: $path"
  done

  if grep -RInE 'pkgs\.omarchy|mirror\.omarchy|\[omarchy\]' "$SETUP_ROOT" --exclude=README.md; then
    die "Omarchy repository reference detected"
  fi

  local duplicates
  duplicates=$(cat \
    <(read_manifest "$SETUP_ROOT/packages/official.txt") \
    <(read_manifest "$SETUP_ROOT/packages/multilib.txt") \
    <(read_manifest "$SETUP_ROOT/packages/aur-preinstall.txt") \
    <(read_manifest "$SETUP_ROOT/packages/aur.txt") | sort | uniq -d)
  [[ -z $duplicates ]] || die "Packages classified in more than one pacman/AUR manifest: $duplicates"

  local script
  while IFS= read -r script; do
    bash -n "$script" || die "Invalid Bash syntax: $script"
  done < <(find "$SETUP_ROOT" -path "$SETUP_ROOT/.git" -prune -o -type f \( -perm -u+x -o -name '*.sh' \) -print)
}

run() {
  if [[ ${SETUP_MODE:-apply} == "dry-run" ]]; then
    printf '+ '
    printf '%q ' "$@"
    printf '\n'
  else
    "$@"
  fi
}
