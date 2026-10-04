# Assembling machine (3x3m): iron gantry, glass cover, press Arms, brass cabinet.
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa
import math as _m
import bpy

ensure_base_materials()
C = col("FF_assembler")
wipe_collection("FF_assembler")

pad(C, 3.0, 3.0)
for sx in (-1.18, 1.18):
    for sz in (-1.18, 1.18):
        box(C, "Post", (0.16, 2.05, 0.16), (sx, 1.18, sz), "FF_iron", bevel=0.015)
        bolt(C, (sx, 0.2, sz), r=0.04)
ibeam(C, "GantryX", 2.55, (0, 2.22, 0), "FF_darkiron", axis="x")
ibeam(C, "GantryZ", 2.55, (0, 2.22, 0), "FF_darkiron", axis="z")

box(C, "Body", (1.95, 0.78, 1.95), (0, 0.55, 0), "FF_iron", bevel=0.04)
box(C, "BodyBand", (2.05, 0.1, 2.05), (0, 0.92, 0), "FF_brass")
rivet_row(C, (-0.85, 0.92, 1.0), (0.85, 0.92, 1.0), n=7, r=0.026)
box(C, "Table", (1.35, 0.12, 1.35), (0, 1.0, 0), "FF_darkiron")
box(C, "GlassTop", (1.48, 0.48, 1.48), (0, 1.32, 0), "FF_glass", bevel=0.03)

# press arms (animated)
for s in (-1, 1):
    arm = box(C, "Arm", (0.2, 0.48, 0.2), (s * 0.42, 1.28, 0), "FF_brass", bevel=0.02)
    pist = cyl(C, "Piston", 0.06, 0.06, 0.38, (s * 0.42, 0.88, 0), "FF_iron", verts=10)
    parent_keep(pist, arm)
    gear(C, "ArmGear", 0.16, 10, 0.05, (s * 0.42, 1.55, 0), "FF_bronze", axis="y")

for sz in (-1.32, 1.32):
    box(C, "Conveyor", (0.78, 0.16, 0.48), (0, 0.48, sz), "FF_darkiron", bevel=0.015)
    for i in range(3):
        r = cyl(C, "Roller", 0.045, 0.045, 0.65, (-0.22 + i * 0.22, 0.58, sz),
                "FF_iron", verts=8, centered=True)
        r.rotation_euler = (0, _m.pi / 2, 0)

box(C, "Cabinet", (0.48, 1.05, 0.55), (1.22, 0.68, -0.92), "FF_iron", bevel=0.03)
box(C, "CabDial", (0.12, 0.12, 0.04), (1.22, 1.05, -0.64), "FF_brass_polish", bevel=0.006)
gauge(C, (1.22, 0.95, -0.62), facing="z", r=0.07)
lamp(C, (1.22, 1.28, -0.92), r=0.06)
# overhead drive shaft
shaft = cyl(C, "LineShaft", 0.04, 0.04, 2.2, (0, 2.05, 0.9), "FF_iron", verts=8, centered=True)
shaft.rotation_euler = (0, _m.pi / 2, 0)
for sx in (-0.7, 0.7):
    gear(C, "LineGear", 0.14, 10, 0.04, (sx, 2.05, 0.9), "FF_brass", axis="x")

frame_camera_target(target=(0, 1.1, 0), dist=8.0)
print("assembler done")
