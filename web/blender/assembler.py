# Assembling machine 1 (3x3m): frame rig, glass top, 2 press Arms, cabinet.
import sys
sys.path.insert(0, "/home/rah/factoryforge/web/blender")
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa

ensure_base_materials()
C = col("FF_assembler")
wipe_collection("FF_assembler")

pad(C, 3.0, 3.0)
# corner posts + gantry
for sx in (-1.2, 1.2):
    for sz in (-1.2, 1.2):
        box(C, "Post", (0.18, 2.0, 0.18), (sx, 1.15, sz), "FF_bluepaint")
        bolt(C, (sx, 0.2, sz))
box(C, "Gantry", (2.7, 0.2, 2.7), (0, 2.2, 0), "FF_darksteel")
# lower body
box(C, "Body", (2.0, 0.8, 2.0), (0, 0.55, 0), "FF_lightsteel", bevel=0.05)
box(C, "BodyBand", (2.08, 0.12, 2.08), (0, 0.95, 0), "FF_darksteel")
# work table + glass cover
box(C, "Table", (1.4, 0.15, 1.4), (0, 1.02, 0), "FF_darksteel")
box(C, "GlassTop", (1.5, 0.5, 1.5), (0, 1.35, 0), "FF_glass", bevel=0.04)
# 2 press arms (animated) - fully inside the glass cover
for s in (-1, 1):
    box(C, "Arm", (0.22, 0.5, 0.22), (s * 0.45, 1.3, 0), "FF_hazard", bevel=0.03)
    cyl(C, "ArmPiston", 0.07, 0.07, 0.4, (s * 0.45, 0.9, 0), "FF_steel", verts=10)
# in/out conveyor stubs
for sz in (-1.35, 1.35):
    box(C, "Conveyor", (0.8, 0.18, 0.5), (0, 0.5, sz), "FF_darksteel", bevel=0.02)
    import math as _m
    for i in range(3):
        r = cyl(C, "Roller", 0.05, 0.05, 0.7, (-0.25 + i * 0.25, 0.55, sz), "FF_steel", verts=8)
        r.rotation_euler = (0, 0, _m.pi / 2)
# cabinet + lamp
box(C, "Cabinet", (0.5, 1.0, 0.6), (1.25, 0.65, -0.9), "FF_bluepaint", bevel=0.04)
sphere(C, "Lamp", 0.07, (1.25, 1.25, -0.9), "FF_greenlamp")

frame_camera_target(target=(0, 1.1, 0), dist=8.0)
print("assembler done")
