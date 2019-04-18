#!/usr/bin/env python3
import sys


def parse_line(line):
    idx = line.index("=")
    return line[:idx], line[idx + 1:]


if __name__ == '__main__':
    base = {}
    for line in open(sys.argv[1]):
        line = line.strip()
        if len(line) == 0:
            continue
        if line[0] == '#':
            continue
        item, value = parse_line(line)
        base[item] = value

    for line in open(sys.argv[2]):
        line = line.strip()
        if len(line) == 0:
            continue
        if line[0] == '#':
            continue
        item, value = parse_line(line)
        if item not in base:
            print(line + " is not in " + sys.argv[1])
