# Stone furnace (2x2m): soot-brick kiln, arched mouth Glow, iron bands, stack.
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa

ensure_base_materials()
C = col("FF_stone_furnace")
wipe_collection("FF_stone_furnace")

pad(C, 2.0, 2.0)
box(C, "Body", (1.62, 1.35, 1.62), (0, 0.82, 0), "FF_brick", bevel=0.04)
box(C, "BandLow", (1.72, 0.1, 1.72), (0, 0.32, 0), "FF_iron")
box(C, "BandHigh", (1.72, 0.1, 1.72), (0, 1.28, 0), "FF_iron")
rivet_row(C, (-0.7, 0.32, 0.86), (0.7, 0.32, 0.86), n=6, r=0.026)
rivet_row(C, (-0.7, 1.28, 0.86), (0.7, 1.28, 0.86), n=6, r=0.026)

# arched mouth
box(C, "MouthInset", (0.72, 0.52, 0.1), (0, 0.48, 0.8), "FF_soot", bevel=0.02)
glow_plane(C, "GlowFire", 0.52, 0.34, (0, 0.48, 0.86))
box(C, "Lintel", (0.95, 0.14, 0.18), (0, 0.82, 0.82), "FF_iron")
# arch voussoirs
for i, x in enumerate((-0.32, -0.16, 0, 0.16, 0.32)):
    box(C, "Voussoir", (0.14, 0.1, 0.16), (x, 0.78 + (0.04 if i in (0, 4) else 0.08), 0.82),
        "FF_brick", bevel=0.01)

box(C, "TopRim", (1.05, 0.1, 1.05), (0, 1.55, 0), "FF_iron")
box(C, "TopHole", (0.55, 0.12, 0.55), (0, 1.55, 0), "FF_soot")
chimney(C, (-0.48, 1.5, -0.52), r=0.2, h=1.15, material="FF_brick")
pipe(C, "Flue", 0.06, (-0.2, 1.55, -0.2), (-0.48, 1.55, -0.52), "FF_iron")

box(C, "Shelf", (0.48, 0.07, 0.85), (0.95, 0.88, 0), "FF_iron")
for sx in (0.82, 1.08):
    box(C, "ShelfLeg", (0.06, 0.88, 0.06), (sx, 0.44, 0.32), "FF_iron")
# bellows / air inlet
box(C, "Bellows", (0.35, 0.22, 0.28), (-0.85, 0.38, 0.55), "FF_leather", bevel=0.02)
tuy = cyl(C, "Tuyere", 0.05, 0.05, 0.35, (-0.55, 0.42, 0.55), "FF_brass", verts=8, centered=True)
tuy.rotation_euler = (0, 1.5708, 0)

frame_camera_target(target=(0, 0.8, 0), dist=6.0)
print("stone furnace done")
