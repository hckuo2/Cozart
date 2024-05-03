.PHONY: rm-disk clean build-db
echo-env:
	@echo "linux=$(linux)"
	@echo "base=$(base)"

remove-makefile-escaped-newlines:
	find $(linux) -name Makefile | \
		xargs sed -i ':a;N;$!ba;s/\\\n/ /g'

build-db:
	./directive-extracter.sh $(linux) >directives.db
	find $(linux) -name Makefile \
		| xargs awk -f extract-makefile.awk | sort -u -t' ' -k2,2 -k1,1 -r | \
		awk -f postproc-fndb.awk | sed 's/^\.\///' >filename.db

setup-linux:
	git clone --depth=1 https://git.launchpad.net/~ubuntu-kernel/ubuntu/+source/linux/+git/cosmic $(linux)
	cd $(linux) && \
		git apply -v ../patches/watchdog.patch
	make remove-makefile-escaped-newlines
	cp $(linux)/debian/scripts/retpoline-extract-one $(linux)/scripts/ubuntu-retpoline-extract-one

setup-qemu:
	-git clone --depth 1 -b stable-2.12 https://github.com/qemu/qemu.git
	cd qemu && \
		git submodule init && git submodule update --recursive && \
		git apply -v ../patches/cpu-exec.patch && \
		git apply -v ../patches/trace-events.patch && \
		./configure --disable-werror --enable-trace-backend=log --target-list=x86_64-softmmu && \
		make -j`nproc`

build-base:
	mkdir -p $(kernelbuild)/$(linux)/$(base)/base
	cd $(linux) && \
		cp ../config-db/$(linux)/$(base)/base.config .config && \
		make olddefconfig && \
		make -j`nproc` LOCALVERSION=-$(linux)-$(base)-base && \
		cp vmlinux $(kernelbuild)/$(linux)/$(base)/base/vmlinux && \
		INSTALL_PATH=$(kernelbuild)/$(linux)/$(base)/base make install && \
		INSTALL_MOD_PATH=$(kernelbuild)/$(linux)/$(base)/base make modules_install
	make install-kernel-modules

$(mnt):
	mkdir -p $(mnt)

$(disk):
	dd if=/dev/zero of=$(disk) bs=1 count=0 seek=20G

clean:
	rm -rf *.tmp

rm-disk:
	rm $(disk)

install-kernel-modules:
	-sudo umount --recursive $(mnt)
	sudo mount -o loop $(disk) $(mnt)
	cd $(linux) && \
	sudo INSTALL_MOD_PATH=$(mnt) make modules_install
	-sudo umount --recursive $(mnt)

debootstrap: $(disk) $(mnt)
	-sudo umount --recursive $(mnt)
	sudo mkfs.ext4 -F $(disk)
	sudo mount -o loop $(disk) $(mnt)
	sudo debootstrap --components=main,universe \
		--include="build-essential vim kmod net-tools apache2 apache2-utils haveged cgroupfs-mount iptables libltdl7 redis-server redis-tools nginx sysbench php memcached" \
		--arch=amd64 cosmic $(mnt) http://old-releases.ubuntu.com/ubuntu
	sudo umount --recursive $(mnt)
	make install-docker install-mark sync-scripts

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
	sudo chroot ./mnt /bin/bash -c "dpkg -i docker-ce_18.06.2~ce~3-0~debian_amd64.deb"
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

repair-disk:
	sudo fsck.ext4 -y $(disk)


