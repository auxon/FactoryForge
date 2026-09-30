# Lab (3x3m): white instrument base, glass dome, glowing flask, antenna.
import sys
sys.path.insert(0, "/home/rah/factoryforge/web/blender")
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa

ensure_base_materials()
C = col("FF_lab")
wipe_collection("FF_lab")

pad(C, 3.0, 3.0)
# instrument base with panel lines + vents
box(C, "Base", (2.4, 0.8, 2.4), (0, 0.55, 0), "FF_pearl", bevel=0.06)
box(C, "BaseTrim", (2.5, 0.12, 2.5), (0, 0.2, 0), "FF_bluepaint")
for s in (-1, 1):
    box(C, "Vent", (0.5, 0.3, 0.06), (s * 0.6, 0.55, 1.21), "FF_darksteel", bevel=0.01)
    box(C, "Panel", (0.4, 0.5, 0.06), (s * 0.6, 0.55, -1.21), "FF_lightsteel", bevel=0.01)
# glass dome + inner flask (glow) + coil
sphere(C, "Dome", 1.0, (0, 0.95, 0), "FF_glass", scale=(1, 0.75, 1), verts=24)
sphere(C, "Flask", 0.32, (0, 1.25, 0), "FF_sac")
cyl(C, "FlaskNeck", 0.08, 0.08, 0.3, (0, 1.45, 0), "FF_glass", verts=10)
# antenna mast + dish + lamp
cyl(C, "Mast", 0.04, 0.05, 1.2, (-1.0, 0.95, -1.0), "FF_darksteel", verts=8)
sphere(C, "Dish", 0.22, (-1.0, 2.2, -1.0), "FF_lightsteel", scale=(1, 0.5, 1))
sphere(C, "Lamp", 0.06, (1.0, 1.05, 1.0), "FF_greenlamp")
# sample tray + beakers
box(C, "Tray", (0.7, 0.08, 0.4), (0.75, 1.0, 0.75), "FF_darksteel", bevel=0.01)
for i in range(3):
    cyl(C, "Beaker", 0.06, 0.05, 0.18, (0.55 + i * 0.2, 1.04, 0.75), "FF_glass", verts=8)

frame_camera_target(target=(0, 1.0, 0), dist=8.0)
print("lab done")
