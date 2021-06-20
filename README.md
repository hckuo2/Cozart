# Cozart: Mozart for OS Kernel Configuration

[SIGMETRICS'20] Set the Configuration for the Heart of the OS:
On the Practicality of Operating System Kernel Debloating [[pdf]](https://hckuo.github.io/pdfs/cozart.pdf)

## What's the problem?


We find that less than 20% of an Ubuntu kernel is used for running a HTTP
server. Lots of modules(features) are not used and they can be disabled by
configurations. However, Linux has so many options and the number of options
is still growing... Since it is not practical to spend hours to reconfigure
the kernel every time we deploying an application, we need an automatic tool
that specialize the bloated kernels.

| Version  | # Options  |
|:--------:| -------------:|
| 3.0      |    __11,328__    |
| 4.0      |    __14,406__    |
| 5.0      |    __16,527__    |

## What can Cozart do?

Cozart generates *APPLETS* for each applications and *BASELETS* for each deployment
environment. Cozart then can compose one BASELET and one or multiple APPLETS to
generate the final configuration.


## How can I use Cozart?

### Setup
```
git@github.com:hckuo/Cozart.git
cd Cozart/docker;
docker build -f Dockerfile -t cozart-env:latest .
```

### Run
```
cd Cozart # project root directory
docker run -v $PWD:/Cozart --privileged -it --name cozart cozart-env /bin/bash # start up the docker container 
```
### In docker container
```
mknod /dev/loop0 b 7 0 # create loop device if not exist
cd Cozart/
source constant.sh
make $mnt; make $disk # set-up mnt folder and qemu disk
make setup-qemu # patch the qemu to enable PC tracing
make setup-linux # clone the linux source
make build-db # parse the linux source to extract the relationships between the configuration options and code
make debootstrap # create a rootfs for the VM
make build-base # build the vanilla kernel as the baseline
./job.sh trace boot # generate a baselet
./job.sh trace apache # generate an applet for apache (the executed workload in the VM is in /benchmark-scripts/apache.sh)
./job.sh compose apache # compose apache applet with boot baselet
./job.sh benchmark apache # benchmark the debloated kernel
```

## Questions

If you have any questions, please let me know at hckuo2@illinois.edu.
Any feedbacks (good or bad) are also welcomed.

[Test coverage data in the paper](https://bit.ly/2uMFr3e)
