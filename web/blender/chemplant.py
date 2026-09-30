# Chemical plant (3x3m): reactor sphere, base block, pipe rack, vent stack.
import sys
sys.path.insert(0, "/home/rah/factoryforge/web/blender")
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa
import math as _m

ensure_base_materials()
plain_material("FF_chemgreen", (0.2, 0.55, 0.3), metallic=0.5, roughness=0.45)
C = col("FF_chemplant")
wipe_collection("FF_chemplant")

pad(C, 3.0, 3.0)
# base block + skirt
box(C, "BaseBlock", (2.2, 0.9, 2.2), (0, 0.6, 0), "FF_chemgreen", bevel=0.06)
box(C, "Skirt", (2.35, 0.18, 2.35), (0, 0.24, 0), "FF_darksteel")
# reactor sphere on top + cap + pipes
sphere(C, "Reactor", 0.95, (0, 1.9, 0), "FF_lightsteel", scale=(1, 1, 1), verts=24)
# weld bands around sphere
for y, r in [(1.45, 0.82), (1.9, 0.95), (2.35, 0.82)]:
    cyl(C, "WeldBand", r, r, 0.05, (0, y - 0.025, 0), "FF_darksteel", verts=24)
cyl(C, "TopNozzle", 0.18, 0.18, 0.4, (0, 2.7, 0), "FF_steel", verts=12)
sphere(C, "NozzleCap", 0.2, (0, 2.92, 0), "FF_copper")
# side pipe rack: 3 horizontal pipes + supports
for i, y in enumerate([0.7, 1.0, 1.3]):
    p = cyl(C, "RackPipe", 0.07, 0.07, 2.6, (-1.25, y, -0.9 + i * 0.15), "FF_copper" if i == 1 else "FF_steel", verts=10)
    p.rotation_euler = (0, _m.pi / 2, 0)
for sx in (-1.25, 0.2):
    box(C, "RackPost", (0.08, 1.5, 0.5), (sx, 0.75, -0.75), "FF_darksteel")
# vent stack + steam wisp + lamp + stripes
chimney(C, (1.0, 1.05, -1.0), r=0.13, h=1.6, material="FF_chemgreen")
sphere(C, "Lamp", 0.07, (-1.0, 1.2, 1.0), "FF_greenlamp")
box(C, "Stripe", (3.0, 0.02, 0.14), (0, 0.16, 1.43), "FF_hazard", bevel=0.005)
# gauge panel
box(C, "Gauges", (0.5, 0.4, 0.08), (-0.6, 0.9, 1.12), "FF_darksteel", bevel=0.02)
for i in range(2):
    cyl(C, "Gauge", 0.07, 0.07, 0.04, (-0.72 + i * 0.24, 0.92, 1.12), "FF_glass", verts=12)

frame_camera_target(target=(0, 1.2, 0), dist=8.5)
print("chemplant done")
