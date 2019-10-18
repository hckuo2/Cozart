#!/bin/bash
source constant.sh

control=${1:-0}
epoch=${2:-1}
with_script=${3:-1} # default to 1 (run test scripts), if equals 0, just copy files
start_index=${4:-1} # start epoch index
disk=${5:-$disk} # use the one (qemu-disk.ext4) in constant if not specified

target_src="/benchmark-scripts/mysql-src"
target_bin="/benchmark-scripts/mysql-src/bld"
stat_folder=$workdir/gcov-gprof-stats/mysql
vanilla="/vanilla"
debloated="/debloated"

# vanilla make test
if (($control == "1" || $control == "0"))
then
  for i in `seq $epoch`; do
    if [ $i -lt $start_index ]
    then
      continue
    fi

    cd $workdir
    if [ "$with_script" == "1" ]
    then	    
      ./boot-kernel.sh kernelbuild/linux-cosmic/cosmic/base/vmlinuz-4.18.20-linux-cosmic-cosmic-base /benchmark-scripts/mysql-make-test.sh $disk
    fi
    sudo rm -r $stat_folder$vanilla/testsuite/epoch$i
    base=$stat_folder$vanilla/testsuite/epoch$i
    mkdir $base
    mkdir $base/gcov $base/gprof $base/gcovr 

    sudo umount --recursive $mnt
    sudo mount -o loop $disk $mnt
  
    sudo cp -r $mnt$target_src/* $base/gcov
    sudo rm -r /benchmark-scripts/mysql-src/*
    sudo cp -r $base/gcov/* /benchmark-scripts/mysql-src
    cd /benchmark-scripts/mysql-src
    sudo gcovr -p 2> $base/gcovr/err 1> $base/gcovr/out

    # gprof ???
    sudo umount --recursive $mnt
  done
fi
# vanilla bench script
if (($control == "2" || $control == "0"))
then
  for i in `seq $epoch`; do
    if [ $i -lt $start_index ]
    then
      continue
    fi
    cd $workdir
    if [ "$with_script" == "1" ]
    then	    
      ./boot-kernel.sh kernelbuild/linux-cosmic/cosmic/base/vmlinuz-4.18.20-linux-cosmic-cosmic-base /benchmark-scripts/mysql-bench.sh $disk
    fi
    sudo rm -r $stat_folder$vanilla/bench/epoch$i
    base=$stat_folder$vanilla/bench/epoch$i
    mkdir $base
    mkdir $base/gcov $base/gprof $base/gcovr 

    sudo umount --recursive $mnt
    sudo mount -o loop $disk $mnt
  
    sudo cp -r $mnt$target_src/* $base/gcov
    sudo rm -r /benchmark-scripts/mysql-src/*
    sudo cp -r $base/gcov/* /benchmark-scripts/mysql-src

    cd /benchmark-scripts/mysql-src
    sudo gcovr -p 2> $base/gcovr/err 1> $base/gcovr/out

    # gprof ???
    sudo umount --recursive $mnt
  done
fi
# debloated make test
if (($control == "3" || $control == "0"))
then
  for i in `seq $epoch`; do
    if [ $i -lt $start_index ]
    then
      continue
    fi
    cd $workdir
    if [ "$with_script" == "1" ]
    then	    
      ./boot-kernel.sh kernelbuild/linux-cosmic/cosmic/mysql-test/vmlinuz-4.18.20-linux-cosmic-cosmic-mysql-test /benchmark-scripts/mysql-make-test.sh $disk
    fi
    sudo rm -r $stat_folder$debloated/testsuite/epoch$i
    base=$stat_folder$debloated/testsuite/epoch$i
    mkdir $base
    mkdir $base/gcov $base/gprof $base/gcovr 

    sudo umount --recursive $mnt
    sudo mount -o loop $disk $mnt
   
    sudo cp -r $mnt$target_src/* $base/gcov
    sudo rm -r /benchmark-scripts/mysql-src/*
    sudo cp -r $base/gcov/* /benchmark-scripts/mysql-src
    cd /benchmark-scripts/mysql-src
    sudo gcovr -p 2> $base/gcovr/err 1> $base/gcovr/out

    #gprof ???
    sudo umount --recursive $mnt
  done
fi
# debloated bench script
if (($control == "4" || $control == "0"))
then
  for i in `seq $epoch`; do
    if [ $i -lt $start_index ]
    then
      continue
    fi
    cd $workdir
    if [ "$with_script" == "1" ]
    then	    
      ./boot-kernel.sh kernelbuild/linux-cosmic/cosmic/mysql/vmlinuz-4.18.20-linux-cosmic-cosmic-mysql /benchmark-scripts/mysql-bench.sh $disk
    fi
    sudo rm -r $stat_folder$debloated/bench/epoch$i
    base=$stat_folder$debloated/bench/epoch$i
    mkdir $base
    mkdir $base/gcov $base/gprof $base/gcovr 

    sudo umount --recursive $mnt
    sudo mount -o loop $disk $mnt
   
    sudo cp -r $mnt$target_src/* $base/gcov 
    sudo rm -r /benchmark-scripts/mysql-src/*
    sudo cp -r $base/gcov/* /benchmark-scripts/mysql-src

    cd /benchmark-scripts/mysql-src
    sudo gcovr -p 2> $base/gcovr/err 1> $base/gcovr/out

    #gprof ???
    sudo umount --recursive $mnt
  done
fi
