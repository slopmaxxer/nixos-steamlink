# Defaults for a headless 512 MiB armv7l box that never builds anything itself: closures are
# built (cross-compiled) elsewhere and copied over. All of them can be overridden.
{ lib, modulesPath, ... }:
{
  imports = [ "${modulesPath}/profiles/minimal.nix" ];

  nixpkgs.hostPlatform = lib.mkDefault "armv7l-linux";

  # Receive closures (nixos-rebuild --target-host), never build or evaluate on the device.
  nix.settings.max-jobs = lib.mkDefault 0;
  nixpkgs.flake.setNixPath = lib.mkDefault false;
  nixpkgs.flake.setFlakeRegistry = lib.mkDefault false;
  system.disableInstallerTools = lib.mkDefault true;
  programs.command-not-found.enable = lib.mkDefault false;

  # Ethernet works out of the box; HDMI does not, so SSH is the console.
  services.openssh.enable = lib.mkDefault true;
}
