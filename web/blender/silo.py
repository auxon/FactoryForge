# Rocket silo (9x9m): pad, pit ring, gantry tower, Rocket (animated rise).
import sys
sys.path.insert(0, "/home/rah/factoryforge/web/blender")
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa

ensure_base_materials()
C = col("FF_silo")
wipe_collection("FF_silo")

pad(C, 9.0, 9.0)
# pit: dark ring + inner collar
cyl(C, "PitRing", 2.2, 2.4, 0.5, (0, 0.15, 0), "FF_darksteel", verts=32)
cyl(C, "PitCollar", 1.7, 1.7, 0.7, (0, 0.15, 0), "FF_hazard", verts=32)
# Rocket (animated): body + nose + fins + engine bell
cyl(C, "RocketBody", 0.7, 0.7, 2.6, (0, 0.6, 0), "FF_pearl", verts=20)
cone(C, "RocketNose", 0.7, 1.0, (0, 3.2, 0), "FF_redlamp", verts=20)
for i in range(4):
    import math as _m
    fin = box(C, "RocketFin", (0.08, 0.9, 0.5), (0.75 * _m.cos(i * _m.pi / 2), 1.0, 0.75 * _m.sin(i * _m.pi / 2)), "FF_redlamp", bevel=0.02)
    fin.rotation_euler = (0, -i * _m.pi / 2, 0)
cyl(C, "RocketBell", 0.5, 0.28, 0.4, (0, 0.25, 0), "FF_darksteel", verts=16)
glow_plane(C, "RocketGlow", 0.5, 0.5, (0, 0.2, 0.55))
# gantry tower + crane arms + elevator rails
box(C, "Gantry", (0.8, 5.2, 0.8), (-2.6, 2.75, -2.6), "FF_hazard", bevel=0.04)
for y in (2.0, 3.4, 4.6):
    arm = box(C, "CraneArm", (2.2, 0.18, 0.18), (-1.5, y, -1.5), "FF_darksteel", bevel=0.02)
    arm.rotation_euler = (0, 0.6, 0)
box(C, "GantryTop", (1.0, 0.3, 1.0), (-2.6, 5.4, -2.6), "FF_darksteel")
sphere(C, "Beacon", 0.09, (-2.6, 5.65, -2.6), "FF_redlamp")
# hazard ring dashes + floodlight poles
for i in range(8):
    import math as _m2
    a = i * _m2.pi / 4
    box(C, "RingDash", (0.7, 0.02, 0.25), (3.4 * _m2.cos(a), 0.16, 3.4 * _m2.sin(a)), "FF_hazard", bevel=0.005)
for sx, sz in [(-4, 4), (4, -4)]:
    cyl(C, "FloodPole", 0.06, 0.08, 2.6, (sx, 0.15, sz), "FF_darksteel", verts=8)
    sphere(C, "FloodHead", 0.12, (sx, 2.8, sz), "FF_pearl")

frame_camera_target(target=(0, 2.0, 0), dist=16.0)
print("silo done")
