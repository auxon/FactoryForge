# Chest (1x1m): riveted iron crate, brass lid, leather straps.
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa

ensure_base_materials()
C = col("FF_chest")
wipe_collection("FF_chest")

box(C, "Base", (0.86, 0.1, 0.86), (0, 0.05, 0), "FF_darkiron", bevel=0.015)
box(C, "Body", (0.8, 0.52, 0.8), (0, 0.42, 0), "FF_iron", bevel=0.03)
for sx in (-0.36, 0.36):
    for sz in (-0.36, 0.36):
        box(C, "Corner", (0.08, 0.58, 0.08), (sx, 0.42, sz), "FF_brass", bevel=0.008)
        bolt(C, (sx, 0.18, sz), r=0.025)
box(C, "Lid", (0.86, 0.12, 0.86), (0, 0.76, 0), "FF_brass", bevel=0.025)
box(C, "Handle", (0.22, 0.045, 0.055), (0, 0.8, 0.42), "FF_bronze", bevel=0.008)
box(C, "Lock", (0.12, 0.1, 0.06), (0, 0.55, 0.42), "FF_brass_polish", bevel=0.008)
box(C, "Strap", (0.08, 0.5, 0.82), (0, 0.42, 0), "FF_leather", bevel=0.006)
rivet_row(C, (-0.3, 0.55, 0.41), (0.3, 0.55, 0.41), n=4, r=0.02)

frame_camera_target(target=(0, 0.4, 0), dist=3.5)
print("chest done")
