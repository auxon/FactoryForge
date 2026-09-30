# Pumpjack (1x1m): A-frame, walking Beam (animated), horsehead, motor, rod.
import sys
sys.path.insert(0, "/home/rah/factoryforge/web/blender")
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa

ensure_base_materials()
C = col("FF_pumpjack")
wipe_collection("FF_pumpjack")

box(C, "Base", (0.9, 0.14, 0.9), (0, 0.07, 0), "FF_darksteel", bevel=0.02)
# A-frame legs
for s in (-1, 1):
    leg = box(C, "AFrame", (0.09, 1.0, 0.09), (s * 0.28, 0.55, -0.25), "FF_hazard")
    leg.rotation_euler = (0.35, 0, s * -0.18)
box(C, "Bearing", (0.5, 0.14, 0.14), (0, 1.0, -0.32), "FF_darksteel")
# walking Beam (animated rock about X at bearing)
box(C, "Beam", (0.14, 0.12, 1.5), (0, 1.08, 0.25), "FF_hazard", bevel=0.02)
box(C, "Horsehead", (0.16, 0.3, 0.3), (0, 0.95, 0.95), "FF_darksteel", bevel=0.04)
box(C, "Counterweight", (0.2, 0.35, 0.25), (0, 0.85, -0.45), "FF_darksteel", bevel=0.03)
# polished rod into ground + stuffing box
cyl(C, "Rod", 0.025, 0.025, 0.9, (0, 0.0, 0.95), "FF_steel", verts=8)
box(C, "StuffBox", (0.12, 0.14, 0.12), (0, 0.5, 0.95), "FF_copper", bevel=0.01)
# motor + belt guard
box(C, "Motor", (0.3, 0.3, 0.4), (0.25, 0.3, -0.35), "FF_bluepaint", bevel=0.03)
box(C, "BeltGuard", (0.34, 0.5, 0.12), (-0.15, 0.4, -0.35), "FF_hazard", bevel=0.02)
# outlet pipe
import math as _m
op = cyl(C, "Outlet", 0.05, 0.05, 0.5, (-0.35, 0.25, 0.3), "FF_steel", verts=8)
op.rotation_euler = (0, _m.pi / 2, 0)

frame_camera_target(target=(0, 0.6, 0), dist=4.5)
print("pumpjack done")
