# Transport belt (1x1m): iron frame, brass rails, rollers, chevron slats.
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa
import math as _m

ensure_base_materials()
C = col("FF_belt")
wipe_collection("FF_belt")

for s in (-1, 1):
    box(C, "Rail", (0.09, 0.2, 0.98), (s * 0.42, 0.28, 0), "FF_brass", bevel=0.008)
    for dz in (-0.38, 0.38):
        box(C, "Leg", (0.07, 0.18, 0.07), (s * 0.42, 0.1, dz), "FF_darkiron")
        bolt(C, (s * 0.42, 0.22, dz), r=0.02, h=0.03)
for dz in (-0.44, 0.44):
    r = cyl(C, "RollerEnd", 0.085, 0.085, 0.72, (0, 0.34, dz), "FF_iron", verts=12, centered=True)
    r.rotation_euler = (0, _m.pi / 2, 0)
box(C, "Bed", (0.72, 0.05, 0.92), (0, 0.3, 0), "FF_soot", bevel=0.008)
for i in range(6):
    z = -0.375 + i * 0.15
    box(C, "Slat", (0.68, 0.025, 0.055), (0, 0.34, z), "FF_iron", bevel=0.003)
box(C, "Nub", (0.18, 0.08, 0.1), (0, 0.36, 0.48), "FF_brass", bevel=0.008)
# tiny side gears
gear(C, "Drive", 0.09, 8, 0.03, (0.42, 0.28, -0.42), "FF_bronze", axis="x")

frame_camera_target(target=(0, 0.3, 0), dist=3.5)
print("belt done")
