# Marvell's Berlin AVIO kernel drivers (galois_shm, galois_cc, galois_pe), the kernel half of
# the stock firmware's video stack, ported from Valve's 3.8.13-mrvl kernel to mainline.
# With them, the firmware's own closed userspace (PE_Single_CPU, libSLVideo, libSLAudio)
# drives HDMI, the H.264 decoder and audio; see ../../modules/video.nix.
{
  lib,
  stdenv,
  kernel,
  kernelModuleMakeFlags,
}:
stdenv.mkDerivation {
  pname = "galois-avio";
  version = "3.8.13-mrvl-${kernel.version}";
  src = ./src;

  nativeBuildInputs = kernel.moduleBuildDependencies;
  makeFlags = kernelModuleMakeFlags ++ [
    "-C"
    "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
  ];
  buildFlags = [ "modules" ];
  preBuild = ''
    makeFlagsArray+=("M=$PWD")
  '';
  installFlags = [ "INSTALL_MOD_PATH=${placeholder "out"}" ];
  installTargets = [ "modules_install" ];
  enableParallelBuilding = true;

  meta = {
    description = "Marvell Berlin BG2CD AVIO drivers (pe, shm, cc) for the Valve Steam Link";
    license = lib.licenses.gpl2Only;
    platforms = [ "armv7l-linux" ];
  };
}
