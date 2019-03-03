#!/bin/bash
linuxdir="linux-4.18.0"

rebase-linuxdir() {
	sed -r "s/.+$linuxdir/$linuxdir/"
}
