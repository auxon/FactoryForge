# Laser turret (2x2m): pedestal, capacitor bank, rotating Head + emitter lens.
import sys
sys.path.insert(0, "/home/rah/factoryforge/web/blender")
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa
import math as _m

ensure_base_materials()
C = col("FF_laser_turret")
wipe_collection("FF_laser_turret")

pad(C, 2.0, 2.0)
# pedestal + capacitor bank
cyl(C, "Pedestal", 0.45, 0.6, 0.9, (0, 0.15, 0), "FF_pearl", verts=20)
box(C, "CapBank", (1.1, 0.6, 0.5), (0, 0.55, -0.65), "FF_bluepaint", bevel=0.04)
for i in range(3):
    cyl(C, "Capacitor", 0.09, 0.09, 0.5, (-0.35 + i * 0.35, 0.6, -0.65), "FF_copper", verts=10)
box(C, "CapTop", (1.15, 0.08, 0.55), (0, 0.9, -0.65), "FF_darksteel")
# Head (animated aim): yoke + emitter housing + lens Glow
box(C, "YokeL", (0.14, 0.5, 0.3), (-0.4, 1.25, 0), "FF_pearl", bevel=0.03)
box(C, "YokeR", (0.14, 0.5, 0.3), (0.4, 1.25, 0), "FF_pearl", bevel=0.03)
box(C, "Head", (0.55, 0.45, 0.7), (0, 1.25, 0.1), "FF_pearl", bevel=0.06)
cyl(C, "Emitter", 0.16, 0.2, 0.3, (0, 1.25, 0.5), "FF_darksteel", verts=14)
glow_plane(C, "GlowLens", 0.2, 0.2, (0, 1.25, 0.66))
box(C, "HeadFin", (0.1, 0.3, 0.5), (0, 1.45, -0.1), "FF_bluepaint", bevel=0.02)
# power cables + lamp
c = cyl(C, "PowerCable", 0.04, 0.04, 0.7, (-0.5, 0.2, -0.4), "FF_darksteel", verts=8)
c.rotation_euler = (0, 0, 0.5)
sphere(C, "Lamp", 0.06, (0.55, 1.0, -0.65), "FF_greenlamp")

frame_camera_target(target=(0, 0.9, 0), dist=6.0)
print("laser turret done")
