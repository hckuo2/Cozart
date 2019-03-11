mnt=mnt/
disk=qemu-disk.ext4
setupfile=bench/native/setup_custom.sh
kernelversion=4.18.0
linuxdir=linux-$(kernelversion)
whoami=hckuo2
.PHONY: rm-disk clean build-db
nothing:

remove-makefile-escaped-newlines:
	find $(linuxdir) -name Makefile | \
		xargs sed -i ':a;N;$!ba;s/\\\n/ /g'

build-db:
	./directive-extracter.sh $(linuxdir) > directives.db
	find $(linuxdir) -name Makefile \
		| xargs awk -f extract-makefile.awk >filename.db

setup-linux:
	wget --no-clobber http://archive.ubuntu.com/ubuntu/pool/main/l/linux/linux_$(kernelversion).orig.tar.gz
	wget --no-clobber http://archive.ubuntu.com/ubuntu/pool/main/l/linux/linux_$(kernelversion)-15.16.diff.gz
	tar xvzf linux_$(kernelversion).orig.tar.gz
	mv linux-4.18 $(linuxdir) cd $(linuxdir) && \
		zcat ../linux_$(kernelversion)-15.16.diff.gz | patch -p1
	make remove-makefile-escaped-newlines

setup-qemu:
	-git clone --depth 1 -b stable-2.12 https://github.com/qemu/qemu.git cd qemu && \ git submodule init && git submodule update --recursive && \
	git apply -v ../patches/cpu-exec.patch && \ git apply -v ../patches/trace-events.patch && \ ./configure --enable-trace-backend=log --target-list=x86_64-softmmu && \ make -j`nproc`

build-ubuntu-vanilla:
	mkdir -p vanilla-modules
	cd $(linuxdir) && \
		make distclean && \
		cp -u ../config-db/ubuntu/vanilla.config .config && \
		make olddefconfig && \
		make -j`nproc` LOCALVERSION=-ubuntu-vanilla && \
		cp vmlinux ../ubuntu.vmlinux && \
		cp arch/x86/boot/bzImage ../ubuntu.bzImage && \
		INSTALL_PATH=../compiled-kernels/ubuntu/vanilla make install && \
		INSTALL_MOD_PATH=../vanilla-modules make modules_install
	make install-kernel-modules

$(mnt):
	mkdir -p $(mnt)

$(disk):
	qemu-img create -f raw $(disk) 30G

clean:
	rm -rf ./tmp/* ./bin/* *.tmp

rm-disk:
	rm $(disk)

install-kernel-modules:
	-sudo umount --recursive $(mnt)
	sudo mount -o loop $(disk) $(mnt)
	cd $(linuxdir) && \
	sudo INSTALL_MOD_PATH=../$(mnt) make modules_install
	-sudo umount --recursive ./$(mnt)

debootstrap: $(disk) $(mnt)
	-sudo umount --recursive $(mnt)
	sudo mkfs.ext4 $(disk)
	sudo mount -o loop $(disk) $(mnt)
	sudo debootstrap --components=main,universe \
		--include="build-essential vim kmod net-tools apache2 apache2-utils haveged cgroupfs-mount linux-tools-generic iptables libltdl7 redis-server redis-tools" \
		--arch=amd64 cosmic $(mnt) http://archive.ubuntu.com/ubuntu
	sudo umount --recursive $(mnt)
	make install-docker install-mark

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
	sed -i 's/reqcnt=.*/reqcnt=10000/' benchmark-scripts/memcached.sh
	sed -i 's/itr=.*/itr=20/' benchmark-scripts/*.sh
	make sync-scripts

toggle-trace-mode:
	sed -i 's/reqcnt=.*/reqcnt=100/' benchmark-scripts/*.sh
	sed -i 's/itr=.*/itr=1/' benchmark-scripts/*.sh
	make sync-scripts

