# Valve Steam Link (original 2015 model: Marvell Berlin BG2CD, 2x Cortex-A9, 512 MiB RAM).
#
# The NAND bootloader only starts Valve-signed kernels, so the stock firmware boots
# first, runs steamlink/factory_test/run.sh from a USB stick's FAT partition, and that
# script kexecs into a mainline kernel. Method from
# https://heap.ovh/getting-linux-on-valve-steam-link.html and
# https://github.com/djmuted/steamlink-debian.
#
# This module provides the kernel, the "boot loader" (writing the kexec files to the FAT
# partition on every switch) and firmware. ./sd-image.nix builds the USB stick.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hardware.steamlink;
  steamlinkPkgs = import ../pkgs { inherit pkgs; };

  # Built twice: for the board (switch-to-configuration) and for the build machine (image).
  mkInstallBoot =
    p:
    p.replaceVarsWith {
      src = ../pkgs/boot/install-boot.sh;
      isExecutable = true;
      replacements = {
        shell = p.runtimeShell;
        path = lib.makeBinPath [
          p.coreutils
          p.findutils
          p.gnused
          p.util-linux
        ];
        bootDir = cfg.bootDir;
        dtb = cfg.dtb;
        maxGenerations = toString cfg.generations;
        runScript = ../pkgs/boot/run.sh;
        kexecModule = "${steamlinkPkgs.kexec-load-module}";
        kexec = lib.getExe steamlinkPkgs.kexec-tools-steamlink;
      };
    };
in
{
  imports = [ ./video.nix ];

  options.hardware.steamlink = {
    enable = lib.mkEnableOption "Valve Steam Link hardware support and the USB kexec boot";

    bootDir = lib.mkOption {
      type = lib.types.str;
      default = "/boot/firmware";
      description = "Mount point of the USB stick's FAT partition, which the stock firmware boots from.";
    };

    rootDevice = lib.mkOption {
      type = lib.types.str;
      example = "PARTUUID=2178694e-02";
      description = ''
        Root partition as the kernel understands it without an initrd
        (`/dev/sdXN`, `PARTUUID=` or `PARTLABEL=`; not `LABEL=` or `/dev/disk/by-*`).
      '';
    };

    dtb = lib.mkOption {
      type = lib.types.str;
      default = "berlin2cd-valve-steamlink.dtb";
      description = "Device tree (from the kernel's dtbs) that kexec hands to the kernel.";
    };

    generations = lib.mkOption {
      type = lib.types.ints.positive;
      default = 5;
      description = "Number of recent generations whose kernel and boot script stay on the FAT partition.";
    };

    populateCmd = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "${mkInstallBoot pkgs.buildPackages}";
      description = ''
        The boot file installer built for the build machine, for image builders:
        `''${populateCmd} -c <toplevel> -d <FAT directory>`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelPackages = pkgs.linuxPackagesFor steamlinkPkgs.linux-steamlink;
    # The kernel mounts root itself (USB storage and ext4 are built in).
    boot.initrd.enable = false;
    boot.kernelParams = [
      "root=${cfg.rootDevice}"
      "rootwait"
      "rw"
      "console=ttyS0,115200n8"
      # USB autosuspend drops the root stick on this board.
      "usbcore.autosuspend=-1"
    ];
    hardware.deviceTree.enable = true;

    boot.loader.grub.enable = false;
    boot.loader.external = {
      enable = true;
      installHook = mkInstallBoot pkgs;
    };

    # Marvell 88W8897 (mwifiex_sdio) Wi-Fi/Bluetooth, without all of linux-firmware.
    hardware.firmware = [
      (pkgs.runCommand "steamlink-firmware" { } ''
        install -Dm644 ${pkgs.linux-firmware}/lib/firmware/mrvl/sd8897_uapsta.bin* -t $out/lib/firmware/mrvl
      '')
      pkgs.wireless-regdb
    ];

    # 512 MiB RAM: compressed swap in RAM instead of wearing out the stick.
    zramSwap.enable = lib.mkDefault true;

    nixpkgs.overlays = [
      (final: prev: {
        # nftables -> libpcap -> rdma-core, whose cmake finds no Python interpreter when
        # cross-compiling. There is no RDMA hardware here anyway.
        libpcap = prev.libpcap.override { withRdma = false; };
      })
    ];
  };
}
