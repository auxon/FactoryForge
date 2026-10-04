# Steel furnace (2x2m): riveted iron body, brick throat, brass fittings, stack.
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa

ensure_base_materials()
C = col("FF_steel_furnace")
wipe_collection("FF_steel_furnace")

pad(C, 2.0, 2.0)
box(C, "Body", (1.62, 1.52, 1.62), (0, 0.92, 0), "FF_darkiron", bevel=0.04)
box(C, "Throat", (0.78, 0.58, 0.1), (0, 0.52, 0.8), "FF_brick", bevel=0.02)
box(C, "MouthInset", (0.58, 0.4, 0.08), (0, 0.5, 0.84), "FF_soot", bevel=0.015)
glow_plane(C, "GlowFire", 0.42, 0.28, (0, 0.5, 0.9))
box(C, "Lintel", (0.88, 0.12, 0.16), (0, 0.8, 0.82), "FF_brass")
box(C, "BandLow", (1.7, 0.12, 1.7), (0, 0.3, 0), "FF_brass")
box(C, "BandHigh", (1.7, 0.12, 1.7), (0, 1.52, 0), "FF_brass")
rivet_row(C, (-0.7, 1.52, 0.84), (0.7, 1.52, 0.84), n=6, r=0.03)
rivet_row(C, (-0.7, 0.3, 0.84), (0.7, 0.3, 0.84), n=6, r=0.028)
# side rivet columns
for sx in (-0.82, 0.82):
    rivet_row(C, (sx, 0.45, 0.7), (sx, 1.4, 0.7), n=5, r=0.022)

chimney(C, (-0.48, 1.68, -0.52), r=0.18, h=1.35, material="FF_rust")
box(C, "ControlBox", (0.38, 0.58, 0.28), (0.88, 0.48, -0.48), "FF_iron", bevel=0.025)
gauge(C, (0.88, 0.7, -0.32), facing="z", r=0.07)
valve(C, (0.88, 0.95, -0.48), r=0.08)
lamp(C, (0.88, 0.88, -0.48), r=0.055)
pipe(C, "Air", 0.05, (0.7, 0.42, 0.2), (0.7, 0.42, 0.7), "FF_copper")

frame_camera_target(target=(0, 0.9, 0), dist=6.0)
print("steel furnace done")
