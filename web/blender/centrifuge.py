# Centrifuge (3x3m): squat base, spinning Rotor drum, feed pipes, panel.
import sys
sys.path.insert(0, "/home/rah/factoryforge/web/blender")
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa
import math as _m

ensure_base_materials()
C = col("FF_centrifuge")
wipe_collection("FF_centrifuge")

pad(C, 3.0, 3.0)
# base + vibration mounts
box(C, "Base", (2.0, 0.5, 2.0), (0, 0.4, 0), "FF_darksteel", bevel=0.05)
for sx in (-0.8, 0.8):
    for sz in (-0.8, 0.8):
        cyl(C, "Mount", 0.09, 0.11, 0.25, (sx, 0.15, sz), "FF_steel", verts=8)
# outer casing (open top) + spinning Rotor drum inside
cyl(C, "Casing", 0.85, 0.9, 0.9, (0, 0.65, 0), "FF_lightsteel", verts=24)
cyl(C, "CasingRim", 0.9, 0.9, 0.1, (0, 1.5, 0), "FF_hazard", verts=24)
cyl(C, "Rotor", 0.6, 0.6, 0.7, (0, 0.75, 0), "FF_steel", verts=20)
sphere(C, "RotorCap", 0.25, (0, 1.15, 0), "FF_copper")
# feed/discharge pipes + control panel + lamp
for s, z in [(-1, 0.6), (1, -0.6)]:
    p = cyl(C, "FeedPipe", 0.08, 0.08, 1.2, (s * 1.1, 0.5, z), "FF_copper", verts=10, centered=True)
    p.rotation_euler = (0, _m.pi / 2, 0)
box(C, "Panel", (0.5, 0.9, 0.25), (1.15, 0.6, 0.9), "FF_bluepaint", bevel=0.03)
sphere(C, "Lamp", 0.06, (1.15, 1.15, 0.9), "FF_greenlamp")
box(C, "Stripe", (3.0, 0.02, 0.14), (0, 0.16, 1.43), "FF_hazard", bevel=0.005)

frame_camera_target(target=(0, 0.9, 0), dist=8.0)
print("centrifuge done")
