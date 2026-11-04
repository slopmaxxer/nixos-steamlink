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
- Video (`modules/video.nix`, README "Video"): Marvell's AVIO drivers in
  `pkgs/galois-avio/src` (first commit = verbatim copy from the SDK kernel's
  `arch/arm/mach-berlin`; port changes on top, keep them minimal and mainline-API only),
  `pkgs/kernel/berlin-avio.patch` (1:1 map of 0xf7000000 as the vendor kernel did: the
  drivers dereference physical register addresses; avio DTB with shm/pe/gpio nodes and the
  shm reservation 0x12000000-0x20000000), `pkgs/steamlink-firmware` (update 930's
  system/, links and modes replayed from its updater-script). The firmware 930 galois_pe.ko
  has the same functions as the SDK source. The stock boot runs factory_test/run.sh before
  PE starts (S01config), so after kexec the hardware is in its bootloader state, as for
  PE on the stock firmware. Fast module rebuilds: `make -C <kernel.dev>/lib/modules/*/build
  M=<copy of src> modules` with the cross toolchain and `kernelModuleMakeFlags`.
  PE_Single_CPU under qemu-arm loads all libraries and stops at mapping /dev/mem (expected).
- Hardware table in README. Reboot needed GPIO_DWAPB + POWER_RESET_GPIO_RESTART (the
  mainline DT's gpio-restart on GPIO A6 had no driver); `steamlink-watchdog.patch` moves
  the enabled watchdog from SM wdt0 to wdt4 (0xf7e82000, the one Valve's S80watchdog uses;
  it starts after S01config, so it is never armed across the kexec). No RTC on the board,
  NAND deliberately unsupported (Valve's randomizer/read-retry layout, brick risk).
- Kernel options: `pkgs/kernel/steamlink_defconfig` (board, from steamlink-debian's 6.1 config)
  plus `structuredExtraConfig` in `pkgs/kernel/default.nix` (systemd/NixOS needs). buildLinux
  kernels skip NixOS's requiredKernelConfig assertions, so check the generated `.configfile`.
