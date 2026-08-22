# Package classification

The setup has no custom binary repository.

- `official.txt`: packages resolved by `pacman -Si` from Arch core/extra.
- `multilib.txt`: official packages that require Arch's disabled-by-default multilib repository.
- `aur-preinstall.txt`: AUR dependency providers installed before the main AUR transaction.
- `aur.txt`: packages resolved through the AUR RPC and installed by `yay`.
- Graphics, legacy network, and kernel-header packages are selected at runtime.

Notable replacements for the previous environment:

| Previous package/workflow | Standalone source |
| --- | --- |
| `omarchy-walker` | AUR `walker-bin` plus `elephant-all-bin` |
| Omarchy GPU Screen Recorder build | official `gpu-screen-recorder` |
| Omarchy Wiremix build | official `wiremix` |
| Omarchy SwayOSD build | official `swayosd` |
| VSCodium | AUR `vscodium-bin` |
| Claude Code | AUR `claude-code` |
| Omarchy update/channel packages | removed |
| Limine/Snapper/Plymouth packages | outside repository scope |
