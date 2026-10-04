# Lab (3x3m): brass instrument bench, glass dome, glowing flask, coils.
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa

ensure_base_materials()
C = col("FF_lab")
wipe_collection("FF_lab")

pad(C, 3.0, 3.0)
box(C, "Base", (2.35, 0.78, 2.35), (0, 0.52, 0), "FF_iron", bevel=0.05)
box(C, "BaseTrim", (2.48, 0.1, 2.48), (0, 0.18, 0), "FF_brass")
rivet_row(C, (-1.05, 0.85, 1.18), (1.05, 0.85, 1.18), n=7, r=0.026)
for s in (-1, 1):
    box(C, "Vent", (0.48, 0.28, 0.05), (s * 0.58, 0.52, 1.18), "FF_darkiron", bevel=0.008)
    box(C, "Panel", (0.38, 0.45, 0.05), (s * 0.58, 0.52, -1.18), "FF_brass", bevel=0.01)

sphere(C, "Dome", 0.98, (0, 0.92, 0), "FF_glass", scale=(1, 0.72, 1), verts=22)
flask = sphere(C, "Flask", 0.3, (0, 1.22, 0), "FF_amber", verts=12)
cyl(C, "FlaskNeck", 0.07, 0.07, 0.28, (0, 1.42, 0), "FF_glass", verts=8)
# mark flask as glow so the view flickers it
flask.name = "GlowFlask"

cyl(C, "Mast", 0.035, 0.045, 1.15, (-0.98, 0.92, -0.98), "FF_iron", verts=8)
sphere(C, "Dish", 0.2, (-0.98, 2.15, -0.98), "FF_copper", scale=(1, 0.48, 1), verts=12)
# Tesla coil
cyl(C, "CoilCol", 0.06, 0.08, 0.7, (0.95, 0.92, -0.95), "FF_wood", verts=8)
torus(C, "CoilTop", 0.18, 0.04, (0.95, 1.65, -0.95), "FF_copper", major_seg=14, minor_seg=6)
lamp(C, (0.98, 1.02, 0.98), r=0.055)
box(C, "Tray", (0.68, 0.07, 0.38), (0.72, 0.98, 0.72), "FF_darkiron", bevel=0.008)
for i in range(3):
    cyl(C, "Beaker", 0.055, 0.045, 0.16, (0.52 + i * 0.18, 1.02, 0.72), "FF_glass", verts=8)
gauge(C, (-0.7, 0.85, 1.2), facing="z", r=0.07)

frame_camera_target(target=(0, 1.0, 0), dist=8.0)
print("lab done")
