# Package classification

The setup has no custom binary repository.

- `official.txt`: packages resolved by `pacman -Si` from Arch core/extra.
- `multilib.txt`: official packages that require Arch's disabled-by-default multilib repository.
- `aur-preinstall.txt`: AUR dependency providers installed before the main AUR transaction.
- `aur.txt`: packages resolved through the AUR RPC and installed by `yay`.
- CPU microcode, graphics, legacy network, and additional kernel-header
  packages are selected at runtime.

Notable replacements for the previous environment:

| Previous package/workflow | Standalone source |
| --- | --- |
| `omarchy-walker` | AUR `walker-bin`, `elephant-bin`, and only the configured providers |
| Omarchy GPU Screen Recorder build | official `gpu-screen-recorder` |
| Omarchy Wiremix build | official `wiremix` |
| Omarchy SwayOSD build | official `swayosd` |
| VSCodium | AUR `vscodium-bin` |
| Claude Code | AUR `claude-code` |
| Omarchy update/channel packages | removed |
| Limine/Snapper recovery base | official `limine`, `snapper`, `snap-pac`, and `btrfs-progs` |
| Plymouth | outside repository scope |
