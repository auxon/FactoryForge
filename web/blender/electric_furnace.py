# Electric furnace (3x3m): iron oven, glowing elements, brass coils, cabinet.
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
C = col("FF_electric_furnace")
wipe_collection("FF_electric_furnace")

pad(C, 3.0, 3.0)
box(C, "Body", (2.35, 1.65, 2.35), (0, 0.98, 0), "FF_iron", bevel=0.05)
box(C, "BaseFrame", (2.52, 0.22, 2.52), (0, 0.26, 0), "FF_darkiron")
box(C, "TopCap", (2.5, 0.16, 2.5), (0, 1.9, 0), "FF_darkiron")
rivet_row(C, (-1.05, 1.7, 1.18), (1.05, 1.7, 1.18), n=8, r=0.028)
rivet_row(C, (-1.05, 0.4, 1.18), (1.05, 0.4, 1.18), n=8, r=0.028)

box(C, "Door", (1.15, 1.05, 0.1), (0, 0.95, 1.2), "FF_soot", bevel=0.025)
box(C, "DoorFrame", (1.35, 1.25, 0.07), (0, 0.95, 1.16), "FF_brass", bevel=0.015)
for i in range(3):
    glow_plane(C, f"GlowElement{i}", 0.85, 0.1, (0, 0.68 + i * 0.26, 1.28))
# door wheel
valve(C, (0.48, 0.95, 1.28), r=0.1)

for sx in (-0.7, 0.7):
    box(C, "RoofVent", (0.48, 0.22, 0.48), (sx, 2.1, -0.55), "FF_darkiron", bevel=0.015)
chimney(C, (0.85, 2.02, -0.8), r=0.13, h=0.95, material="FF_rust")

box(C, "Cabinet", (0.58, 1.15, 0.48), (-1.32, 0.75, 0.55), "FF_iron", bevel=0.03)
gauge(C, (-1.32, 1.15, 0.8), facing="z", r=0.08)
lamp(C, (-1.32, 1.42, 0.55), r=0.06)
# induction coils
coil = cyl(C, "Coil", 0.15, 0.15, 0.95, (1.28, 0.55, -0.75), "FF_copper", verts=14)
# bus bars
box(C, "Bus", (0.08, 0.06, 0.9), (1.28, 1.45, -0.2), "FF_copper", bevel=0.006)
pipe(C, "Feed", 0.05, (-1.05, 1.2, 0.55), (-0.6, 1.2, 0.9), "FF_copper")
box(C, "Stripe", (3.0, 0.02, 0.12), (0, 0.15, 1.43), "FF_bronze", bevel=0.004)

frame_camera_target(target=(0, 1.1, 0), dist=8.0)
print("electric furnace done")
