# Inserter (1x1m): base, column, motor housing, swinging Arm + claw tip.
import sys
sys.path.insert(0, "/home/rah/factoryforge/web/blender")
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa

ensure_base_materials()
C = col("FF_inserter")
wipe_collection("FF_inserter")

box(C, "Base", (0.6, 0.14, 0.6), (0, 0.07, 0), "FF_darksteel", bevel=0.02)
for sx in (-0.22, 0.22):
    for sz in (-0.22, 0.22):
        bolt(C, (sx, 0.15, sz), r=0.035)
cyl(C, "Column", 0.14, 0.18, 0.45, (0, 0.14, 0), "FF_hazard", verts=12)
sphere(C, "Pivot", 0.13, (0, 0.62, 0), "FF_darksteel")
# motor housing (back)
box(C, "Motor", (0.3, 0.28, 0.24), (0, 0.45, -0.3), "FF_bluepaint", bevel=0.03)
# Arm (animated swing about Y at pivot height)
box(C, "Arm", (0.14, 0.1, 1.3), (0, 0.68, 0.1), "FF_hazard", bevel=0.02)
box(C, "ArmTip", (0.2, 0.08, 0.24), (0, 0.68, 0.72), "FF_darksteel", bevel=0.02)
for s in (-1, 1):
    box(C, "Claw", (0.05, 0.12, 0.18), (s * 0.09, 0.64, 0.78), "FF_steel", bevel=0.01)
sphere(C, "Lamp", 0.045, (0, 0.62, -0.32), "FF_greenlamp")

frame_camera_target(target=(0, 0.4, 0), dist=3.5)
print("inserter done")
