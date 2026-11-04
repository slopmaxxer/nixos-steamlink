# HDMI video, the H.264 decoder and HDMI audio on mainline, through the stock firmware's own
# media stack: Marvell's AVIO kernel drivers (pkgs/galois-avio, ported from Valve's 3.8
# kernel) plus Valve's userspace from the firmware update (pkgs/steamlink-firmware), run
# in a chroot. PE_Single_CPU is the media server; apps talk to it through libSLVideo /
# libSLAudio exactly as on the stock firmware, so stock-firmware apps (Moonlight,
# steamlink-airplay) run unchanged inside `hardware.steamlink.video.serviceConfig`.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hardware.steamlink.video;
  steamlinkPkgs = import ../pkgs { inherit pkgs; };
in
{
  options.hardware.steamlink.video = {
    enable = lib.mkEnableOption ''
      HDMI output, hardware video decoding and HDMI audio via the stock firmware's media
      stack (Valve's unfree binaries, downloaded from Valve). Linux then keeps off the
      224 MiB of RAM the media processors use, as the stock kernel did'';

    firmware = lib.mkOption {
      type = lib.types.package;
      default = steamlinkPkgs.steamlink-firmware;
      defaultText = lib.literalExpression "nixos-steamlink's steamlink-firmware";
      description = "Root filesystem of the stock firmware, used as the media stack's chroot.";
    };

    serviceConfig = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      description = ''
        systemd `serviceConfig` that runs a unit inside the firmware chroot with the media
        devices, the media server's /tmp and /data. Merge it into your own unit to run a
        stock-firmware app, and order the unit after `steamlink-pe.service`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.steamlink.dtb = "berlin2cd-valve-steamlink-avio.dtb";
    boot.extraModulePackages = [
      (config.boot.kernelPackages.callPackage ../pkgs/galois-avio { })
    ];
    boot.kernelModules = [
      "galois_shm"
      "galois_cc"
      "galois_pe"
      "galois_gpio"
    ];
    # The bootloader switched the AVIO clocks on and mainline knows no consumer for them.
    boot.kernelParams = [ "clk_ignore_unused" ];

    nixpkgs.config.allowUnfreePredicate = lib.mkDefault (
      pkg: builtins.elem (lib.getName pkg) [ "steamlink-firmware" ]
    );

    hardware.steamlink.video.serviceConfig = {
      RootDirectory = "${cfg.firmware}";
      # /proc, /sys and the host's /dev (galois_*, shm_*, mem).
      MountAPIVFS = true;
      BindPaths = [
        "/run/steamlink-media:/tmp"
        "/var/lib/steamlink-media:/data"
      ];
      TemporaryFileSystem = [
        "/var:mode=0755"
        "/mnt/scratch:mode=0755"
      ];
    };

    systemd.tmpfiles.rules = [
      "d /run/steamlink-media 1777 root root -"
      "d /var/lib/steamlink-media 0755 root root -"
    ];

    systemd.services.steamlink-pe = {
      description = "Steam Link media server (stock firmware PE_Single_CPU)";
      wantedBy = [ "multi-user.target" ];
      after = [
        "systemd-modules-load.service"
        "systemd-tmpfiles-setup.service"
      ];
      environment = {
        # As in the firmware's /home/steam/rc.local.
        LD_LIBRARY_PATH = "/home/steam/lib";
        # The chroot's own tools, not the Nix store's.
        PATH = lib.mkForce "/home/steam/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      };
      serviceConfig = cfg.serviceConfig // {
        # "+": outside the chroot. Apps wait for PE to (re)create this file.
        ExecStartPre = "+${pkgs.coreutils}/bin/rm -f /run/steamlink-media/pe_ready";
        ExecStart = "/home/steam/bin/PE_Single_CPU";
        Nice = -10;
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };
}
