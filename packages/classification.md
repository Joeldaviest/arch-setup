# Package classification

The setup has no custom binary repository.

- `official.txt`: packages resolved by `pacman -Si` from Arch core/extra/multilib.
- `aur.txt`: packages resolved through the AUR RPC and installed by `yay`.
- `npm.txt`: upstream npm command-line applications not supplied by Arch.
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
| OpenCode wrapper | upstream npm `opencode-ai` |
| Omarchy update/channel packages | removed |
| Limine/Snapper/Plymouth packages | outside repository scope |

