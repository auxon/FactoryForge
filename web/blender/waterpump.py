# Water pump / offshore pump (1x1m): pump house, intake pipe, motor.
import sys
sys.path.insert(0, "/home/rah/factoryforge/web/blender")
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa
import math as _m

ensure_base_materials()
C = col("FF_waterpump")
wipe_collection("FF_waterpump")

box(C, "Base", (0.9, 0.14, 0.9), (0, 0.07, 0), "concrete_floor", bevel=0.02)
box(C, "House", (0.6, 0.5, 0.6), (0, 0.39, -0.1), "FF_bluepaint", bevel=0.04)
box(C, "HouseRoof", (0.68, 0.08, 0.68), (0, 0.68, -0.1), "FF_darksteel", bevel=0.02)
# volute (round pump body) + motor
cyl(C, "Volute", 0.22, 0.22, 0.3, (-0.15, 0.25, 0.25), "FF_steel", verts=16)
cyl(C, "Motor", 0.14, 0.14, 0.35, (0.25, 0.32, 0.25), "FF_bluepaint", verts=12)
box(C, "FanCover", (0.2, 0.2, 0.1), (0.25, 0.32, 0.48), "FF_darksteel", bevel=0.02)
# intake pipe (into water, +Z) + outlet (up)
p = cyl(C, "Intake", 0.09, 0.09, 0.7, (0, 0.25, 0.55), "FF_steel", verts=10, centered=True)
p.rotation_euler = (_m.pi / 2, 0, 0)
cyl(C, "IntakeFlange", 0.12, 0.12, 0.06, (0, 0.25, 0.88), "FF_darksteel", verts=10)
cyl(C, "Outlet", 0.09, 0.09, 0.4, (0.25, 0.5, -0.15), "FF_copper", verts=10)
sphere(C, "Lamp", 0.045, (-0.2, 0.62, -0.1), "FF_greenlamp")

frame_camera_target(target=(0, 0.35, 0), dist=3.5)
print("water pump done")
