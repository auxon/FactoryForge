# Inserter (1x1m): iron base, brass column, swinging Arm + claw.
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa

ensure_base_materials()
C = col("FF_inserter")
wipe_collection("FF_inserter")

box(C, "Base", (0.62, 0.12, 0.62), (0, 0.06, 0), "FF_darkiron", bevel=0.015)
for sx in (-0.22, 0.22):
    for sz in (-0.22, 0.22):
        bolt(C, (sx, 0.14, sz), r=0.03)
cyl(C, "Column", 0.13, 0.17, 0.42, (0, 0.12, 0), "FF_brass", verts=12)
sphere(C, "Pivot", 0.12, (0, 0.6, 0), "FF_bronze", verts=12)
box(C, "Motor", (0.28, 0.26, 0.22), (0, 0.42, -0.28), "FF_iron", bevel=0.02)
gear(C, "MotorGear", 0.1, 9, 0.04, (0, 0.55, -0.18), "FF_brass", axis="x")

arm = box(C, "Arm", (0.12, 0.09, 1.25), (0, 0.66, 0.12), "FF_brass", bevel=0.015)
tip = box(C, "ArmTip", (0.18, 0.07, 0.22), (0, 0.66, 0.7), "FF_darkiron", bevel=0.012)
parent_keep(tip, arm)
for s in (-1, 1):
    claw = box(C, "Claw", (0.045, 0.11, 0.16), (s * 0.08, 0.62, 0.76), "FF_iron", bevel=0.006)
    parent_keep(claw, arm)
lamp(C, (0, 0.6, -0.3), r=0.04)
# steam/pneumatic hose
pipe(C, "Hose", 0.025, (0.12, 0.35, -0.28), (0.18, 0.6, 0.05), "FF_copper")

frame_camera_target(target=(0, 0.4, 0), dist=3.5)
print("inserter done")
