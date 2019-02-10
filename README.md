# Cozart (Configuration + Mozart)
Silm your kernel with better configuration.

## Setup
`make setup-qemu setup-linux debootstrap build-directives-db build-makefile-db`

`make ubuntu-bzImage`

## Run
`./trace-kernel.sh ubuntu` and do things... Ctrl-x to leave qemu.

It will generate a .config in the kernel directory.
