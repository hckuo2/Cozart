#/usr/bin/env python3
import sys

base = int(sys.argv[1], 16)
for line in sys.stdin:
    try:
        print(hex(int(line, 16)-base))
    except ValueError:
        pass

