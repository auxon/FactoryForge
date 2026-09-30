# Chest (1x1m): steel crate, lid, corner posts, stencil stripes.
import sys
sys.path.insert(0, "/home/rah/factoryforge/web/blender")
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa

ensure_base_materials()
C = col("FF_chest")
wipe_collection("FF_chest")

box(C, "Base", (0.85, 0.12, 0.85), (0, 0.06, 0), "FF_darksteel", bevel=0.02)
box(C, "Body", (0.8, 0.55, 0.8), (0, 0.45, 0), "metal_plate", bevel=0.04)
# corner posts
for sx in (-0.36, 0.36):
    for sz in (-0.36, 0.36):
        box(C, "Corner", (0.09, 0.62, 0.09), (sx, 0.45, sz), "FF_darksteel", bevel=0.01)
# lid + handle + stencil stripe
box(C, "Lid", (0.86, 0.14, 0.86), (0, 0.79, 0), "FF_hazard", bevel=0.03)
box(C, "Handle", (0.2, 0.05, 0.06), (0, 0.82, 0.44), "FF_darksteel", bevel=0.01)
box(C, "Stencil", (0.5, 0.2, 0.02), (0, 0.45, 0.41), "FF_bluepaint", bevel=0.005)

frame_camera_target(target=(0, 0.4, 0), dist=3.5)
print("chest done")
