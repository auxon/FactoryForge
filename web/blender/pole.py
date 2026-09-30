# Small electric pole (1x1m): concrete mast, crossarm, 4 insulators.
import sys
sys.path.insert(0, "/home/rah/factoryforge/web/blender")
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa

ensure_base_materials()
C = col("FF_pole")
wipe_collection("FF_pole")

box(C, "Footing", (0.5, 0.2, 0.5), (0, 0.1, 0), "concrete_floor", bevel=0.02)
cyl(C, "Mast", 0.07, 0.1, 2.3, (0, 0.2, 0), "concrete_floor", verts=10)
box(C, "Crossarm", (1.1, 0.09, 0.09), (0, 2.2, 0), "FF_darksteel", bevel=0.01)
for sx in (-0.45, 0.45):
    cyl(C, "Insulator", 0.045, 0.06, 0.14, (sx, 2.25, 0), "FF_glass", verts=8)
    sphere(C, "WireNub", 0.03, (sx, 2.34, 0), "FF_copper")
box(C, "Transformer", (0.3, 0.4, 0.22), (0, 1.6, -0.18), "FF_bluepaint", bevel=0.03)
for i in range(3):
    box(C, "Fin", (0.34, 0.03, 0.24), (0, 1.5 + i * 0.1, -0.18), "FF_darksteel", bevel=0.005)

frame_camera_target(target=(0, 1.2, 0), dist=5.0)
print("pole done")
