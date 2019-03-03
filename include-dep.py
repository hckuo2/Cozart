#!/usr/bin/env python3
import kconfiglib
import os
import sys
os.environ['srctree'] = "linux-4.18.0"
os.environ['SRCARCH'] = "x86"
os.environ['ARCH'] = "x86"
kconf = kconfiglib.Kconfig()

def is_constant_y(sym):
    return sym.is_constant and (kconfiglib.expr_value(sym) == 2)

def _find_deps(dep, result, level):
    if type(dep) is tuple:
        relation = dep[0]
        if relation == kconfiglib.AND:
            for i in dep[1:]:
                _find_deps(i, result, level + 1)
        if relation == kconfiglib.EQUAL and is_constant_y(dep[2]):
            result.add(dep[1].name)

    elif type(dep) is kconfiglib.Symbol:
        if is_constant_y(dep):
            return
        if dep.name not in result:
            result.add(dep.name)
            _find_deps(dep.direct_dep, result, level + 1)


def find_deps(sym):
    result = set()
    _find_deps(sym.direct_dep, result, 0)
    return result


if __name__ == '__main__':
    for line in sys.stdin:
        line = line.strip()
        name = line.replace("CONFIG_", "")
        print("CONFIG_" + name)
        try:
            for d in find_deps(kconf.syms[name]):
                print("CONFIG_" + d)
        except KeyError:
            pass

