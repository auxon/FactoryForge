# Pumpjack (1x1m): A-frame, walking Beam, horsehead, brass stuffing box.
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa
import math as _m

ensure_base_materials()
C = col("FF_pumpjack")
wipe_collection("FF_pumpjack")

box(C, "Base", (0.92, 0.12, 0.92), (0, 0.06, 0), "FF_darkiron", bevel=0.015)
for sx in (-0.35, 0.35):
    for sz in (-0.35, 0.35):
        bolt(C, (sx, 0.14, sz), r=0.03)

for s in (-1, 1):
    leg = box(C, "AFrame", (0.08, 1.05, 0.08), (s * 0.26, 0.58, -0.22), "FF_iron")
    leg.rotation_euler = (0.32, 0, s * -0.16)
box(C, "Bearing", (0.48, 0.12, 0.12), (0, 1.02, -0.3), "FF_brass")

beam = box(C, "Beam", (0.12, 0.1, 1.48), (0, 1.08, 0.22), "FF_iron", bevel=0.015)
hh = box(C, "Horsehead", (0.14, 0.28, 0.28), (0, 0.96, 0.92), "FF_darkiron", bevel=0.03)
parent_keep(hh, beam)
cw = box(C, "Counterweight", (0.18, 0.32, 0.22), (0, 0.86, -0.42), "FF_bronze", bevel=0.02)
parent_keep(cw, beam)
# beam rivets
for z in (-0.4, 0.1, 0.55):
    b = bolt(C, (0, 1.16, z), r=0.02, h=0.03)
    parent_keep(b, beam)

cyl(C, "Rod", 0.022, 0.022, 0.88, (0, 0.0, 0.92), "FF_iron", verts=8)
box(C, "StuffBox", (0.12, 0.14, 0.12), (0, 0.48, 0.92), "FF_brass", bevel=0.01)
box(C, "Motor", (0.28, 0.28, 0.36), (0.24, 0.3, -0.32), "FF_iron", bevel=0.02)
box(C, "BeltGuard", (0.32, 0.48, 0.1), (-0.14, 0.4, -0.32), "FF_brass", bevel=0.015)
gear(C, "CrankGear", 0.16, 10, 0.05, (-0.14, 0.35, -0.22), "FF_bronze", axis="x")
op = cyl(C, "Outlet", 0.045, 0.045, 0.48, (-0.32, 0.24, 0.28), "FF_copper", verts=8, centered=True)
op.rotation_euler = (0, _m.pi / 2, 0)
flange(C, (-0.55, 0.24, 0.28), r=0.08, axis="x", material="FF_brass")

frame_camera_target(target=(0, 0.6, 0), dist=4.5)
print("pumpjack done")
