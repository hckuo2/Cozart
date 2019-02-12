#!/bin/sh

for i in `seq 10`; do
    perf_4.9 bench sched all;
done

