# SSSS Cozart demo handout

## Setup

We clone Cozart source files from the repository and checkout the branch `s4_demo`. We will next build a docker image that will be used for Cozart to work.

```bash
git clone git@github.com:hckuo/Cozart.git ~
cd ~/Cozart/docker
git checkout s4_demo
sudo docker build -f Dockerfile -t cozart-env:latest .
```



## Preparation

We start a container with the image we just built in the previous step. **Note that you have to change directory to the Cozart root directory**. 

```bash
cd ~/Cozart
sudo docker run -v $PWD:/Cozart --privileged -it --name cozart cozart-env /bin/bash
```

**Starting from this point, you should already see a bash prompt in the container and the following commands should be executed in the container.**

```bash
cd /Cozart
source constant.sh
make $mnt; make $disk # set-up mnt folder and qemu disk
make setup-qemu # patch the qemu to enable PC tracing
make setup-linux # clone the linux source
make build-db # parse the linux source to extract the relationships between the configuration options and code
make debootstrap # create a rootfs for the VM
make build-base # build the vanilla kernel as the baseline
./job.sh trace boot # generate a baselet
./job.sh trace nginx # generate an applet for apache (the executed workload in the VM is in /benchmark-scripts/apache.sh)
./job.sh compose nginx # compose apache applet with boot baselet
```

The above lists all commands necessary to debloat a kernel for Nginx.

`constant.sh` contains constant variables such as the kernel and disk path. We then need to patch QEMU in order to enable tracing by `make setup-qemu`. We download the Linux source files and build our vanilla kernel by `make setup-linux`.



 `make build-db` parses the Linux source files to extract the relationships between source files and kernel configurations. It generates two files: `directives.db` and `filename.db`.

`directives.db` contains the mapping of C directives and source code lines as the following:

```
linux-cosmic/arch/x86/boot/compressed/head_32.S:264:#ifdef CONFIG_EFI_STUB
linux-cosmic/arch/x86/boot/compressed/head_32.S:271:#endif
linux-cosmic/arch/x86/boot/compressed/head_64.S:101:#ifdef CONFIG_RELOCATABLE
linux-cosmic/arch/x86/boot/compressed/head_64.S:110:#endif
```

`filename.db` contains the mapping of Makefiles and configuration as the following:

```
linux-cosmic/drivers/iio/pressure/zpa2326.c CONFIG_ZPA2326
linux-cosmic/drivers/zorro/names.c CONFIG_ZORRO_NAMES
linux-cosmic/drivers/net/ethernet/8390/zorro8390.c CONFIG_ZORRO8390
linux-cosmic/drivers/zorro/zorro.c CONFIG_ZORRO
linux-cosmic/drivers/zorro/zorro-sysfs.c CONFIG_ZORR
```

 `make debootstrap` utilizes the system command, `deboostrap` to create disk image for tracing and it prepares necessary files such as the application and its workload. In this demo, we will be debloating a kernel for Nginx so the workload looks like the following.

```bash
...
service nginx start
sleep 3;
for i in `seq $itr`; do
    ab -n $reqcnt -c 100 127.0.0.1:80/index.html;
done
service nginx stop
...
```

 `make build-base` builds a vanilla kernel by Ubuntu cosmic config and store it at `kernelbuild/`. (This can take a while.)
 This vanilla kernel will be used as the baseline for debloating.
 
 ## Tracing
 We finally prepare all necessary files for debloating including QEMU, kernel source, compiled kernel, application and its workload. We are about to trace our workload to debloat the kernel. Cozart divide the configuration into `baselet` and `applet`.
 A `baselet` is the configuration to boot and a `applet` is the configuration option for the application.
 
 We generate the baselet by running `./job.sh trace boot`. This will start up a VM and trace it until it successfully boots. A baselet, `config-db/linux-cosmic/cosmic/boot.config`, will be generated.
 
 We generate the applet for Nginx by running `./job.sh trace nginx`. This will start up a VM and trace it until the designated Nginx workload is finished. An applet, `config-db/linux-cosmic/cosmic/nginx.config`, will be generated.
 
