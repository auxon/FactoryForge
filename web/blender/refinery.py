# Oil refinery (3x3m): 2 distillation towers, crossover pipes, platform.
import sys
sys.path.insert(0, "/home/rah/factoryforge/web/blender")
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa
import math as _m

ensure_base_materials()
C = col("FF_refinery")
wipe_collection("FF_refinery")

pad(C, 3.0, 3.0)
# main fractionator (tall) + secondary (short) with tray rings
cyl(C, "TowerMain", 0.55, 0.62, 2.8, (-0.7, 0.15, -0.6), "FF_refpurple", verts=20)
for i in range(4):
    cyl(C, "TrayRing", 0.6, 0.6, 0.07, (-0.7, 0.7 + i * 0.55, -0.6), "FF_darksteel", verts=20)
sphere(C, "TowerCap", 0.55, (-0.7, 2.95, -0.6), "FF_steel")
cyl(C, "TowerSecond", 0.42, 0.48, 1.9, (0.75, 0.15, -0.7), "FF_refpurple", verts=18)
for i in range(3):
    cyl(C, "TrayRing2", 0.47, 0.47, 0.06, (0.75, 0.6 + i * 0.5, -0.7), "FF_darksteel", verts=18)
# crossover pipes between towers (2 levels)
for y in (1.83, 2.63):
    p = cyl(C, "Crossover", 0.08, 0.08, 1.45, (-0.7, y, -0.7), "FF_copper", verts=10, centered=True)
    p.rotation_euler = (0, _m.pi / 2, 0)
# furnace box (front) with fire mouth
box(C, "Heater", (1.2, 1.0, 0.9), (0.3, 0.65, 0.85), "rusty_metal_02", bevel=0.05)
box(C, "HeaterDoor", (0.5, 0.5, 0.08), (0.3, 0.55, 1.32), "FF_darksteel", bevel=0.02)
glow_plane(C, "GlowFire", 0.35, 0.3, (0.3, 0.55, 1.37))
chimney(C, (0.9, 1.15, 0.7), r=0.12, h=1.4, material="rusty_metal_02")
# platform + railing + lamp
box(C, "Platform", (2.6, 0.08, 0.7), (0, 1.7, -0.6), "metal_plate", bevel=0.01)
for ix in range(6):
    box(C, "RailPost", (0.05, 0.5, 0.05), (-1.2 + ix * 0.48, 1.95, -0.3), "FF_hazard", bevel=0.005)
box(C, "RailTop", (2.6, 0.05, 0.05), (0, 2.2, -0.3), "FF_hazard", bevel=0.005)
sphere(C, "Lamp", 0.07, (1.15, 1.3, 0.85), "FF_greenlamp")

frame_camera_target(target=(0, 1.3, 0), dist=8.5)
print("refinery done")
