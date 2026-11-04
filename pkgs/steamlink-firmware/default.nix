# The root filesystem of Valve's stock Steam Link firmware (public update, build 930), as
# the updater would install it: glibc 2.19 userspace with Marvell's media stack
# (PE_Single_CPU, libSLVideo, libSLAudio, ...). ../../modules/video.nix runs it in a chroot
# on top of the galois-avio drivers. Downloaded from Valve, not redistributed.
{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
  python3,
}:
stdenvNoCC.mkDerivation {
  pname = "steamlink-firmware";
  version = "930";

  src = fetchurl {
    url = "http://media.steampowered.com/steamlink/06_2015/SystemUpdate_full_930.zip";
    hash = "sha256-GLKqm1keOZFOo5JsMO4Vsnm+8kkS0q9KqQUoG50n5bg=";
  };

  nativeBuildInputs = [
    unzip
    python3
  ];

  unpackPhase = ''
    runHook preUnpack
    unzip -q $src 'system/*' META-INF/com/google/android/updater-script
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    python3 ${./apply-updater-script.py} META-INF/com/google/android/updater-script system
    # Modules for Valve's 3.8 kernel are of no use; the chroot needs these mount points.
    rm -r system/lib/modules
    mkdir -p system/data system/run system/mnt/scratch system/mnt/config
    mv system $out
    runHook postInstall
  '';

  # Prebuilt binaries for the firmware's own glibc: leave them exactly as shipped.
  dontFixup = true;

  meta = {
    description = "Root filesystem of the Valve Steam Link stock firmware (media stack userspace)";
    homepage = "https://github.com/ValveSoftware/steamlink-sdk";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "armv7l-linux" ];
  };
}
