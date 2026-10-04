# Player: riveted steampunk engineer (~1.28m). Faces +Z. Visor + lamp glow.
import os
import sys
import math as _m

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa

ensure_base_materials()
C = col("FF_player")
wipe_collection("FF_player")

# ---- legs ----
for sx in (-0.11, 0.11):
    box(C, "Boot", (0.17, 0.10, 0.26), (sx, 0.05, 0.03), "FF_darkiron", bevel=0.02)
    box(C, "ToeCap", (0.15, 0.05, 0.08), (sx, 0.07, 0.14), "FF_brass", bevel=0.01)
    rivet_row(C, (sx - 0.05, 0.10, 0.14), (sx + 0.05, 0.10, 0.14), n=3, r=0.012, h=0.02)
    cyl(C, "Calf", 0.055, 0.068, 0.22, (sx, 0.10, 0.0), "FF_iron", verts=10)
    box(C, "Greave", (0.10, 0.14, 0.08), (sx, 0.22, 0.05), "FF_brass", bevel=0.012)
    sphere(C, "Knee", 0.07, (sx, 0.34, 0.02), "FF_darkiron", verts=12)
    bolt(C, (sx, 0.34, 0.08), r=0.016, h=0.03)
    cyl(C, "Thigh", 0.068, 0.058, 0.20, (sx, 0.38, 0.0), "FF_iron", verts=10)
    box(C, "ThighPlate", (0.10, 0.12, 0.06), (sx, 0.48, 0.05), "FF_leather", bevel=0.01)

# hips + belt
box(C, "Hips", (0.36, 0.15, 0.24), (0, 0.64, 0.0), "FF_darkiron", bevel=0.03)
box(C, "Cod", (0.16, 0.10, 0.08), (0, 0.60, 0.12), "FF_brass", bevel=0.012)
box(C, "Belt", (0.38, 0.07, 0.26), (0, 0.73, 0.0), "FF_leather", bevel=0.012)
box(C, "Buckle", (0.10, 0.06, 0.04), (0, 0.73, 0.14), "FF_brass_polish", bevel=0.006)
rivet_row(C, (-0.14, 0.73, 0.14), (0.14, 0.73, 0.14), n=4, r=0.012, h=0.018)

# hip pouches
box(C, "PouchL", (0.08, 0.10, 0.06), (-0.20, 0.66, 0.10), "FF_leather", bevel=0.01)
box(C, "PouchR", (0.08, 0.10, 0.06), (0.20, 0.66, 0.10), "FF_leather", bevel=0.01)

# torso armor
box(C, "Torso", (0.40, 0.38, 0.26), (0, 0.96, 0.0), "FF_iron", bevel=0.04)
box(C, "ChestPlate", (0.30, 0.26, 0.05), (0, 0.98, 0.14), "FF_brass", bevel=0.016)
rivet_row(C, (-0.12, 1.08, 0.17), (0.12, 1.08, 0.17), n=4, r=0.014, h=0.02)
rivet_row(C, (-0.12, 0.88, 0.17), (0.12, 0.88, 0.17), n=4, r=0.014, h=0.02)
gauge(C, (0.10, 1.00, 0.18), facing="z", r=0.045)
box(C, "Collar", (0.22, 0.06, 0.18), (0, 1.16, 0.02), "FF_darkiron", bevel=0.012)
# abdomen piston
cyl(C, "BellyPiston", 0.04, 0.04, 0.10, (0, 0.80, 0.12), "FF_copper", verts=8)

# backpack + tanks
box(C, "Pack", (0.30, 0.34, 0.16), (0, 0.96, -0.20), "FF_darkiron", bevel=0.03)
rivet_row(C, (-0.10, 1.10, -0.28), (0.10, 1.10, -0.28), n=3, r=0.012, h=0.018)
for sx in (-0.09, 0.09):
    cyl(C, "Tank", 0.055, 0.055, 0.30, (sx, 0.82, -0.30), "FF_copper", verts=12)
    sphere(C, "TankCap", 0.055, (sx, 1.14, -0.30), "FF_brass", verts=10)
    bolt(C, (sx, 1.18, -0.30), r=0.014, h=0.03)
pipe(C, "TankPipe", 0.018, (-0.09, 1.12, -0.30), (0.09, 1.12, -0.30), "FF_copper", verts=8)
valve(C, (0.0, 1.18, -0.30), r=0.05)

# arms
for s in (-1, 1):
    sphere(C, "Shoulder", 0.10, (s * 0.26, 1.12, 0.0), "FF_darkiron", verts=12)
    box(C, "Pauldron", (0.14, 0.08, 0.16), (s * 0.28, 1.18, 0.0), "FF_brass", bevel=0.014)
    rivet_row(C, (s * 0.28, 1.22, -0.05), (s * 0.28, 1.22, 0.05), n=3, r=0.012, h=0.018)
    arm = cyl(C, "UpperArm", 0.055, 0.048, 0.20, (s * 0.30, 0.88, 0.02), "FF_iron", verts=10)
    arm.rotation_euler = (0, 0, s * -0.10)
    sphere(C, "Elbow", 0.055, (s * 0.32, 0.86, 0.03), "FF_darkiron", verts=10)
    fore = cyl(C, "Forearm", 0.048, 0.042, 0.18, (s * 0.33, 0.68, 0.04), "FF_iron", verts=10)
    fore.rotation_euler = (0.12, 0, s * -0.08)
    box(C, "Gauntlet", (0.10, 0.12, 0.12), (s * 0.34, 0.64, 0.06), "FF_leather", bevel=0.016)
    box(C, "Cuff", (0.11, 0.04, 0.12), (s * 0.34, 0.70, 0.05), "FF_brass", bevel=0.008)

# shoulder lamp (anim prefix Lamp*)
lamp(C, (-0.28, 1.24, 0.08), material="FF_amber", r=0.035)
box(C, "LampCage", (0.06, 0.06, 0.06), (-0.28, 1.24, 0.08), "FF_brass", bevel=0.004)

# helmet + goggles
sphere(C, "Helmet", 0.155, (0, 1.28, 0.0), "FF_iron", scale=(1.05, 1.0, 1.1), verts=16)
box(C, "HelmRidge", (0.06, 0.08, 0.22), (0, 1.40, -0.02), "FF_brass", bevel=0.01)
for sx in (-0.055, 0.055):
    rim = cyl(C, "GoggleRim", 0.05, 0.05, 0.03, (sx, 1.28, 0.13),
              "FF_brass_polish", verts=12, centered=True)
    rim.rotation_euler = (_m.pi / 2, 0, 0)
    lens = cyl(C, "Visor", 0.038, 0.038, 0.016, (sx, 1.28, 0.145),
               "FF_visor", verts=12, centered=True)
    lens.rotation_euler = (_m.pi / 2, 0, 0)
box(C, "GoggleBridge", (0.05, 0.025, 0.03), (0, 1.28, 0.14), "FF_brass", bevel=0.004)
# chin guard
box(C, "Chin", (0.16, 0.06, 0.10), (0, 1.18, 0.08), "FF_darkiron", bevel=0.012)

# antenna
cyl(C, "Antenna", 0.010, 0.010, 0.22, (0.10, 1.38, -0.06), "FF_darkiron", verts=6)
sphere(C, "LampAntenna", 0.022, (0.10, 1.60, -0.06), "FF_redlamp", verts=8)

frame_camera_target(target=(0, 0.7, 0), dist=3.4)
print("player done")
