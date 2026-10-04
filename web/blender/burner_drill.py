# Burner mining drill (2x2m): rusted derrick, auger Rotor, firebox, chimney.
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa
import math as _m
import bpy

ensure_base_materials()
C = col("FF_burner_drill")
wipe_collection("FF_burner_drill")

pad(C, 2.0, 2.0)

# derrick posts + cross braces
for sx in (-0.78, 0.78):
    for sz in (-0.78, 0.78):
        box(C, "Post", (0.14, 1.55, 0.14), (sx, 0.92, sz), "FF_rust", bevel=0.015)
        bolt(C, (sx, 0.2, sz), r=0.04)
ibeam(C, "Top", 1.7, (0, 1.72, 0), "FF_darkiron", axis="x")
ibeam(C, "TopZ", 1.7, (0, 1.72, 0), "FF_darkiron", axis="z")
# X braces
for s in (-1, 1):
    br = box(C, "Brace", (0.07, 0.07, 1.55), (s * 0.78, 1.0, 0), "FF_iron", bevel=0.006)
    br.rotation_euler = (0.45, 0, 0)

# housing
box(C, "Housing", (1.1, 0.82, 1.1), (0, 0.62, 0), "FF_rust", bevel=0.04)
box(C, "HousingBand", (1.18, 0.1, 1.18), (0, 0.95, 0), "FF_brass")
rivet_row(C, (-0.5, 0.95, 0.58), (0.5, 0.95, 0.58), n=5, r=0.026)
box(C, "PanelL", (0.05, 0.55, 0.72), (-0.58, 0.7, 0), "FF_iron", bevel=0.008)
box(C, "PanelR", (0.05, 0.55, 0.72), (0.58, 0.7, 0), "FF_iron", bevel=0.008)

# Rotor: mast + helical bit + drive gear
rotor = cyl(C, "Rotor", 0.08, 0.08, 1.85, (0, -0.45, 0), "FF_iron", verts=10)
bit = cyl(C, "Bit", 0.03, 0.2, 0.65, (0, -0.5, 0), "FF_soot", verts=8)
parent_keep(bit, rotor)
# flighting
for i in range(5):
    fl = torus(C, "Flight", 0.16, 0.03, (0, 0.15 + i * 0.18, 0), "FF_iron",
               major_seg=10, minor_seg=6)
    fl.rotation_euler = (0, 0, i * 0.4)
    parent_keep(fl, rotor)
gear(C, "DriveGear", 0.28, 12, 0.08, (0, 1.55, 0), "FF_brass", axis="y")
# parent gear objects that sit on the rotor axis? Drive gear is static on the frame.

# firebox + glow + chimney + hopper
box(C, "Firebox", (0.52, 0.48, 0.48), (0.0, 0.4, 0.82), "FF_soot", bevel=0.02)
glow_plane(C, "GlowFire", 0.36, 0.26, (0, 0.4, 1.08))
chimney(C, (0.52, 0.62, -0.72), r=0.12, h=1.65, material="FF_rust")
box(C, "Hopper", (0.48, 0.42, 0.52), (-0.52, 1.18, -0.68), "FF_rust", bevel=0.03)
box(C, "HopperLip", (0.56, 0.07, 0.6), (-0.52, 1.4, -0.68), "FF_brass")
pipe(C, "SteamPipe", 0.05, (0.25, 1.05, 0.55), (0.52, 1.05, -0.4), "FF_copper")
valve(C, (0.4, 1.18, 0.1), r=0.08)
gauge(C, (0.58, 0.85, 0.55), facing="z", r=0.07)
lamp(C, (0.55, 1.15, 0.55), r=0.05)
box(C, "Stripe", (2.0, 0.02, 0.1), (0, 0.15, 0.94), "FF_bronze", bevel=0.004)

frame_camera_target(target=(0, 1.0, 0), dist=6.5)
print("burner drill done")
