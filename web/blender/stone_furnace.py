# Stone furnace (2x2m): brick block, arched mouth Glow, stout chimney.
import sys
sys.path.insert(0, "/home/rah/factoryforge/web/blender")
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa

ensure_base_materials()
C = col("FF_stone_furnace")
wipe_collection("FF_stone_furnace")

pad(C, 2.0, 2.0)
# brick body
box(C, "Body", (1.6, 1.3, 1.6), (0, 0.8, 0), "FF_brick", bevel=0.05)
# metal bands
box(C, "BandLow", (1.68, 0.12, 1.68), (0, 0.35, 0), "FF_darksteel")
box(C, "BandHigh", (1.68, 0.12, 1.68), (0, 1.25, 0), "FF_darksteel")
# mouth: dark inset + glow + lintel
box(C, "MouthInset", (0.7, 0.5, 0.1), (0, 0.45, 0.78), "FF_darksteel", bevel=0.02)
glow_plane(C, "GlowFire", 0.55, 0.35, (0, 0.45, 0.84))
box(C, "Lintel", (0.9, 0.14, 0.2), (0, 0.78, 0.8), "FF_darksteel")
# top opening rim
box(C, "TopRim", (1.0, 0.12, 1.0), (0, 1.5, 0), "FF_darksteel")
box(C, "TopHole", (0.7, 0.14, 0.7), (0, 1.5, 0), "FF_darksteel")
# stout chimney behind
chimney(C, (-0.45, 1.45, -0.55), r=0.22, h=1.1, material="FF_brick")
# side ore shelf
box(C, "Shelf", (0.5, 0.08, 0.9), (0.95, 0.9, 0), "FF_darksteel")
for sx in (0.8, 1.1):
    box(C, "ShelfLeg", (0.06, 0.9, 0.06), (sx, 0.45, 0.35), "FF_darksteel")

frame_camera_target(target=(0, 0.8, 0), dist=6.0)
print("stone furnace done")
