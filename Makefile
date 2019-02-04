ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
mnt:=$(ROOT_DIR)/mnt/
disk:=$(ROOT_DIR)/qemu-disk.ext4
kernelversion:=18.11
kerneldir:=$(ROOT_DIR)/src/kernel/fiasco
.PHONY: rm-disk clean

trace-processor: bin/trace-parser

build-directives-db:
	$(ROOT_DIR)/directive-extracter.sh $(kerneldir)/src > $(ROOT_DIR)/directives.db

build-makefile-db:
	touch filename.db
	cd $(linuxdir) && \
	find drivers init net -name Makefile | go run ../makefile-extracter.go > ../filename.db

setup-fiasco:
	svn cat https://svn.l4re.org/repos/oc/l4re/trunk/repomgr \
		| perl - init https://svn.l4re.org/repos/oc/l4re fiasco l4re

setup-qemu:
	-git clone --depth 1 -b stable-2.12 https://github.com/qemu/qemu.git
	cd qemu && \
	git submodule init && git submodule update --recursive && \
	git apply -v ../patches/cpu-exec.patch && \
	git apply -v ../patches/trace-events.patch && \
	./configure --enable-trace-backend=log --target-list=x86_64-softmmu && \
	make -j`nproc`

bin/%: %.go
	go build -o $@ $<;

$(mnt):
	mkdir -p $(mnt)

$(disk):
	qemu-img create -f raw $(disk) 10G

clean:
	rm -rf ./tmp/* ./bin/*

rm-disk:
	rm $(disk)

debootstrap: $(disk) $(mnt)
	sudo mkfs.ext4 $(disk)
	sudo mount -o loop $(disk) $(mnt)
	sudo debootstrap --include="vim kmod time net-tools apache2 apache2-utils" --arch=amd64 cosmic $(mnt) http://us.archive.ubuntu.com/ubuntu/
	sudo umount --recursive $(mnt)

