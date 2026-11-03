{
  description = "NixOS on a Valve Steam Link";

  inputs.nixos-steamlink.url = "github:slopmaxxer/nixos-steamlink";

  outputs =
    { nixos-steamlink, ... }:
    {
      # Cross-compiled on an x86_64-linux (or aarch64-linux) machine:
      #   nix build .#nixosConfigurations.steamlink.config.system.build.sdImage
      nixosConfigurations.steamlink = nixos-steamlink.lib.mkSystem {
        buildSystem = "x86_64-linux";
        modules = [ ./configuration.nix ];
      };
    };
}
