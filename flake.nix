{
  description = "NixOS on the original Valve Steam Link (USB boot via kexec, cross-compiled)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;
      # Machines that can cross-build the system. Not darwin: NixOS runs systemd tools
      # (udevadm for hwdb.bin) on the build machine.
      buildSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forBuildSystems = lib.genAttrs buildSystems;

      example = buildSystem: self.lib.mkSystem {
        inherit buildSystem;
        modules = [ ./examples/configuration.nix ];
      };
    in
    {
      nixosModules = {
        # Everything: hardware, boot, USB image and small-footprint defaults.
        default = {
          imports = [
            ./modules/sd-image.nix
            ./modules/profile.nix
          ];
        };
        hardware = ./modules/hardware.nix;
        sd-image = ./modules/sd-image.nix;
        profile = ./modules/profile.nix;
      };

      lib.mkSystem =
        {
          # The machine that builds the system; "armv7l-linux" builds natively.
          buildSystem ? "x86_64-linux",
          modules ? [ ],
          specialArgs ? { },
        }:
        lib.nixosSystem {
          inherit specialArgs;
          modules = [
            self.nixosModules.default
            { nixpkgs.hostPlatform = "armv7l-linux"; }
            (lib.optionalAttrs (buildSystem != "armv7l-linux") { nixpkgs.buildPlatform = buildSystem; })
          ]
          ++ modules;
        };

      nixosConfigurations.example = example "x86_64-linux";

      packages = forBuildSystems (
        buildSystem:
        let
          system = if buildSystem == "x86_64-linux" then self.nixosConfigurations.example else example buildSystem;
          steamlinkPkgs = import ./pkgs { inherit (system) pkgs; };
        in
        {
          inherit (steamlinkPkgs) linux-steamlink kexec-tools-steamlink;
          example-image = system.config.system.build.sdImage;
          example-toplevel = system.config.system.build.toplevel;
          default = self.packages.${buildSystem}.example-image;
        }
      );

      checks = forBuildSystems (buildSystem: {
        inherit (self.packages.${buildSystem}) kexec-tools-steamlink;
        kernel-config = self.packages.${buildSystem}.linux-steamlink.configfile;
        install-boot = nixpkgs.legacyPackages.${buildSystem}.callPackage ./tests/install-boot.nix {
          populateCmd =
            (if buildSystem == "x86_64-linux" then self.nixosConfigurations.example else example buildSystem)
            .config.hardware.steamlink.populateCmd;
        };
      });

      # hydra.kyouma.net builds these into cache.kyouma.net (armv7l has no other binary cache).
      hydraJobs = {
        inherit (self.packages.x86_64-linux)
          linux-steamlink
          kexec-tools-steamlink
          example-image
          example-toplevel
          ;
        checks = self.checks.x86_64-linux;
      };

      templates.default = {
        path = ./templates/default;
        description = "NixOS configuration for a Valve Steam Link";
      };

      devShells = forBuildSystems (buildSystem: {
        default = nixpkgs.legacyPackages.${buildSystem}.mkShell {
          # Inspecting images: zstd -d, sfdisk -d, mdir/mcopy -i img@@offset, debugfs.
          packages = with nixpkgs.legacyPackages.${buildSystem}; [
            zstd
            util-linux
            mtools
            e2fsprogs
            dtc
          ];
        };
      });

      formatter = forBuildSystems (buildSystem: nixpkgs.legacyPackages.${buildSystem}.nixfmt-rfc-style);
    };
}
