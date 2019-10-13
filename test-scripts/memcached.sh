source constant.sh

control=${1:-0}
epoch=${2:-1}

target_src="/benchmark-scripts/memcached-src"
stat_folder=$workdir/gcov-gprof-stats/memcached
vanilla="/vanilla"
debloated="/debloated"

# vanilla kernel
# run memcached-make-test.sh, copy all generated fils
#   (*.c, *.o, *.h, *.gc*) to $stat_folder$vanilla"/testsuite/gcov"
#   gmon.out.* to $stat_folder$vanilla"/testsuite/gprof"
if (($control == "1" || $control == "0"))
then
  for i in `seq $epoch`; do
    cd $workdir
    ./boot-kernel.sh kernelbuild/linux-cosmic/cosmic/base/vmlinuz-4.18.20-linux-cosmic-cosmic-base /benchmark-scripts/memcached-make-test.sh

    rm -r $stat_folder$vanilla/testsuite/epoch$i
    base=$stat_folder$vanilla/testsuite/epoch$i
    mkdir $base
    mkdir $base/gcov $base/gprof $base/gcovr 

    sudo umount --recursive $mnt
    sudo mount -o loop $disk $mnt

    cp $mnt$target_src/*.[coh] $base/gcov
    cp $mnt$target_src/*log $base/gcov
    cp $mnt$target_src/*.gc[don][avo] $base/gcov
    cp $mnt$target_src/gmon.out $base/gprof
    cp $mnt$target_src/memcached-debug $base/gprof
    sync
    cd $base/gcov
    gcovr -p > $base/gcovr/out
    cd $base/gprof
    gprof memcached-debug > out
    sudo umount --recursive $mnt
  done
fi
# run memcached-debug-test.sh, copy all generated fils
#   (*.c, *.o, *.h, *.gc*) to $stat_folder$vanilla"/bench/gcov"
#   gmon.out.* to $stat_folder$vanilla"/bench/gprof"

if (($control == "2" || $control == "0"))
then
  for i in `seq $epoch`; do
    cd $workdir
    ./boot-kernel.sh kernelbuild/linux-cosmic/cosmic/base/vmlinuz-4.18.20-linux-cosmic-cosmic-base /benchmark-scripts/memcached-debug-memtier.sh

    rm -r $stat_folder$vanilla/bench/epoch$i
    base=$stat_folder$vanilla/bench/epoch$i
    mkdir $base
    mkdir $base/gcov $base/gprof $base/gcovr 
    sudo umount --recursive $mnt
    sudo mount -o loop $disk $mnt

    cp $mnt$target_src/*.[coh] $base/gcov
    cp $mnt$target_src/*log $base/gcov
    cp $mnt$target_src/*.gc[don][avo] $base/gcov
    cp $mnt$target_src/gmon.out $base/gprof
    cp $mnt$target_src/memcached-debug $base/gprof
    sync
    cd $base/gcov
    for f in *.c; do
      cp $f memcached_debug-$f
    done
    for f in *.gcno; do
      cp $f memcached_debug-$f
    done
    gcovr -p > $base/gcovr/out
    cd $base/gprof
    gprof memcached-debug > out
    sudo umount --recursive $mnt
  done
fi
# debloated kernel
# run memcached-make-test.sh, copy all generated fils
#   (*.c, *.o, *.h, *.gc*) to $stat_folder$debloated"/testsuite/gcov"
#   gmon.out.* to $stat_folder$vanilla"/testsuite/gprof"

if (($control == "3" || $control == "0"))
then
  for i in `seq $epoch`; do
    cd $workdir
    ./boot-kernel.sh kernelbuild/linux-cosmic/cosmic/memcached/vmlinuz-4.18.20-linux-cosmic-cosmic-memcached  /benchmark-scripts/memcached-make-test.sh

    rm -r $stat_folder$debloated/testsuite/epoch$i
    base=$stat_folder$debloated/testsuite/epoch$i
    mkdir $base
    mkdir $base/gcov $base/gprof $base/gcovr 
    sudo umount --recursive $mnt
    sudo mount -o loop $disk $mnt

    cp $mnt$target_src/*.[coh] $base/gcov
    cp $mnt$target_src/*log $base/gcov
    cp $mnt$target_src/*.gc[don][avo] $base/gcov
    cp $mnt$target_src/gmon.out $base/gprof
    cp $mnt$target_src/memcached-debug $base/gprof
    sync
    cd $base/gcov
    gcovr -p > $base/gcovr/out
    cd $base/gprof
    gprof memcached-debug > out
    sudo umount --recursive $mnt
  done
fi
# run memcached-debug-test.sh, copy all generated fils
#   (*.c, *.o, *.h, *.gc*) to $stat_folder$debloated"/bench/gcov"
#   gmon.out.* to $stat_folder$vanilla"/bench/gprof"

if (($control == "4" || $control == "0"))
then
  	
  for i in `seq $epoch`; do
    cd $workdir
    ./boot-kernel.sh kernelbuild/linux-cosmic/cosmic/memcached/vmlinuz-4.18.20-linux-cosmic-cosmic-memcached  /benchmark-scripts/memcached-debug-memtier.sh

    rm -r $stat_folder$debloated/bench/epoch$i
    base=$stat_folder$debloated/bench/epoch$i
    mkdir $base
    mkdir $base/gcov $base/gprof $base/gcovr 
    sudo umount --recursive $mnt
    sudo mount -o loop $disk $mnt

    cp $mnt$target_src/*.[coh] $base/gcov
    cp $mnt$target_src/*log $base/gcov
    cp $mnt$target_src/*.gc[don][avo] $base/gcov
    cp $mnt$target_src/gmon.out $base/gprof
    cp $mnt$target_src/memcached-debug $base/gprof
    sync
    cd $base/gcov
    for f in *.c; do
      cp $f memcached_debug-$f
    done
    for f in *.gcno; do
      cp $f memcached_debug-$f
    done
    gcovr -p > $base/gcovr/out 
    cd $base/gprof
    gprof memcached-debug > out
    sudo umount --recursive $mnt
  done
fi
