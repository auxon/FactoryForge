# Player: exosuit engineer (~1.75m). Faces +Z. Visor glows.
import sys
sys.path.insert(0, "/home/rah/factoryforge/web/blender")
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa

ensure_base_materials()
C = col("FF_player")
wipe_collection("FF_player")

# boots + legs
for sx in (-0.14, 0.14):
    box(C, "Boot", (0.22, 0.16, 0.32), (sx, 0.08, 0.02), "FF_darksteel", bevel=0.03)
    cyl(C, "Leg", 0.09, 0.11, 0.5, (sx, 0.16, 0), "FF_orange", verts=10)
    sphere(C, "Knee", 0.1, (sx, 0.42, 0.06), "FF_darksteel")
box(C, "Hips", (0.4, 0.2, 0.28), (0, 0.72, 0), "FF_darksteel", bevel=0.04)
# torso armor
box(C, "Torso", (0.52, 0.55, 0.36), (0, 1.1, 0), "FF_orange", bevel=0.06)
box(C, "ChestPlate", (0.4, 0.4, 0.06), (0, 1.12, 0.2), "metal_plate", bevel=0.02)
box(C, "Belt", (0.54, 0.1, 0.38), (0, 0.85, 0), "FF_hazard", bevel=0.02)
# backpack + tanks
box(C, "Pack", (0.38, 0.5, 0.2), (0, 1.12, -0.28), "FF_darksteel", bevel=0.04)
for sx in (-0.11, 0.11):
    cyl(C, "Tank", 0.08, 0.08, 0.42, (sx, 0.95, -0.4), "FF_steel", verts=10)
    sphere(C, "TankCap", 0.08, (sx, 1.16, -0.4), "FF_copper")
# arms
for s in (-1, 1):
    sphere(C, "Shoulder", 0.13, (s * 0.33, 1.32, 0), "FF_darksteel")
    arm = cyl(C, "Arm", 0.08, 0.07, 0.5, (s * 0.36, 0.82, 0.02), "FF_orange", verts=10)
    arm.rotation_euler = (0, 0, s * -0.12)
    box(C, "Glove", (0.14, 0.16, 0.16), (s * 0.4, 0.72, 0.04), "FF_darksteel", bevel=0.03)
# shoulder lamp
sphere(C, "Lamp", 0.05, (-0.33, 1.44, 0.05), "FF_greenlamp")
# helmet + visor
sphere(C, "Helmet", 0.21, (0, 1.62, 0), "FF_orange", scale=(1, 1.05, 1))
box(C, "Visor", (0.26, 0.12, 0.06), (0, 1.63, 0.17), "FF_visor", bevel=0.02)
cyl(C, "HelmRidge", 0.06, 0.1, 0.12, (0, 1.78, -0.02), "FF_darksteel", verts=8)
# antenna
cyl(C, "Antenna", 0.012, 0.012, 0.35, (0.15, 1.7, -0.1), "FF_darksteel", verts=6)
sphere(C, "AntennaTip", 0.025, (0.15, 2.06, -0.1), "FF_redlamp")

frame_camera_target(target=(0, 1.0, 0), dist=4.5)
print("player done")
