# Gun turret (2x2m): riveted iron barbette, rotating Head, brass sights.
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa
import math as _m

ensure_base_materials()
C = col("FF_gun_turret")
wipe_collection("FF_gun_turret")

pad(C, 2.0, 2.0)
box(C, "Skirt", (1.48, 0.48, 1.48), (0, 0.38, 0), "FF_iron", bevel=0.05)
rivet_row(C, (-0.6, 0.55, 0.74), (0.6, 0.55, 0.74), n=6, r=0.028)
cyl(C, "TurretRing", 0.52, 0.58, 0.22, (0, 0.62, 0), "FF_brass", verts=18)

head = box(C, "Head", (0.88, 0.52, 0.88), (0, 1.02, 0), "FF_soot", bevel=0.05)
mant = box(C, "Mantlet", (0.58, 0.38, 0.22), (0, 0.98, 0.48), "FF_darkiron", bevel=0.03)
parent_keep(mant, head)
for sx in (-0.14, 0.14):
    b = cyl(C, "Barrel", 0.05, 0.06, 1.05, (sx, 1.0, 0.58), "FF_darkiron", verts=10, centered=True)
    b.rotation_euler = (_m.pi / 2, 0, 0)
    parent_keep(b, head)
    mz = cyl(C, "Muzzle", 0.07, 0.07, 0.14, (sx, 1.0, 1.08), "FF_brass", verts=10, centered=True)
    mz.rotation_euler = (_m.pi / 2, 0, 0)
    parent_keep(mz, head)
sight = box(C, "Sight", (0.1, 0.1, 0.26), (0.28, 1.28, 0.18), "FF_brass", bevel=0.015)
parent_keep(sight, head)
lens = sphere(C, "SightLens", 0.04, (0.28, 1.28, 0.34), "FF_redlamp", verts=8)
parent_keep(lens, head)

box(C, "AmmoBox", (0.42, 0.48, 0.55), (-0.82, 0.48, -0.28), "FF_iron", bevel=0.025)
box(C, "FeedChute", (0.14, 0.1, 0.45), (-0.52, 0.72, -0.28), "FF_darkiron", bevel=0.012)
for sx in (-0.62, 0.62):
    for sz in (-0.62, 0.62):
        bolt(C, (sx, 0.2, sz), r=0.045)

frame_camera_target(target=(0, 0.8, 0), dist=6.0)
print("gun turret done")
