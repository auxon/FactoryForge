# Accumulator (2x2m): battery bank, charge bar Glow, terminals, vents.
import sys
sys.path.insert(0, "/home/rah/factoryforge/web/blender")
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa

ensure_base_materials()
C = col("FF_accumulator")
wipe_collection("FF_accumulator")

pad(C, 2.0, 2.0)
box(C, "Bank", (1.6, 1.1, 1.6), (0, 0.7, 0), "FF_chemgreen", bevel=0.06)
box(C, "BankBase", (1.7, 0.15, 1.7), (0, 0.22, 0), "FF_darksteel")
# cell caps row
for i in range(4):
    cyl(C, "CellCap", 0.09, 0.09, 0.1, (-0.6 + i * 0.4, 1.25, 0), "FF_copper", verts=10)
# charge bar (front, emissive green)
box(C, "ChargeBar", (1.2, 0.16, 0.06), (0, 0.95, 0.82), "FF_greenlamp", bevel=0.01)
box(C, "ChargeFrame", (1.34, 0.28, 0.05), (0, 0.95, 0.79), "FF_darksteel", bevel=0.01)
# terminals + cables + vents
for s in (-1, 1):
    cyl(C, "Terminal", 0.06, 0.08, 0.25, (s * 0.5, 1.25, -0.5), "FF_copper", verts=8)
    box(C, "Vent", (0.3, 0.4, 0.06), (s * 0.5, 0.7, -0.81), "FF_darksteel", bevel=0.01)
sphere(C, "Lamp", 0.06, (0.6, 1.35, 0.6), "FF_greenlamp")

frame_camera_target(target=(0, 0.7, 0), dist=6.0)
print("accumulator done")
