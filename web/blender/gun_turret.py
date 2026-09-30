# Gun turret (2x2m): armored base, rotating Head + twin barrels, ammo box.
import sys
sys.path.insert(0, "/home/rah/factoryforge/web/blender")
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa
import math as _m

ensure_base_materials()
plain_material("FF_gunmetal", (0.3, 0.28, 0.22), metallic=0.8, roughness=0.5)
C = col("FF_gun_turret")
wipe_collection("FF_gun_turret")

pad(C, 2.0, 2.0)
# armored base: sloped skirt + turret ring
box(C, "Skirt", (1.5, 0.5, 1.5), (0, 0.4, 0), "FF_gunmetal", bevel=0.06)
cyl(C, "TurretRing", 0.55, 0.6, 0.25, (0, 0.65, 0), "FF_darksteel", verts=20)
# Head (animated aim): housing + mantlet + twin barrels + sight
box(C, "Head", (0.9, 0.55, 0.9), (0, 1.05, 0), "FF_gunmetal", bevel=0.06)
box(C, "Mantlet", (0.6, 0.4, 0.25), (0, 1.0, 0.5), "FF_darksteel", bevel=0.04)
for sx in (-0.15, 0.15):
    b = cyl(C, "Barrel", 0.055, 0.065, 1.1, (sx, 1.02, 0.6), "FF_darksteel", verts=10, centered=True)
    b.rotation_euler = (_m.pi / 2, 0, 0)
    mz = cyl(C, "Muzzle", 0.075, 0.075, 0.16, (sx, 1.02, 1.1), "FF_darksteel", verts=10, centered=True)
    mz.rotation_euler = (_m.pi / 2, 0, 0)
box(C, "Sight", (0.12, 0.12, 0.3), (0.3, 1.3, 0.2), "FF_darksteel", bevel=0.02)
sphere(C, "SightLens", 0.045, (0.3, 1.3, 0.37), "FF_redlamp")
# ammo box + feed chute on the side
box(C, "AmmoBox", (0.45, 0.5, 0.6), (-0.85, 0.5, -0.3), "FF_hazard", bevel=0.03)
box(C, "FeedChute", (0.15, 0.12, 0.5), (-0.55, 0.75, -0.3), "FF_darksteel", bevel=0.02)
# corner bolts
for sx in (-0.65, 0.65):
    for sz in (-0.65, 0.65):
        bolt(C, (sx, 0.2, sz), r=0.05)

frame_camera_target(target=(0, 0.8, 0), dist=6.0)
print("gun turret done")
