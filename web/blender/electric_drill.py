# Electric mining drill (3x3m): iron derrick, brass motor, copper coils, Rotor.
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
C = col("FF_electric_drill")
wipe_collection("FF_electric_drill")

pad(C, 3.0, 3.0)
for sx in (-1.22, 1.22):
    for sz in (-1.22, 1.22):
        box(C, "Post", (0.18, 2.15, 0.18), (sx, 1.22, sz), "FF_iron", bevel=0.02)
        bolt(C, (sx, 0.2, sz), r=0.045)
        rivet_row(C, (sx, 0.4, sz), (sx, 2.1, sz), n=5, r=0.022, h=0.03)
ibeam(C, "GantryX", 2.6, (0, 2.38, 0), "FF_darkiron", axis="x")
ibeam(C, "GantryZ", 2.6, (0, 2.38, 0), "FF_darkiron", axis="z")

box(C, "Housing", (1.65, 1.15, 1.65), (0, 0.88, 0), "FF_iron", bevel=0.05)
box(C, "HousingBand", (1.74, 0.12, 1.74), (0, 0.42, 0), "FF_brass")
rivet_row(C, (-0.7, 1.3, 0.84), (0.7, 1.3, 0.84), n=6, r=0.028)
for i in range(5):
    box(C, "Vent", (0.65, 0.07, 0.05), (-0.4, 0.7 + i * 0.14, 0.84), "FF_brass", bevel=0.004)

# motor + copper coils
cyl(C, "Motor", 0.42, 0.48, 0.65, (0, 1.52, 0), "FF_darkiron", verts=18)
cyl(C, "Coil", 0.46, 0.46, 0.28, (0, 1.62, 0), "FF_copper", verts=18)
sphere(C, "MotorCap", 0.28, (0, 2.22, 0), "FF_brass", verts=14)
gear(C, "Crown", 0.38, 14, 0.08, (0, 2.05, 0), "FF_brass", axis="y")

rotor = cyl(C, "Rotor", 0.11, 0.11, 2.5, (0, -0.65, 0), "FF_iron", verts=12)
bit = cyl(C, "Bit", 0.03, 0.28, 0.85, (0, -0.7, 0), "FF_soot", verts=10)
parent_keep(bit, rotor)
for i in range(6):
    fl = torus(C, "Flight", 0.2, 0.035, (0, 0.2 + i * 0.22, 0), "FF_iron",
               major_seg=10, minor_seg=6)
    parent_keep(fl, rotor)

# cable run + cabinet
pipe(C, "Cable", 0.04, (1.05, 1.7, 0), (1.22, 1.7, -1.05), "FF_copper")
box(C, "Cabinet", (0.48, 0.95, 0.62), (1.08, 0.62, -1.05), "FF_iron", bevel=0.03)
box(C, "CabDoor", (0.02, 0.7, 0.4), (1.33, 0.62, -1.05), "FF_brass", bevel=0.008)
gauge(C, (1.08, 1.05, -0.7), facing="z", r=0.07)
lamp(C, (1.08, 1.2, -1.05), r=0.06)
box(C, "Stripe", (3.0, 0.02, 0.12), (0, 0.15, 1.43), "FF_bronze", bevel=0.004)

frame_camera_target(target=(0, 1.2, 0), dist=8.0)
print("electric drill done")
