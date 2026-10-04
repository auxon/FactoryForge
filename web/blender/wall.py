# Stone wall (1x1m): soot-brick barrier, iron cap, brass studs.
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa

ensure_base_materials()
C = col("FF_wall")
wipe_collection("FF_wall")

box(C, "Footing", (0.95, 0.14, 0.95), (0, 0.07, 0), "FF_concrete", bevel=0.015)
box(C, "Body", (0.82, 0.72, 0.82), (0, 0.5, 0), "FF_brick", bevel=0.03)
box(C, "Cap", (0.9, 0.1, 0.9), (0, 0.92, 0), "FF_iron", bevel=0.015)
rivet_row(C, (-0.35, 0.92, 0.42), (0.35, 0.92, 0.42), n=4, r=0.022)
for s in (-1, 1):
    box(C, "Groove", (0.02, 0.48, 0.48), (s * 0.42, 0.5, 0), "FF_soot", bevel=0.003)
for sx in (-0.22, 0.22):
    for sz in (-0.22, 0.22):
        cyl(C, "Rebar", 0.018, 0.018, 0.16, (sx, 0.98, sz), "FF_iron", verts=6)

frame_camera_target(target=(0, 0.5, 0), dist=3.5)
print("wall done")
