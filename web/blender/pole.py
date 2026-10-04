# Electric pole (1x1m): iron mast, brass insulators, transformer.
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa

ensure_base_materials()
C = col("FF_pole")
wipe_collection("FF_pole")

box(C, "Footing", (0.48, 0.18, 0.48), (0, 0.09, 0), "FF_concrete", bevel=0.015)
cyl(C, "Mast", 0.065, 0.095, 2.25, (0, 0.18, 0), "FF_iron", verts=10)
rivet_row(C, (0.08, 0.4, 0), (0.08, 2.1, 0), n=6, r=0.018, h=0.025)
box(C, "Crossarm", (1.15, 0.08, 0.08), (0, 2.18, 0), "FF_darkiron", bevel=0.008)
for sx in (-0.48, 0.48):
    cyl(C, "Insulator", 0.04, 0.055, 0.13, (sx, 2.22, 0), "FF_verdigris", verts=8)
    sphere(C, "WireNub", 0.028, (sx, 2.32, 0), "FF_copper", verts=8)
box(C, "Transformer", (0.28, 0.38, 0.2), (0, 1.55, -0.16), "FF_iron", bevel=0.02)
for i in range(4):
    box(C, "Fin", (0.32, 0.025, 0.22), (0, 1.42 + i * 0.09, -0.16), "FF_copper", bevel=0.003)
# ceramic petticoats
for y in (1.9, 2.0):
    cyl(C, "Skirt", 0.09, 0.07, 0.04, (0, y, 0), "FF_verdigris", verts=8)

frame_camera_target(target=(0, 1.2, 0), dist=5.0)
print("pole done")
