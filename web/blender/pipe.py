# Pipe (1x1m): brass-flanged iron cross, valve wheel.
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa
import math as _m

ensure_base_materials()
C = col("FF_pipe")
wipe_collection("FF_pipe")

ax = cyl(C, "ArmX", 0.15, 0.15, 0.96, (0, 0.3, 0), "FF_iron", verts=12, centered=True)
ax.rotation_euler = (0, _m.pi / 2, 0)
az = cyl(C, "ArmZ", 0.15, 0.15, 0.96, (0, 0.3, 0), "FF_iron", verts=12, centered=True)
az.rotation_euler = (_m.pi / 2, 0, 0)
sphere(C, "Hub", 0.2, (0, 0.3, 0), "FF_iron", verts=14)
cyl(C, "TopStub", 0.14, 0.14, 0.22, (0, 0.32, 0), "FF_iron", verts=12)
for loc, axis in [((0, 0.3, 0.47), "z"), ((0, 0.3, -0.47), "z"),
                  ((0.47, 0.3, 0), "x"), ((-0.47, 0.3, 0), "x")]:
    f = cyl(C, "Flange", 0.2, 0.2, 0.055, loc, "FF_brass", verts=12, centered=True)
    f.rotation_euler = (0, _m.pi / 2, 0) if axis == "x" else (_m.pi / 2, 0, 0)
valve(C, (0, 0.58, 0), r=0.12)
# packing nut
cyl(C, "Packing", 0.08, 0.08, 0.06, (0, 0.5, 0), "FF_bronze", verts=8)

frame_camera_target(target=(0, 0.3, 0), dist=3.0)
print("pipe done")
