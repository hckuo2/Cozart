#!/bin/bash
source constant.sh

control=${1:-0}
epoch=${2:-1}

target_src="/benchmark-scripts/test-apache/httpd-2.4.39"
stat_folder=$workdir/gcov-gprof-stats/apache
vanilla="/vanilla"
debloated="/debloated"


# vanilla make test
if (($control == "1" || $control == "0"))
then
  for i in `seq $epoch`; do
    cd $workdir
    ./boot-kernel.sh kernelbuild/linux-cosmic/cosmic/base/vmlinuz-4.18.20-linux-cosmic-cosmic-base /benchmark-scripts/apache-make-test.sh

    sudo rm -r $stat_folder$vanilla/testsuite/epoch$i
    base=$stat_folder$vanilla/testsuite/epoch$i
    mkdir $base
    mkdir $base/gcov $base/gprof $base/gcovr 

    sudo umount --recursive $mnt
    sudo mount -o loop $disk $mnt
  
    sudo cp -r $mnt$target_src/* $base/gcov

    cd $base/gcov
    sudo gcovr -p 2> ../gcovr/err 1> ../gcovr/out
    # gprof ???
    sudo umount --recursive $mnt
  done
fi
# vanilla bench script
if (($control == "2" || $control == "0"))
then
  for i in `seq $epoch`; do
    cd $workdir
    ./boot-kernel.sh kernelbuild/linux-cosmic/cosmic/base/vmlinuz-4.18.20-linux-cosmic-cosmic-base /benchmark-scripts/apache-bench.sh

    sudo rm -r $stat_folder$vanilla/bench/epoch$i
    base=$stat_folder$vanilla/bench/epoch$i
    mkdir $base
    mkdir $base/gcov $base/gprof $base/gcovr 

    sudo umount --recursive $mnt
    sudo mount -o loop $disk $mnt
  
    sudo cp -r $mnt$target_src/* $base/gcov

    cd $base/gcov
    sudo gcovr -p 2> ../gcovr/err 1> ../gcovr/out
    # gprof ???
    sudo umount --recursive $mnt
  done
fi
# debloated make test
if (($control == "3" || $control == "0"))
then
  for i in `seq $epoch`; do
    cd $workdir
    ./boot-kernel.sh kernelbuild/linux-cosmic/cosmic/apache/vmlinuz-4.18.20-linux-cosmic-cosmic-apache /benchmark-scripts/apache-make-test.sh

    sudo rm -r $stat_folder$debloated/testsuite/epoch$i
    base=$stat_folder$debloated/testsuite/epoch$i
    mkdir $base
    mkdir $base/gcov $base/gprof $base/gcovr 

    sudo umount --recursive $mnt
    sudo mount -o loop $disk $mnt
   
    sudo cp -r $mnt$target_src $base/gcov

    cd $base/gcov
    sudo gcovr -p 2> ../gcovr/err 1> ../gcovr/out
    #gprof ???
    sudo umount --recursive $mnt
  done
fi
# debloated bench script
if (($control == "4" || $control == "0"))
then
  for i in `seq $epoch`; do
    cd $workdir
    ./boot-kernel.sh kernelbuild/linux-cosmic/cosmic/apache/vmlinuz-4.18.20-linux-cosmic-cosmic-apache /benchmark-scripts/apache-bench.sh

    sudo rm -r $stat_folder$debloated/bench/epoch$i
    base=$stat_folder$debloated/bench/epoch$i
    mkdir $base
    mkdir $base/gcov $base/gprof $base/gcovr 

    sudo umount --recursive $mnt
    sudo mount -o loop $disk $mnt
   
    sudo cp -r $mnt$target_src/* $base/gcov 

    cd $base/gcov
    sudo gcovr -p 2> ../gcovr/err 1> ../gcovr/out
    #gprof ???
    sudo umount --recursive $mnt
  done
fi
