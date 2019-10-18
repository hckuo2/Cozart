#!/bin/bash
source constant.sh

control=${1:-0}
epoch=${2:-1}
with_script=${3:-1} # by default, run test scripts, if equals 0, just copy files
start_index=${4:-1} # start epoch index
target_src="/benchmark-scripts/nginx-src"
stat_folder=$workdir/gcov-gprof-stats/nginx
vanilla="/vanilla"
debloated="/debloated"


# vanilla make test
if (($control == "1" || $control == "0"))
then
  for i in `seq $epoch`; do
    cd $workdir
    ./boot-kernel.sh kernelbuild/linux-cosmic/cosmic/base/vmlinuz-4.18.20-linux-cosmic-cosmic-base /benchmark-scripts/nginx-make-test.sh

    sudo rm -r $stat_folder$vanilla/testsuite/epoch$i
    base=$stat_folder$vanilla/testsuite/epoch$i
    mkdir $base
    mkdir $base/gcov $base/gprof $base/gcovr 

    sudo umount --recursive $mnt
    sudo mount -o loop $disk $mnt
  
    cp -r $mnt$target_src/* $base/gcov

    cd $base/gcov
    gcovr -p 2> ../gcovr/err 1> ../gcovr/out
    # gprof ???
    gprof objs/nginx 2> ../gprof/err 1> ../gprof/out
    sudo umount --recursive $mnt
  done
fi
# vanilla bench script
if (($control == "2" || $control == "0"))
then
  for i in `seq $epoch`; do
    cd $workdir
    ./boot-kernel.sh kernelbuild/linux-cosmic/cosmic/base/vmlinuz-4.18.20-linux-cosmic-cosmic-base /benchmark-scripts/nginx-bench.sh

    sudo rm -r $stat_folder$vanilla/bench/epoch$i
    base=$stat_folder$vanilla/bench/epoch$i
    mkdir $base
    mkdir $base/gcov $base/gprof $base/gcovr 

    sudo umount --recursive $mnt
    sudo mount -o loop $disk $mnt
  
    cp -r $mnt$target_src/* $base/gcov

    cd $base/gcov
    sudo gcovr -p 2> ../gcovr/err 1> ../gcovr/out
    # gprof ???
    sudo gprof objs/nginx 2> ../gprof/err 1> ../gprof/out
    sudo umount --recursive $mnt
  done
fi
# debloated make test
if (($control == "3" || $control == "0"))
then
  for i in `seq $epoch`; do
    cd $workdir
    ./boot-kernel.sh kernelbuild/linux-cosmic/cosmic/nginx/vmlinuz-4.18.20-linux-cosmic-cosmic-nginx /benchmark-scripts/nginx-make-test.sh

    sudo rm -r $stat_folder$debloated/testsuite/epoch$i
    base=$stat_folder$debloated/testsuite/epoch$i
    mkdir $base
    mkdir $base/gcov $base/gprof $base/gcovr 

    sudo umount --recursive $mnt
    sudo mount -o loop $disk $mnt
   
    cp -r $mnt$target_src/* $base/gcov

    cd $base/gcov
    gcovr -p 2> ../gcovr/err 1> ../gcovr/out
    #gprof ???
    sudo gprof objs/nginx 2> ../gprof/err 1> ../gprof/out
    sudo umount --recursive $mnt
  done
fi
# debloated bench script
if (($control == "4" || $control == "0"))
then
  for i in `seq $epoch`; do
    cd $workdir
    ./boot-kernel.sh kernelbuild/linux-cosmic/cosmic/nginx/vmlinuz-4.18.20-linux-cosmic-cosmic-nginx /benchmark-scripts/nginx-bench.sh

    sudo rm -r $stat_folder$debloated/bench/epoch$i
    base=$stat_folder$debloated/bench/epoch$i
    mkdir $base
    mkdir $base/gcov $base/gprof $base/gcovr 

    sudo umount --recursive $mnt
    sudo mount -o loop $disk $mnt
   
    cp -r $mnt$target_src/* $base/gcov 

    cd $base/gcov
    sudo gcovr -p 2> ../gcovr/err 1> ../gcovr/out
    sudo gprof objs/nginx 2> ../gprof/err 1> ../gprof/out
    sudo umount --recursive $mnt
  done
fi
