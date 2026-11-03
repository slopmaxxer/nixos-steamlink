# nixos-steamlink development notes

Follow `/home/slop/CLAUDE.md`. `AGENTS.md` links here. Keep this file and README current.
Public, generic flake (MIT): NixOS on the original Valve Steam Link. Our own Steam Link host
config (users, keys, deployment) lives in nixfiles (`config/hosts/steamlink`), which uses this
flake as input `nixos-steamlink`; nothing personal belongs here.

- Layout: `modules/hardware.nix` (`hardware.steamlink.*`: kernel, `boot.loader.external` hook,
  firmware, cross fixes), `modules/sd-image.nix` (USB image on nixpkgs' sd-image.nix),
  `modules/profile.nix` (mkDefault small-footprint settings), `pkgs/` (kernel + defconfig,
  static musl kexec-tools 2.0.15, fetched `kexec_load.ko`, boot scripts), `tests/`,
  `examples/configuration.nix` (= `templates/default/configuration.nix`, keep in sync).
- Boot chain and limits: README. `pkgs/boot/run.sh` runs under Valve's 3.8 firmware shell
  (busybox sh): keep it POSIX, static binaries only. Its placeholders are `%…%` because
  install-boot.sh's own build-time substitution uses `@…@`.
- Checks: `nix flake check` (static kexec, kernel config, install-boot test against a fake
  toplevel; shellcheck of run.sh). Full system: `nix build .#example-image` (~450 cross
  derivations without cache). Only Linux build platforms work (systemd tools run at build time).
- CI: hydra.kyouma.net project `nixos-steamlink`, jobset `main`, `hydraJobs` = packages +
  checks for x86_64-linux; results in cache.kyouma.net. nixpkgs is locked to the same revision
  as nixfiles so the host shares the cache.
- Never boot-tested before 2026-11-03; record hardware test results here.
- Kernel options: `pkgs/kernel/steamlink_defconfig` (board, from steamlink-debian's 6.1 config)
  plus `structuredExtraConfig` in `pkgs/kernel/default.nix` (systemd/NixOS needs). buildLinux
  kernels skip NixOS's requiredKernelConfig assertions, so check the generated `.configfile`.
