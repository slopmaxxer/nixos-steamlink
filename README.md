# nixos-steamlink

NixOS for the original Valve Steam Link (2015; Marvell Berlin BG2CD, 2× Cortex-A9,
512 MiB RAM), booted from a USB stick. A NixOS port of
[djmuted/steamlink-debian](https://github.com/djmuted/steamlink-debian). The internal NAND
is left alone: without the stick, the Steam Link boots Valve's firmware as before.

It is a headless box: Ethernet, USB, Wi-Fi/Bluetooth drivers, SSH. Mainline Linux has no
driver for its display pipeline, audio or NAND, so HDMI stays dark once NixOS runs. For
video on the TV (e.g. AirPlay mirroring), use the stock firmware with an app such as
[steamlink-airplay](https://github.com/slopmaxxer/steamlink-airplay) instead.

## How it boots

The NAND bootloader only starts Valve-signed kernels. But the stock firmware runs
`steamlink/factory_test/run.sh` from a USB stick on every boot. On the stick's FAT
partition, that script

1. loads `kexec_load.ko` into Valve's Linux 3.8.13 (the prebuilt module every Steam Link
   port uses; it adds the `kexec_load` syscall),
2. runs a static musl kexec-tools 2.0.15 (built here; newer versions fail on this
   kernel, static glibc refuses it),
3. jumps into mainline Linux 6.18 with the in-tree `berlin2cd-valve-steamlink.dtb` and
   `init=` of the NixOS generation.

There is no initrd: USB storage and ext4 are built into the kernel (board config derived
from steamlink-debian's), which mounts `root=PARTUUID=…-02` itself.

`nixos-rebuild switch` acts as the boot loader (`boot.loader.external`): it copies the
kernel and DTB of the last 5 generations into `steamlink/nixos/` and writes
`steamlink/factory_test/run.sh` (default) and `steamlink/generations/<n>.sh`. Each boot
leaves `steamlink/boot.log` on the FAT partition.

## Use it

```console
nix flake init -t github:slopmaxxer/nixos-steamlink
$EDITOR configuration.nix        # add your SSH key
nix build .#nixosConfigurations.steamlink.config.system.build.sdImage
```

Or add it to an existing flake:

```nix
{
  inputs.nixos-steamlink.url = "github:slopmaxxer/nixos-steamlink";
  inputs.nixos-steamlink.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { nixos-steamlink, ... }: {
    nixosConfigurations.steamlink = nixos-steamlink.lib.mkSystem {
      buildSystem = "x86_64-linux"; # or "aarch64-linux"
      modules = [ ./steamlink.nix ];
    };
  };
}
```

`lib.mkSystem` is `nixpkgs.lib.nixosSystem` with `nixosModules.default` and the
cross-compilation platforms set. With your own `nixosSystem`, import
`nixosModules.default` and set `nixpkgs.buildPlatform`.

armv7l has no NixOS binary cache, so the first build compiles about 450 derivations
(around an hour on 12 cores). It has to run on Linux: macOS cannot build NixOS systems
(on a Mac, use nix-darwin's `linux-builder` with `buildSystem = "aarch64-linux"`).
hydra.kyouma.net builds this flake's example system into `https://cache.kyouma.net`
(key `cache.kyouma.net:Frjwu4q1rnwE/MnSTmX9yx86GNA/z3p/oElGvucLiZg=`); configurations on
the same nixpkgs share most of it.

## Install

```console
zstd -d result/sd-image/nixos-steamlink.img.zst -o steamlink.img
sudo dd if=steamlink.img of=/dev/disk/by-id/usb-<the stick> bs=4M conv=fsync status=progress
```

(macOS: `diskutil unmountDisk /dev/diskN`, then `dd … of=/dev/rdiskN bs=4m`.)

Plug in the stick and Ethernet, power on. The Steam splash stays on screen; after about a
minute NixOS answers SSH (DHCP address, or `<hostname>.local` with Avahi as in the
template). The first boot grows the root partition to the whole stick.

Update from a Linux machine with Nix that reaches it (the Steam Link never builds):

```console
nixos-rebuild switch --flake .#steamlink --target-host root@steamlink.local
```

New kernels take effect at the next power cycle. `reboot` and `poweroff` do not return on
this board: pull the plug.

Recovery: if a generation does not boot, put the stick into another computer and copy
`steamlink/generations/<n>.sh` over `steamlink/factory_test/run.sh` on the `FIRMWARE`
partition. `steamlink/boot.log` shows what kexec said.

## Modules

| Output | What |
|---|---|
| `nixosModules.default` | `sd-image` + `profile` |
| `nixosModules.hardware` | `hardware.steamlink.*`: kernel, kexec boot loader, Wi-Fi firmware, zram |
| `nixosModules.sd-image` | the USB image (`system.build.sdImage`): FAT `FIRMWARE` + ext4 `NIXOS_SD` |
| `nixosModules.profile` | small-footprint defaults (`mkDefault`): minimal profile, no on-device builds, SSH |
| `packages.<system>` | `linux-steamlink`, `kexec-tools-steamlink`, `example-image` |

Options: `hardware.steamlink.rootDevice` (default `PARTUUID=<sdImage disk id>-02`),
`.bootDir` (`/boot/firmware`), `.generations` (5).

Works: Ethernet, USB, Wi-Fi and Bluetooth drivers + firmware (configure networks
yourself), temperature sensor, zram swap, nftables. Does not work in mainline: HDMI,
audio, NAND, DMA, RTC, suspend, reboot/poweroff.

## Credits

- [heap.ovh: Getting Linux on Valve Steam Link](https://heap.ovh/getting-linux-on-valve-steam-link.html)
  (the kexec method) and lukas2511's [steamlink-sdk fork](https://github.com/lukas2511/steamlink-sdk)
  (`kexec_load.ko`, fetched at build time, not included here).
- [djmuted/steamlink-debian](https://github.com/djmuted/steamlink-debian) (GPL-2.0): the
  kernel config `pkgs/kernel/steamlink_defconfig` is derived from its 6.1.115 config.
- Alexander Monakov: the mainline `berlin2cd-valve-steamlink.dts`.

## License

MIT (Nix code and scripts). The kernel config is derived from GPL-2.0 work, see above.
