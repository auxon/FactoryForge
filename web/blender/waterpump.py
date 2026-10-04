# Water pump (1x1m): iron pump house, brass volute, copper pipes.
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa
import math as _m

ensure_base_materials()
C = col("FF_waterpump")
wipe_collection("FF_waterpump")

box(C, "Base", (0.9, 0.12, 0.9), (0, 0.06, 0), "FF_concrete", bevel=0.015)
box(C, "House", (0.58, 0.48, 0.58), (0, 0.38, -0.1), "FF_iron", bevel=0.03)
box(C, "HouseRoof", (0.66, 0.07, 0.66), (0, 0.66, -0.1), "FF_copper", bevel=0.015)
cyl(C, "Volute", 0.2, 0.2, 0.28, (-0.14, 0.24, 0.24), "FF_brass", verts=16)
cyl(C, "Motor", 0.13, 0.13, 0.32, (0.24, 0.3, 0.24), "FF_iron", verts=12)
box(C, "FanCover", (0.18, 0.18, 0.08), (0.24, 0.3, 0.46), "FF_darkiron", bevel=0.012)
p = cyl(C, "Intake", 0.08, 0.08, 0.68, (0, 0.24, 0.52), "FF_iron", verts=10, centered=True)
p.rotation_euler = (_m.pi / 2, 0, 0)
cyl(C, "IntakeFlange", 0.12, 0.12, 0.05, (0, 0.24, 0.86), "FF_brass", verts=10)
cyl(C, "Outlet", 0.08, 0.08, 0.38, (0.24, 0.48, -0.14), "FF_copper", verts=10)
valve(C, (0.24, 0.72, -0.14), r=0.08)
lamp(C, (-0.18, 0.6, -0.1), r=0.04)
# drip tray
box(C, "Tray", (0.4, 0.04, 0.28), (0, 0.16, 0.35), "FF_copper", bevel=0.006)

frame_camera_target(target=(0, 0.35, 0), dist=3.5)
print("water pump done")
