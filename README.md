# nixos-steamlink

NixOS for the original Valve Steam Link (2015; Marvell Berlin BG2CD, 2× Cortex-A9,
512 MiB RAM), booted from a USB stick. A NixOS port of
[djmuted/steamlink-debian](https://github.com/djmuted/steamlink-debian). The internal NAND
is left alone: without the stick, the Steam Link boots Valve's firmware as before.

By default it is a headless box: Ethernet, USB, Wi-Fi/Bluetooth drivers, SSH. Mainline
Linux has no driver for its display pipeline, video decoder or HDMI audio. With
`hardware.steamlink.video.enable` (experimental, see [Video](#video-experimental)), NixOS
runs the stock firmware's own media stack on ported vendor drivers instead, so HDMI,
hardware H.264 decoding and HDMI audio work like on the stock firmware, and stock-firmware
apps such as [steamlink-airplay](https://github.com/slopmaxxer/steamlink-airplay) run as
NixOS services.

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

New kernels take effect at the next boot: `reboot` resets the board, the stock firmware
starts and kexecs the new generation from the stick (untested on hardware; if it hangs,
pull the plug). `poweroff` only halts.

Recovery: if a generation does not boot, put the stick into another computer and copy
`steamlink/generations/<n>.sh` over `steamlink/factory_test/run.sh` on the `FIRMWARE`
partition. `steamlink/boot.log` shows what kexec said.

## Video (experimental)

The media hardware (display processor, HDMI TX, H.264 decoder, audio DSP) is driven by
Marvell's closed userspace, which Valve ships in the firmware: `PE_Single_CPU` (the media
server) and `libSLVideo`/`libSLAudio` for apps. Underneath, it needs only a few kernel
drivers, which are GPL and part of Valve's 3.8.13 kernel source in the
[Steam Link SDK](https://github.com/ValveSoftware/steamlink-sdk). This flake ports them to
mainline and runs the firmware's userspace in a chroot:

- `pkgs/galois-avio`: `galois_shm` (the media memory pools, `/dev/shm_*`), `galois_cc`
  (IPC, `/dev/galois_cc`), `galois_pe` (interrupts and DMA hub, `/dev/galois_pe*`),
  `galois_gpio` (`/dev/gpio`), as out-of-tree modules.
- `pkgs/kernel/berlin-avio.patch`: the 1:1 register mapping those drivers expect, and
  `berlin2cd-valve-steamlink-avio.dtb`, which adds their nodes and reserves the 224 MiB
  the media processors share (Linux keeps 288 MiB, as on the stock firmware).
- `pkgs/steamlink-firmware`: the root filesystem of Valve's public firmware update 930
  (unfree, downloaded from Valve at build time).
- `hardware.steamlink.video.enable` loads the drivers, boots the avio DTB, keeps the
  bootloader's clocks on (`clk_ignore_unused`) and runs `steamlink-pe.service`.
  `hardware.steamlink.video.serviceConfig` puts another unit into the same chroot, which is
  how steamlink-airplay's `services.steamlink-airplay` runs.

```nix
{
  hardware.steamlink.video.enable = true;
}
```

Status: builds; not yet tested on hardware. `journalctl -u steamlink-pe` and `dmesg | grep
-i galois` show what the media server and the drivers do.

## Modules

| Output | What |
|---|---|
| `nixosModules.default` | `sd-image` + `profile` |
| `nixosModules.hardware` | `hardware.steamlink.*`: kernel, kexec boot loader, Wi-Fi firmware, zram |
| `nixosModules.sd-image` | the USB image (`system.build.sdImage`): FAT `FIRMWARE` + ext4 `NIXOS_SD` |
| `nixosModules.profile` | small-footprint defaults (`mkDefault`): minimal profile, no on-device builds, SSH |
| `packages.<system>` | `linux-steamlink`, `kexec-tools-steamlink`, `example-image` |

Options: `hardware.steamlink.rootDevice` (default `PARTUUID=<sdImage disk id>-02`),
`.bootDir` (`/boot/firmware`), `.generations` (5), `.dtb`, `.video.*` (above).

Hardware support:

| Feature | State |
|---|---|
| Ethernet, USB, Wi-Fi + Bluetooth (mwifiex/btmrvl + firmware; configure networks yourself) | works |
| Temperature sensor (berlin2-adc), zram swap, nftables | works |
| Game controllers: built-in Steam Controller receiver (hid-steam), Xbox (xpad), PlayStation, Switch, Bluetooth HID | drivers built |
| `reboot` | SYS_RESET via `gpio-restart` (GPIO A6, as Valve's kernel); the board restarts into the stock firmware, which boots the stick again |
| Watchdog | `/dev/watchdog` on Valve's watchdog (dw_wdt); opt in with `systemd.watchdog.runtimeTime = "30s";` |
| HDMI, H.264 decoding, HDMI audio, CEC | only with `hardware.steamlink.video` (experimental) |
| `poweroff` | halts: the board cannot switch itself off (Valve's firmware only slows its clocks); pull the plug |
| RTC | none on the board (not in Valve's kernel either); timesyncd sets the clock from the network and saves it across reboots |
| Internal NAND | not supported on purpose: it holds the stock firmware in Valve's randomized/read-retry layout, which mainline's NAND driver does not handle, and a write could brick the device |
| Suspend | none: no wake-up sources; Valve's firmware uses clock-slowing instead |

## Credits

- [heap.ovh: Getting Linux on Valve Steam Link](https://heap.ovh/getting-linux-on-valve-steam-link.html)
  (the kexec method) and lukas2511's [steamlink-sdk fork](https://github.com/lukas2511/steamlink-sdk)
  (`kexec_load.ko`, fetched at build time, not included here).
- [djmuted/steamlink-debian](https://github.com/djmuted/steamlink-debian) (GPL-2.0): the
  kernel config `pkgs/kernel/steamlink_defconfig` is derived from its 6.1.115 config.
- Alexander Monakov: the mainline `berlin2cd-valve-steamlink.dts`.

## License

MIT (Nix code and scripts). The kernel config is derived from GPL-2.0 work, see above.
`pkgs/galois-avio/src` and `pkgs/kernel/berlin-avio.patch` are GPL-2.0 (Marvell's drivers
from Valve's kernel, and kernel code). The firmware's binaries are Valve's and are not
part of this repository.
