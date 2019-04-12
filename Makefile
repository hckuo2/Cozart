mnt=mnt/
disk=qemu-disk.ext4
kernelversion=rpi-4.14.y
linuxdir=linux-$(kernelversion)
whoami=hckuo
.PHONY: rm-disk clean build-db
nothing:

remove-makefile-escaped-newlines:
	bash remove-makefile-escaped-newlines.sh

build-db:
	./directive-extracter.sh $(linuxdir) > directives.db
	find $(linuxdir) -name Makefile \
		| xargs awk -f extract-makefile.awk >filename.db

setup-linux:
	wget --no-clobber https://github.com/raspberrypi/linux/archive/$(kernelversion).zip
	unzip $(kernelversion).zip
	make remove-makefile-escaped-newlines

setup-cc-toolchains:
	sudo apt install -y libc6-armel-cross libc6-dev-armel-cross binutils-arm-linux-gnueabi libncurses5-dev

setup-qemu:
	-git clone --depth 1 -b stable-2.12 https://github.com/qemu/qemu.git
	cd qemu && \
		git submodule init && git submodule update --recursive && \
		git apply -v ../patches/cpu-exec.patch; \
		git apply -v ../patches/trace-events.patch; \
		./configure --enable-trace-backend=log --target-list=aarch64-softmmu --disable-werror && \
		make -j`nproc`

build-raspberry-vanilla:
	mkdir -p compiled-kernels/raspberry/vanilla/boot/overlays
	cd $(linuxdir) && \
		export ARCH=arm64 && \
		export CROSS_COMPILE=aarch64-linux-gnu- && \
		INSTALL_DIR=../compiled-kernels/raspberry/vanilla && \
		make bcmrpi3_defconfig && \
		sed -i 's/# CONFIG_DEBUG_INFO is not set/CONFIG_DEBUG_INFO=y/' .config && \
	 	make -j`nproc` \
		LOCALVERSION=-raspberry-vanilla && \
		INSTALL_PATH=$$INSTALL_DIR make install && \
		INSTALL_MOD_PATH=$$INSTALL_DIR make modules_install && \
		cp arch/arm/boot/dts/*.dtb $$INSTALL_DIR/boot/ && \
		cp arch/arm/boot/dts/overlays/*.dtb* $$INSTALL_DIR/boot/overlays/ && \
		cp arch/arm/boot/dts/overlays/README $$INSTALL_DIR/boot/overlays/ && \
		cp arch/arm/boot/zImage $$INSTALL_DIR/boot/kernel7.img


$(mnt):
	mkdir -p $(mnt)

clean:
	rm -rf ./bin/* *.tmp *.benchresult

rm-disk:
	rm $(disk)

install-kernel-modules:
	-sudo umount --recursive $(mnt)
	sudo mount -o loop $(disk) $(mnt)
	cd $(linuxdir) && \
		sudo ARCH=arm64 INSTALL_MOD_PATH=../$(mnt) make modules_install
	-sudo umount --recursive ./$(mnt)

debootstrap: $(disk) $(mnt)
	-sudo umount --recursive $(mnt)
	sudo mkfs.ext4 $(disk)

install-mark:
	-sudo umount --recursive $(mnt)
	sudo mount -o loop $(disk) $(mnt)
	gcc -o mark mark.c
	sudo mv mark $(mnt)
	sudo umount --recursive $(mnt)

install-hello:
	-sudo umount --recursive $(mnt)
	sudo mount -o loop $(disk) $(mnt)
	gcc -o hello hello.c
	sudo mv hello $(mnt)
	sudo umount --recursive $(mnt)

install-docker:
	wget https://download.docker.com/linux/debian/dists/stretch/pool/stable/amd64/docker-ce_18.06.2~ce~3-0~debian_amd64.deb;
	-sudo umount --recursive $(mnt)
	sudo mount -o loop $(disk) $(mnt)
	sudo mv docker-ce_18.06.2~ce~3-0~debian_amd64.deb ./mnt
	-sudo umount --recursive $(mnt)

get-modules:
	-sudo umount --recursive $(mnt)
	sudo mount -o loop $(disk) $(mnt)
	-sudo mv $(mnt)/modules modules.tmp
	sudo chown $(whoami):$(whoami) modules.tmp
	sudo umount --recursive $(mnt)

sync-scripts:
	./copy2disks.sh benchmark-scripts

toggle-benchmark-mode:
	sed -i 's/reqcnt=.*/reqcnt=100000/' benchmark-scripts/*.sh
	sed -i 's/reqcnt=.*/reqcnt=10000/' benchmark-scripts/*memcached.sh
	sed -i 's/itr=.*/itr=20/' benchmark-scripts/*.sh
	make sync-scripts

toggle-trace-mode:
	sed -i 's/reqcnt=.*/reqcnt=5000/' benchmark-scripts/*.sh
	sed -i 's/reqcnt=.*/reqcnt=500/' benchmark-scripts/*memcached.sh
	sed -i 's/reqcnt=.*/reqcnt=500/' benchmark-scripts/*cassandra.sh
	sed -i 's/itr=.*/itr=1/' benchmark-scripts/*.sh
	make sync-scripts

install-unixbench:
	-git clone https://github.com/kdlucas/byte-unixbench.git
	./copy2disks.sh byte-unixbench
	rm -rf byte-unixbench


