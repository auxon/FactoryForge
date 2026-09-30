# Fluid tank (3x3m): big cylinder, roof, ladder, sight gauge, pipes.
import sys
sys.path.insert(0, "/home/rah/factoryforge/web/blender")
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa
import math as _m

ensure_base_materials()
C = col("FF_tank")
wipe_collection("FF_tank")

pad(C, 3.0, 3.0)
# tank shell + roof cone + rim
cyl(C, "Shell", 1.2, 1.25, 2.0, (0, 0.15, 0), "FF_lightsteel", verts=28)
cone(C, "Roof", 1.28, 0.5, (0, 2.15, 0), "FF_darksteel", verts=28)
cyl(C, "RoofRim", 1.3, 1.3, 0.08, (0, 2.12, 0), "FF_darksteel", verts=28)
sphere(C, "RoofCap", 0.12, (0, 2.7, 0), "FF_copper")
# vertical weld seams
for i in range(6):
    a = i * _m.pi / 3
    box(C, "Seam", (0.04, 1.9, 0.04), (1.22 * _m.cos(a), 1.1, 1.22 * _m.sin(a)), "FF_steel", bevel=0.005)
# ladder + cage hoops
for y in [0.5, 1.0, 1.5, 2.0]:
    box(C, "LadderRung", (0.3, 0.04, 0.04), (0, y, 1.3), "FF_hazard", bevel=0.005)
for s in (-0.16, 0.16):
    box(C, "LadderRail", (0.04, 2.0, 0.04), (s, 1.1, 1.3), "FF_darksteel", bevel=0.005)
# sight gauge (glass tube + fluid)
cyl(C, "GaugeTube", 0.05, 0.05, 1.4, (0.9, 0.5, 0.95), "FF_glass", verts=10)
cyl(C, "GaugeFluid", 0.035, 0.035, 0.8, (0.9, 0.5, 0.95), "FF_sac", verts=8)
# inlet/outlet pipes
for sx in (-0.8, 0.8):
    p = cyl(C, "PipeStub", 0.09, 0.09, 0.6, (sx, 0.3, 1.2), "FF_steel", verts=10, centered=True)
    p.rotation_euler = (_m.pi / 2, 0, 0)

frame_camera_target(target=(0, 1.2, 0), dist=8.0)
print("tank done")
