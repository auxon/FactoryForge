# Fluid tank (3x3m): riveted iron cylinder, brass roof, ladder, sight glass.
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa
import math as _m

ensure_base_materials()
C = col("FF_tank")
wipe_collection("FF_tank")

pad(C, 3.0, 3.0)
cyl(C, "Shell", 1.18, 1.22, 2.0, (0, 0.15, 0), "FF_iron", verts=24)
cone(C, "Roof", 1.26, 0.48, (0, 2.15, 0), "FF_copper", verts=24)
cyl(C, "RoofRim", 1.28, 1.28, 0.07, (0, 2.12, 0), "FF_brass", verts=24)
sphere(C, "RoofCap", 0.12, (0, 2.68, 0), "FF_brass_polish", verts=10)
valve(C, (0, 2.78, 0), r=0.09)

for i in range(8):
    a = i * _m.tau / 8
    box(C, "Seam", (0.04, 1.9, 0.04), (1.2 * _m.cos(a), 1.1, 1.2 * _m.sin(a)), "FF_brass", bevel=0.004)
    rivet_row(C, (1.2 * _m.cos(a), 0.4, 1.2 * _m.sin(a)),
              (1.2 * _m.cos(a), 1.9, 1.2 * _m.sin(a)), n=5, r=0.02, h=0.03)

for y in (0.45, 0.9, 1.35, 1.8, 2.2):
    box(C, "LadderRung", (0.28, 0.035, 0.035), (0, y, 1.28), "FF_brass", bevel=0.004)
for s in (-0.15, 0.15):
    box(C, "LadderRail", (0.035, 2.0, 0.035), (s, 1.15, 1.28), "FF_darkiron", bevel=0.004)

cyl(C, "GaugeTube", 0.045, 0.045, 1.35, (0.88, 0.5, 0.95), "FF_glass", verts=8)
cyl(C, "GaugeFluid", 0.03, 0.03, 0.75, (0.88, 0.5, 0.95), "FF_verdigris", verts=6)
for sx in (-0.75, 0.75):
    p = cyl(C, "PipeStub", 0.08, 0.08, 0.55, (sx, 0.32, 1.18), "FF_iron", verts=10, centered=True)
    p.rotation_euler = (_m.pi / 2, 0, 0)
    flange(C, (sx, 0.32, 1.42), r=0.12, axis="z", material="FF_brass")

frame_camera_target(target=(0, 1.2, 0), dist=8.0)
print("tank done")
