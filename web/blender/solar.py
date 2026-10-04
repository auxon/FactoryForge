# Solar panel (3x3m): iron trestle, brass-framed cells, junction box.
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa
import math as _m

ensure_base_materials()
C = col("FF_solar")
wipe_collection("FF_solar")

TILT = -0.42
PIVOT_Y = 1.32


def _tilt(o, y, z):
    dy = y - PIVOT_Y
    c, s = _m.cos(TILT), _m.sin(TILT)
    o.location.y = PIVOT_Y + dy * c - z * s
    o.location.z = dy * s + z * c
    o.rotation_euler = (TILT, 0, 0)


for sx in (-1.32, 1.32):
    rail = box(C, "Rail", (0.09, 0.07, 2.85), (sx, PIVOT_Y, 0), "FF_iron")
    rail.rotation_euler = (TILT, 0, 0)
for sx in (-1.32, 1.32):
    for z, top in [(-1.08, 0.82), (1.08, 1.78)]:
        h = top - 0.14
        box(C, "Post", (0.11, h, 0.11), (sx, 0.14 + h / 2, z), "FF_darkiron")
        bolt(C, (sx, 0.2, z), r=0.03)

for ix in range(4):
    for iz in range(3):
        cell = box(C, "Cell", (0.6, 0.035, 0.76), (-1.02 + ix * 0.68, 1.32, -0.78 + iz * 0.82),
                   "FF_copper", bevel=0.004)
        _tilt(cell, 1.32, -0.78 + iz * 0.82)
for name, x, z in [("FrameEdgeN", 0, 1.3), ("FrameEdgeS", 0, -1.3)]:
    e = box(C, name, (2.85, 0.09, 0.07), (x, PIVOT_Y, z), "FF_brass")
    _tilt(e, PIVOT_Y, z)
for name, x in [("FrameEdgeW", -1.42), ("FrameEdgeE", 1.42)]:
    e = box(C, name, (0.07, 0.09, 2.65), (x, PIVOT_Y, 0), "FF_brass")
    _tilt(e, PIVOT_Y, 0)

box(C, "Junction", (0.38, 0.22, 0.28), (0.78, 0.88, -0.98), "FF_iron", bevel=0.015)
pipe(C, "Cable", 0.03, (0.78, 0.7, -0.98), (0.78, 0.2, -0.98), "FF_copper")
gauge(C, (0.78, 1.05, -0.82), facing="z", r=0.06)

frame_camera_target(target=(0, 1.0, 0), dist=8.0)
print("solar done")
