#!/usr/bin/env python3
import kconfiglib
import os
import sys

HWDIRS=["drivers", "arch", "sound", "init"]
kconf = kconfiglib.Kconfig(warn=False)

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

def has_menunode(sym):
    return hasattr(sym, 'nodes') and len(sym.nodes) > 0

def has_multimenunodes(sym):
    return hasattr(sym, 'nodes') and len(sym.nodes) > 1

def is_hw(sym):
    subdir = sym.nodes[0].filename.split("/")[0]
    return subdir in HWDIRS

def is_sw(sym):
    return not is_hw(sym)

def get_deps(deps, result):
    if type(deps) in [kconfiglib.Symbol, kconfiglib.Choice]:
        return result.append(deps)
    else:
        for d in deps[1:]:
            result.append(d)
            get_deps(d, result)

def print_deps(sym):
    deps = []
    get_deps(sym, deps)
    for s in deps:
        print(s.name)


if __name__ == '__main__':
    syms = kconf.syms
    for line in sys.stdin:
        deps = []
        line = line.strip()
        name = line.replace("CONFIG_", "")
        if name not in syms:
            continue
        sym = syms[name]
        try:
            nodes = sym.nodes
            if nodes[0].prompt:
                print(line)
        except:
            pass
        
