# Centrifuge (3x3m): iron base, spinning Rotor drum, brass pipes, panel.
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa
import math as _m

ensure_base_materials()
C = col("FF_centrifuge")
wipe_collection("FF_centrifuge")

pad(C, 3.0, 3.0)
box(C, "Base", (1.95, 0.48, 1.95), (0, 0.38, 0), "FF_darkiron", bevel=0.04)
for sx in (-0.78, 0.78):
    for sz in (-0.78, 0.78):
        cyl(C, "Mount", 0.08, 0.1, 0.22, (sx, 0.14, sz), "FF_brass", verts=8)
cyl(C, "Casing", 0.82, 0.88, 0.88, (0, 0.62, 0), "FF_iron", verts=22)
cyl(C, "CasingRim", 0.88, 0.88, 0.08, (0, 1.48, 0), "FF_brass", verts=22)
rivet_ring(C, (0, 1.48, 0), 0.86, n=12, r=0.022, h=0.03)

rotor = cyl(C, "Rotor", 0.58, 0.58, 0.68, (0, 0.72, 0), "FF_iron", verts=18)
cap = sphere(C, "RotorCap", 0.22, (0, 1.12, 0), "FF_copper", verts=12)
parent_keep(cap, rotor)
for i in range(6):
    a = i * _m.tau / 6
    vane = box(C, "Vane", (0.06, 0.5, 0.22), (0.35 * _m.cos(a), 1.0, 0.35 * _m.sin(a)),
               "FF_brass", bevel=0.01)
    vane.rotation_euler = (0, -a, 0)
    parent_keep(vane, rotor)

for s, z in [(-1, 0.55), (1, -0.55)]:
    p = cyl(C, "FeedPipe", 0.07, 0.07, 1.15, (s * 1.08, 0.48, z), "FF_copper",
            verts=10, centered=True)
    p.rotation_euler = (0, _m.pi / 2, 0)
    flange(C, (s * 1.45, 0.48, z), r=0.12, axis="x", material="FF_brass")
box(C, "Panel", (0.48, 0.88, 0.22), (1.12, 0.58, 0.88), "FF_iron", bevel=0.025)
gauge(C, (1.12, 0.85, 1.0), facing="z", r=0.07)
lamp(C, (1.12, 1.12, 0.88), r=0.055)
box(C, "Stripe", (3.0, 0.02, 0.12), (0, 0.15, 1.43), "FF_bronze", bevel=0.004)

frame_camera_target(target=(0, 0.9, 0), dist=8.0)
print("centrifuge done")
