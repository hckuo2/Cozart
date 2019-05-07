#!/usr/bin/env python3
import sys

def is_constant(str):
    return str != "m" and str != "y" and str != "n"

if __name__ == '__main__':
    # parse the vanilla config file
    vanilla = {}
    with open(sys.argv[1]) as f:
        for line in f:
            line = line.strip()
            if len(line) == 0:
                continue
            if line[0] == "#":
                if "is not set" in line:
                    cols = line.split()
                    vanilla[cols[1]] = "is not set"
                    print(line)
            else:
                cols = line.split("=")
                vanilla[cols[0]] = cols[1]
                if is_constant(cols[1]):
                    print(line)

    with open(sys.argv[2]) as f:
        for line in f:
            if line[0] == "#":
                continue
        conf = line.strip()
        if conf in vanilla:
            print(conf + "=" + vanilla[conf])
