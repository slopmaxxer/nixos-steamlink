# Steam Link packages for an armv7l package set (native, or cross like
# pkgsCross.armv7l-hf-multiplatform).
{ pkgs }:
rec {
  # Plain import, not callPackage: linuxPackagesFor needs the kernel's own .override.
  linux-steamlink = import ./kernel {
    inherit (pkgs) lib runCommand;
    linux = pkgs.linux_6_18;
  };
  linuxPackages-steamlink = pkgs.linuxPackagesFor linux-steamlink;
  galois-avio = linuxPackages-steamlink.callPackage ./galois-avio { };
  # Unfree (Valve's binaries); built for the board, it runs on any build machine.
  steamlink-firmware = pkgs.callPackage ./steamlink-firmware { };

  # Runs on the stock firmware: static, and musl because static glibc refuses its 3.8 kernel.
  kexec-tools-steamlink = pkgs.pkgsStatic.callPackage ./kexec-tools { };

  # Prebuilt module that adds the kexec_load syscall to Valve's 3.8.13-mrvl kernel
  # (vermagic "3.8.13-mrvl preempt mod_unload ARMv7"). Building it needs Valve's vendor
  # kernel tree and a contemporary toolchain; every Steam Link port uses this same file.
  kexec-load-module = pkgs.fetchurl {
    name = "kexec_load.ko";
    url = "https://github.com/lukas2511/steamlink-sdk/raw/3083b94a3a2af78837e084e6a8c04d5feea7edbe/build/kexec_load.ko";
    hash = "sha256-sbinlkoG1+vNRRcLZWX22eNIxfyIXro65/yBj0BLGVY=";
  };
}
