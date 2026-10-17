#!/usr/bin/env python3
"""把模板里的 {{role}} 占位符替换成实际色值。

用法: render.py <模板> <输出> role=hex [role=hex ...]
"""
import io
import sys

if len(sys.argv) < 4:
    sys.exit("用法: render.py <模板> <输出> role=hex ...")

tpl, dst = sys.argv[1], sys.argv[2]
palette = dict(arg.split("=", 1) for arg in sys.argv[3:])

s = io.open(tpl, encoding="utf-8").read()
for role, value in palette.items():
    s = s.replace("{{%s}}" % role, value)

io.open(dst, "w", encoding="utf-8").write(s)
