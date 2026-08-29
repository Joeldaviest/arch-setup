# Package classification

The setup has no custom binary repository.

- `official.txt`: packages resolved by `pacman -Si` from Arch core/extra.
- `multilib.txt`: official packages that require Arch's disabled-by-default multilib repository.
- `aur-preinstall.txt`: AUR dependency providers installed before the main AUR transaction.
- `aur.txt`: packages resolved through the AUR RPC and installed by `yay`.
- CPU microcode, graphics, legacy network, and additional kernel-header
  packages are selected at runtime.

Notable package sources and decisions:

| Package/workflow             | Source or status                                                    |
| ---------------------------- | ------------------------------------------------------------------- |
| Application launcher         | AUR `walker-bin`, `elephant-bin`, and only the configured providers |
| GPU Screen Recorder          | official `gpu-screen-recorder`                                      |
| Wiremix                      | official `wiremix`                                                  |
| SwayOSD                      | official `swayosd`                                                  |
| VSCodium                     | AUR `vscodium-bin`                                                  |
| Claude Code                  | Anthropic native installer (`https://claude.ai/install.sh`)         |
| Waybar media display         | AUR `waybar-module-music-git`                                       |
| Limine/Snapper recovery base | official `limine`, `snapper`, `snap-pac`, and `btrfs-progs`         |
| Plymouth                     | outside repository scope                                            |
