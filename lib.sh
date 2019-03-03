#!/bin/bash

rebase-linuxdir() {
	sed -r 's/.+linux-([0-9])+\.([0-9])+\.([0-9])+\///'
}
