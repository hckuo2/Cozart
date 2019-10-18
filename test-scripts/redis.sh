source constant.sh

control=${1:-0}
epoch=${2:-1}

target_src="/benchmark-scripts/redis-src/src"
stat_folder=$workdir/gcov-gprof-stats/redis
vanilla="/vanilla"
debloated="/debloated"
disk=qemu-disk.ext4.redis

# vanilla kernel
# run redis-make-test.sh, copy all generated fils
#   (*.c, *.o, *.h, *.gc*) to $stat_folder$vanilla"/testsuite/gcov"
#   gmon.out.* to $stat_folder$vanilla"/testsuite/gprof"
if (($control == "1" || $control == "0"))
then
  for i in `seq $epoch`; do
    cd $workdir
    ./boot-kernel.sh kernelbuild/linux-cosmic/cosmic/base/vmlinuz-4.18.20-linux-cosmic-cosmic-base /benchmark-scripts/redis-make-test.sh $disk

    rm -r $stat_folder$vanilla/testsuite/epoch$i
    base=$stat_folder$vanilla/testsuite/epoch$i
    mkdir $base
    mkdir $base/gcov $base/gprof $base/gcovr 
    sleep 1;

    sudo umount --recursive $mnt
    sudo mount -o loop $disk $mnt
    
    cp $mnt$target_src/*.[coh] $base/gcov
    cp $mnt$target_src/*log $base/gcov
    cp $mnt$target_src/../*log $base/gcov
    cp $mnt$target_src/*.gcda $base/gcov
    cp $mnt$target_src/*.gcov $base/gcov
    cp $mnt$target_src/*.gcno $base/gcov
    cp $mnt$target_src/../gmon.out $base/gprof
    cp $mnt$target_src/redis-server $base/gprof
    sync
    cd $base/gcov
    rm redis-cli*
    rm redis-benchmark*
    gcovr -p > $base/gcovr/out
    cd $base/gprof
    gprof redis-server > out
    sudo umount --recursive $mnt
  done
fi
# runtest-cluster
if (($control == "11" || $control == "0"))
then
  for i in `seq $epoch`; do
    cd $workdir
    ./boot-kernel.sh kernelbuild/linux-cosmic/cosmic/base/vmlinuz-4.18.20-linux-cosmic-cosmic-base /benchmark-scripts/redis-cluster.sh $disk

    rm -r $stat_folder$vanilla/runtest-cluster/epoch$i
    mkdir $stat_folder$vanilla/runtest-cluster
    base=$stat_folder$vanilla/runtest-cluster/epoch$i
    mkdir $base
    mkdir $base/gcov $base/gprof $base/gcovr 
    sleep 1;

    sudo umount --recursive $mnt
    sudo mount -o loop $disk $mnt
    
    cp $mnt$target_src/*.[coh] $base/gcov
    cp $mnt$target_src/*log $base/gcov
    cp $mnt$target_src/../*log $base/gcov
    cp $mnt$target_src/*.gcda $base/gcov
    cp $mnt$target_src/*.gcov $base/gcov
    cp $mnt$target_src/*.gcno $base/gcov
    cp $mnt$target_src/../gmon.out $base/gprof
    cp $mnt$target_src/redis-server $base/gprof
    sync
    cd $base/gcov
    rm redis-cli*
    rm redis-benchmark*
    gcovr -p > $base/gcovr/out
    cd $base/gprof
    gprof redis-server > out
    sudo umount --recursive $mnt
  done
fi
# runtest-sentinel
if (($control == "12" || $control == "0"))
then
  for i in `seq $epoch`; do
    cd $workdir
    ./boot-kernel.sh kernelbuild/linux-cosmic/cosmic/base/vmlinuz-4.18.20-linux-cosmic-cosmic-base /benchmark-scripts/redis-sent.sh $disk

    rm -r $stat_folder$vanilla/runtest-sentinel/epoch$i
    mkdir $stat_folder$vanilla/runtest-sentinel
    base=$stat_folder$vanilla/runtest-sentinel/epoch$i
    mkdir $base
    mkdir $base/gcov $base/gprof $base/gcovr 
    sleep 1;

    sudo umount --recursive $mnt
    sudo mount -o loop $disk $mnt
    
    cp $mnt$target_src/*.[coh] $base/gcov
    cp $mnt$target_src/*log $base/gcov
    cp $mnt$target_src/../*log $base/gcov
    cp $mnt$target_src/*.gcda $base/gcov
    cp $mnt$target_src/*.gcov $base/gcov
    cp $mnt$target_src/*.gcno $base/gcov
    cp $mnt$target_src/../gmon.out $base/gprof
    cp $mnt$target_src/redis-server $base/gprof
    sync
    cd $base/gcov
    rm redis-cli*
    rm redis-benchmark*
    gcovr -p > $base/gcovr/out
    cd $base/gprof
    gprof redis-server > out
    sudo umount --recursive $mnt
  done
fi
# runtest-aggregate
if (($control == "10" || $control == "0"))
then
  for i in `seq $epoch`; do
    cd $workdir
    ./boot-kernel.sh kernelbuild/linux-cosmic/cosmic/base/vmlinuz-4.18.20-linux-cosmic-cosmic-base /benchmark-scripts/redis-aggr.sh $disk

    rm -r $stat_folder$vanilla/runtest-aggr/epoch$i
    mkdir $stat_folder$vanilla/runtest-aggr
    base=$stat_folder$vanilla/runtest-aggr/epoch$i
    mkdir $base
    mkdir $base/gcov $base/gprof $base/gcovr 
    sleep 1;

    sudo umount --recursive $mnt
    sudo mount -o loop $disk $mnt
    
    cp $mnt$target_src/*.[coh] $base/gcov
    cp $mnt$target_src/*log $base/gcov
    cp $mnt$target_src/../*log $base/gcov
    cp $mnt$target_src/*.gcda $base/gcov
    cp $mnt$target_src/*.gcov $base/gcov
    cp $mnt$target_src/*.gcno $base/gcov
    cp $mnt$target_src/../gmon.out $base/gprof
    cp $mnt$target_src/redis-server $base/gprof
    sync
    cd $base/gcov
    rm redis-cli*
    rm redis-benchmark*
    gcovr -p > $base/gcovr/out
    cd $base/gprof
    gprof redis-server > out
    sudo umount --recursive $mnt
  done
fi
# run redis-bench.sh, copy all generated fils
#   (*.c, *.o, *.h, *.gc*) to $stat_folder$vanilla"/bench/gcov"
#   gmon.out.* to $stat_folder$vanilla"/bench/gprof"

if (($control == "2" || $control == "0"))
then
  for i in `seq $epoch`; do
    cd $workdir
    ./boot-kernel.sh kernelbuild/linux-cosmic/cosmic/base/vmlinuz-4.18.20-linux-cosmic-cosmic-base /benchmark-scripts/redis-bench.sh $disk

    rm -r $stat_folder$vanilla/bench/epoch$i
    base=$stat_folder$vanilla/bench/epoch$i
    mkdir $base
    mkdir $base/gcov $base/gprof $base/gcovr 
    sudo umount --recursive $mnt
    sudo mount -o loop $disk $mnt

    cp $mnt$target_src/*.[coh] $base/gcov
    cp $mnt$target_src/*log $base/gcov
    cp $mnt$target_src/../*log $base/gcov
    cp $mnt$target_src/*.gcda $base/gcov
    cp $mnt$target_src/*.gcov $base/gcov
    cp $mnt$target_src/*.gcno $base/gcov
    cp $mnt$target_src/gmon.out $base/gprof
    cp $mnt$target_src/redis-server $base/gprof
    sync
    cd $base/gcov
    rm redis-cli*
    rm redis-benchmark*
    gcovr -p > $base/gcovr/out
    cd $base/gprof
    gprof redis-server > out
    sudo umount --recursive $mnt
  done
fi
# debloated kernel
# run memcached-make-test.sh, copy all generated fils
#   (*.c, *.o, *.h, *.gc*) to $stat_folder$debloated"/testsuite/gcov"
#   gmon.out.* to $stat_folder$debloated"/testsuite/gprof"

if (($control == "3" || $control == "0"))
then
  for i in `seq $epoch`; do
    cd $workdir
    ./boot-kernel.sh kernelbuild/linux-cosmic/cosmic/redis-test/vmlinuz-4.18.20-linux-cosmic-cosmic-redis-test  /benchmark-scripts/redis-make-test.sh $disk

    rm -r $stat_folder$debloated/testsuite/epoch$i
    base=$stat_folder$debloated/testsuite/epoch$i
    mkdir $base
    mkdir $base/gcov $base/gprof $base/gcovr 
    sudo umount --recursive $mnt
    sudo mount -o loop $disk $mnt

    cp $mnt$target_src/*.[coh] $base/gcov
    cp $mnt$target_src/*log $base/gcov
    cp $mnt$target_src/../*log $base/gcov
    cp $mnt$target_src/*.gcda $base/gcov
    cp $mnt$target_src/*.gcov $base/gcov
    cp $mnt$target_src/*.gcno $base/gcov
    cp $mnt$target_src/../gmon.out $base/gprof
    cp $mnt$target_src/redis-server $base/gprof
    sync
    cd $base/gcov
    rm redis-cli*
    rm redis-benchmark*
    gcovr -p > $base/gcovr/out
    cd $base/gprof
    gprof redis-server > out
    sudo umount --recursive $mnt
  done
fi
# runtest-cluster
if (($control == "31" || $control == "0"))
then
  for i in `seq $epoch`; do
    cd $workdir
    ./boot-kernel.sh kernelbuild/linux-cosmic/cosmic/redis/vmlinuz-4.18.20-linux-cosmic-cosmic-redis /benchmark-scripts/redis-cluster.sh

    rm -r $stat_folder$debloated/runtest-cluster/epoch$i
    mkdir $stat_folder$debloated/runtest-cluster
    base=$stat_folder$debloated/runtest-cluster/epoch$i
    mkdir $base
    mkdir $base/gcov $base/gprof $base/gcovr 
    sleep 1;

    sudo umount --recursive $mnt
    sudo mount -o loop $disk $mnt
    
    cp $mnt$target_src/*.[coh] $base/gcov
    cp $mnt$target_src/*log $base/gcov
    cp $mnt$target_src/../*log $base/gcov
    cp $mnt$target_src/*.gcda $base/gcov
    cp $mnt$target_src/*.gcov $base/gcov
    cp $mnt$target_src/*.gcno $base/gcov
    cp $mnt$target_src/../gmon.out $base/gprof
    cp $mnt$target_src/redis-server $base/gprof
    sync
    cd $base/gcov
    rm redis-cli*
    rm redis-benchmark*
    gcovr -p > $base/gcovr/out
    cd $base/gprof
    gprof redis-server > out
    sudo umount --recursive $mnt
  done
fi
# runtest-sentinel
if (($control == "32" || $control == "0"))
then
  for i in `seq $epoch`; do
    cd $workdir
    ./boot-kernel.sh kernelbuild/linux-cosmic/cosmic/redis/vmlinuz-4.18.20-linux-cosmic-cosmic-redis /benchmark-scripts/redis-sen.sh

    rm -r $stat_folder$debloated/runtest-sentinel/epoch$i
    mkdir $stat_folder$debloated/runtest-sentinel
    base=$stat_folder$debloated/runtest-sentinel/epoch$i
    mkdir $base
    mkdir $base/gcov $base/gprof $base/gcovr 
    sleep 1;

    sudo umount --recursive $mnt
    sudo mount -o loop $disk $mnt
    
    cp $mnt$target_src/*.[coh] $base/gcov
    cp $mnt$target_src/*log $base/gcov
    cp $mnt$target_src/../*log $base/gcov
    cp $mnt$target_src/*.gcda $base/gcov
    cp $mnt$target_src/*.gcov $base/gcov
    cp $mnt$target_src/*.gcno $base/gcov
    cp $mnt$target_src/../gmon.out $base/gprof
    cp $mnt$target_src/redis-server $base/gprof
    sync
    cd $base/gcov
    rm redis-cli*
    rm redis-benchmark*
    gcovr -p > $base/gcovr/out
    cd $base/gprof
    gprof redis-server > out
    sudo umount --recursive $mnt
  done
fi
# run memcached-debug-test.sh, copy all generated fils
#   (*.c, *.o, *.h, *.gc*) to $stat_folder$debloated"/bench/gcov"
#   gmon.out.* to $stat_folder$vanilla"/bench/gprof"

# runtest-aggregate
if (($control == "30" || $control == "0"))
then
  for i in `seq $epoch`; do
    cd $workdir
    ./boot-kernel.sh kernelbuild/linux-cosmic/cosmic/redis-test/vmlinuz-4.18.20-linux-cosmic-cosmic-redis-test /benchmark-scripts/redis-aggr.sh $disk

    rm -r $stat_folder$debloated/runtest-aggr/epoch$i
    mkdir $stat_folder$debloated/runtest-aggr
    base=$stat_folder$debloated/runtest-aggr/epoch$i
    mkdir $base
    mkdir $base/gcov $base/gprof $base/gcovr 
    sleep 1;

    sudo umount --recursive $mnt
    sudo mount -o loop $disk $mnt
    
    cp $mnt$target_src/*.[coh] $base/gcov
    cp $mnt$target_src/*log $base/gcov
    cp $mnt$target_src/../*log $base/gcov
    cp $mnt$target_src/*.gcda $base/gcov
    cp $mnt$target_src/*.gcov $base/gcov
    cp $mnt$target_src/*.gcno $base/gcov
    cp $mnt$target_src/../gmon.out $base/gprof
    cp $mnt$target_src/redis-server $base/gprof
    sync
    cd $base/gcov
    rm redis-cli*
    rm redis-benchmark*
    gcovr -p > $base/gcovr/out
    cd $base/gprof
    gprof redis-server > out
    sudo umount --recursive $mnt
  done
fi

# debloated benchmark
if (($control == "4" || $control == "0"))
then
	
  for i in `seq $epoch`; do
    cd $workdir
    ./boot-kernel.sh kernelbuild/linux-cosmic/cosmic/redis/vmlinuz-4.18.20-linux-cosmic-cosmic-redis  /benchmark-scripts/redis-bench.sh $disk

    rm -r $stat_folder$debloated/bench/epoch$i
    base=$stat_folder$debloated/bench/epoch$i
    mkdir $base
    mkdir $base/gcov $base/gprof $base/gcovr 
    sudo umount --recursive $mnt
    sudo mount -o loop $disk $mnt

    cp $mnt$target_src/*.[coh] $base/gcov
    cp $mnt$target_src/*log $base/gcov
    cp $mnt$target_src/../*log $base/gcov
    cp $mnt$target_src/*.gcda $base/gcov
    cp $mnt$target_src/*.gcov $base/gcov
    cp $mnt$target_src/*.gcno $base/gcov
    cp $mnt$target_src/gmon.out $base/gprof
    cp $mnt$target_src/redis-server $base/gprof
    sync
    cd $base/gcov
    rm redis-cli*
    rm redis-benchmark*
    gcovr -p > $base/gcovr/out 
    cd $base/gprof
    gprof redis-server > out
    sudo umount --recursive $mnt
  done
fi

