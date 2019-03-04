ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
kernelversion:=18.11
kerneldir:=$(ROOT_DIR)/src/kernel/fiasco

nothing:

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

build-allyes:
	cd src/kernel/fiasco && \
		rm -rf mybuild && \
		make BUILDDIR=mybuild && \
		make allyesconfig && \
		make -j`nproc`

build-runtime:
	cd src/l4 && \
		rm -rf mybuild && \
		make B=mybuild && \
		make -j`nproc` O=mybuild

