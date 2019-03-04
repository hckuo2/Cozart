# Cozart (Configuration + Mozart)
Silm your kernel with better configuration.

## Setup
`make setup-qemu setup-linux debootstrap build-db`

`make build-ubuntu-vanilla`

## Run
`./trace-kernel.sh ubuntu /bin/bash` and do things... Ctrl-x to leave qemu.

It generates a `.config` in the kernel directory.

