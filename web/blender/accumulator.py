# Accumulator (2x2m): Leyden / battery bank, brass terminals, charge Glow.
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa

ensure_base_materials()
C = col("FF_accumulator")
wipe_collection("FF_accumulator")

pad(C, 2.0, 2.0)
box(C, "Bank", (1.55, 1.08, 1.55), (0, 0.7, 0), "FF_verdigris", bevel=0.045)
box(C, "BankBase", (1.68, 0.14, 1.68), (0, 0.2, 0), "FF_darkiron")
rivet_row(C, (-0.65, 1.15, 0.78), (0.65, 1.15, 0.78), n=6, r=0.026)
for i in range(4):
    cyl(C, "CellCap", 0.08, 0.08, 0.1, (-0.55 + i * 0.37, 1.24, 0), "FF_brass", verts=10)
    cyl(C, "Jar", 0.12, 0.12, 0.35, (-0.55 + i * 0.37, 0.85, 0.45), "FF_glass", verts=10)
box(C, "ChargeBar", (1.15, 0.14, 0.05), (0, 0.95, 0.8), "FF_greenlamp", bevel=0.008)
box(C, "ChargeFrame", (1.28, 0.26, 0.045), (0, 0.95, 0.77), "FF_brass", bevel=0.008)
for s in (-1, 1):
    cyl(C, "Terminal", 0.055, 0.075, 0.22, (s * 0.48, 1.24, -0.48), "FF_copper", verts=8)
    box(C, "Vent", (0.28, 0.36, 0.05), (s * 0.48, 0.7, -0.8), "FF_darkiron", bevel=0.008)
lamp(C, (0.58, 1.32, 0.58), r=0.055)
# bus bar
box(C, "Bus", (1.1, 0.04, 0.06), (0, 1.38, -0.48), "FF_copper", bevel=0.004)

frame_camera_target(target=(0, 0.7, 0), dist=6.0)
print("accumulator done")
