# Chemical plant (3x3m): brass-banded reactor, pipe rack, vent, gauges.
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa
import math as _m

ensure_base_materials()
C = col("FF_chemplant")
wipe_collection("FF_chemplant")

pad(C, 3.0, 3.0)
box(C, "BaseBlock", (2.15, 0.88, 2.15), (0, 0.58, 0), "FF_verdigris", bevel=0.05)
box(C, "Skirt", (2.3, 0.16, 2.3), (0, 0.22, 0), "FF_darkiron")
rivet_row(C, (-0.95, 0.95, 1.08), (0.95, 0.95, 1.08), n=7, r=0.026)

sphere(C, "Reactor", 0.92, (0, 1.88, 0), "FF_iron", verts=22)
for y, r in [(1.42, 0.78), (1.88, 0.92), (2.34, 0.78)]:
    cyl(C, "WeldBand", r, r, 0.05, (0, y - 0.025, 0), "FF_brass", verts=22)
cyl(C, "TopNozzle", 0.16, 0.16, 0.38, (0, 2.7, 0), "FF_iron", verts=12)
sphere(C, "NozzleCap", 0.18, (0, 2.92, 0), "FF_copper", verts=10)
valve(C, (0, 3.05, 0), r=0.09)

for i, y in enumerate([1.95, 2.25, 2.55]):
    p = cyl(C, "RackPipe", 0.065, 0.065, 2.5, (-1.2, y, -0.88 + i * 0.14),
            "FF_copper" if i == 1 else "FF_iron", verts=10, centered=True)
    p.rotation_euler = (0, _m.pi / 2, 0)
for sx in (-1.2, 0.15):
    box(C, "RackPost", (0.07, 1.45, 0.45), (sx, 0.72, -0.75), "FF_darkiron")

chimney(C, (1.0, 1.02, -1.0), r=0.12, h=1.55, material="FF_verdigris")
lamp(C, (-1.0, 1.18, 1.0), r=0.06)
box(C, "Stripe", (3.0, 0.02, 0.12), (0, 0.15, 1.43), "FF_bronze", bevel=0.004)
box(C, "Gauges", (0.55, 0.38, 0.07), (-0.55, 0.88, 1.1), "FF_darkiron", bevel=0.015)
for i in range(2):
    gauge(C, (-0.7 + i * 0.28, 0.9, 1.14), facing="z", r=0.07)

frame_camera_target(target=(0, 1.2, 0), dist=8.5)
print("chemplant done")
