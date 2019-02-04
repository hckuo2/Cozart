#!/bin/bash

go run query-directive.go | grep -E -o "CONFIG_(\w+)" | sort | uniq
