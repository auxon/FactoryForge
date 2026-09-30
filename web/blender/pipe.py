# Pipe (1x1m): cross junction with flanges + valve wheel.
import sys
sys.path.insert(0, "/home/rah/factoryforge/web/blender")
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa
import math as _m

ensure_base_materials()
C = col("FF_pipe")
wipe_collection("FF_pipe")

# cross arms along X and Z (Z-cylinder rotated to lie horizontal)
ax = cyl(C, "ArmX", 0.16, 0.16, 0.95, (0, 0.3, 0), "FF_steel", verts=14, centered=True)
ax.rotation_euler = (0, _m.pi / 2, 0)
az = cyl(C, "ArmZ", 0.16, 0.16, 0.95, (0, 0.3, 0), "FF_steel", verts=14, centered=True)
az.rotation_euler = (_m.pi / 2, 0, 0)
# center hub + top stub + flanges
sphere(C, "Hub", 0.2, (0, 0.3, 0), "FF_steel")
cyl(C, "TopStub", 0.16, 0.16, 0.25, (0, 0.3, 0), "FF_steel", verts=14)
for loc, along_x in [((0, 0.3, 0.48), False), ((0, 0.3, -0.48), False), ((0.48, 0.3, 0), True), ((-0.48, 0.3, 0), True)]:
    f = cyl(C, "Flange", 0.2, 0.2, 0.07, loc, "FF_darksteel", verts=14, centered=True)
    f.rotation_euler = (0, _m.pi / 2, 0) if along_x else (_m.pi / 2, 0, 0)
box(C, "ValveWheel", (0.2, 0.05, 0.2), (0, 0.52, 0), "FF_redlamp", bevel=0.01)

frame_camera_target(target=(0, 0.3, 0), dist=3.0)
print("pipe done")
