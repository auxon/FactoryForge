# Stone wall (1x1m): tapered concrete barrier with cap + rebar stubs.
import sys
sys.path.insert(0, "/home/rah/factoryforge/web/blender")
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa

ensure_base_materials()
C = col("FF_wall")
wipe_collection("FF_wall")

box(C, "Footing", (0.95, 0.15, 0.95), (0, 0.075, 0), "concrete_floor", bevel=0.02)
box(C, "Body", (0.8, 0.75, 0.8), (0, 0.52, 0), "concrete_floor", bevel=0.04)
box(C, "Cap", (0.9, 0.12, 0.9), (0, 0.95, 0), "FF_darksteel", bevel=0.02)
# panel grooves
for s in (-1, 1):
    box(C, "Groove", (0.02, 0.5, 0.5), (s * 0.41, 0.5, 0), "FF_darksteel", bevel=0.005)
# rebar stubs on top (connection teeth)
for sx in (-0.25, 0.25):
    for sz in (-0.25, 0.25):
        cyl(C, "Rebar", 0.02, 0.02, 0.18, (sx, 1.01, sz), "FF_steel", verts=6)

frame_camera_target(target=(0, 0.5, 0), dist=3.5)
print("wall done")
