# Runs the real boot file installer (as the image build does) against a fake toplevel and
# checks the FAT layout and the generated run.sh.
{
  runCommand,
  shellcheck,
  populateCmd,
}:
runCommand "steamlink-install-boot-test" { nativeBuildInputs = [ shellcheck ]; } ''
  top=$PWD/top
  mkdir -p $top/dtbs/synaptics fat
  echo zimage > $top/kernel
  echo dtb > $top/dtbs/synaptics/berlin2cd-valve-steamlink.dtb
  echo '#!/bin/sh' > $top/init
  printf 'root=PARTUUID=2178694e-02 rootwait' > $top/kernel-params

  ${populateCmd} -c $top -d fat
  # A second run must reuse the files and leave the same tree.
  ${populateCmd} -c $top -d fat

  sl=fat/steamlink
  test -x $sl/kexec
  test -s $sl/kexec_load.ko
  test "$(ls $sl/nixos | wc -l)" -eq 2
  run=$sl/factory_test/run.sh
  cat $run
  if grep -nE '@[A-Za-z_]+@|%[A-Z]+%' $run; then echo "unsubstituted placeholder"; exit 1; fi
  grep -q -- "--command-line \"init=$top/init root=PARTUUID=2178694e-02 rootwait\"" $run
  grep -q -- '--dtb "$d/nixos/.*-berlin2cd-valve-steamlink.dtb"' $run
  shellcheck -s sh $run
  touch $out
''
