#/usr/bin/env python3
import sys

base = int(sys.argv[1], 16)
for line in sys.stdin:
    print(hex(int(line, 16)-base))

