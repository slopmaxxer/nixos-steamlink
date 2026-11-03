# USB stick image for the Steam Link, from nixpkgs' sd-image.nix:
#   partition 1: FAT32 "FIRMWARE" (the stock firmware's factory_test hook, kernels, kexec),
#                mounted at /boot/firmware
#   partition 2: ext4 "NIXOS_SD" root, grown to the whole stick on first boot
# Build it with config.system.build.sdImage.
{
  config,
  lib,
  modulesPath,
  ...
}:
let
  # sd-image writes sdImage.firmwarePartitionID as the MBR disk ID, so partition 2 is
  # PARTUUID=<id>-02, which the kernel can find without an initrd.
  diskId = lib.toLower (lib.removePrefix "0x" config.sdImage.firmwarePartitionID);
in
{
  imports = [
    "${modulesPath}/installer/sd-card/sd-image.nix"
    ./hardware.nix
  ];

  hardware.steamlink = {
    enable = true;
    rootDevice = lib.mkDefault "PARTUUID=${diskId}-02";
  };

  image.baseName = lib.mkDefault "nixos-steamlink";
  sdImage = {
    # Room for the kernels of several generations (about 6 MiB each).
    firmwareSize = lib.mkDefault 256;
    # Boot files live on the FAT partition only.
    populateRootCommands = lib.mkDefault "";
    populateFirmwareCommands = ''
      ${config.hardware.steamlink.populateCmd} -c ${config.system.build.toplevel} -d ./firmware
    '';
  };
  # sd-image only mounts the firmware partition on demand; here it holds the boot files.
  fileSystems.${config.hardware.steamlink.bootDir} = {
    device = "/dev/disk/by-label/${config.sdImage.firmwarePartitionName}";
    fsType = "vfat";
    options = lib.mkForce [
      "nofail"
      "noatime"
      "umask=0077"
    ];
  };

  # sd-image pulls in all-hardware.nix; this kernel has none of those modules or firmware.
  hardware.enableAllHardware = lib.mkForce false;
  hardware.enableRedistributableFirmware = lib.mkDefault false;
}
