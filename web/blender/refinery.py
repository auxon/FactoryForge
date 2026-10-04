# Oil refinery (3x3m): distillation towers, brass trays, heater, pipes.
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa
import math as _m

ensure_base_materials()
C = col("FF_refinery")
wipe_collection("FF_refinery")

pad(C, 3.0, 3.0)
cyl(C, "TowerMain", 0.52, 0.58, 2.75, (-0.7, 0.15, -0.55), "FF_iron", verts=18)
for i in range(5):
    cyl(C, "TrayRing", 0.58, 0.58, 0.06, (-0.7, 0.65 + i * 0.48, -0.55), "FF_brass", verts=18)
    rivet_ring(C, (-0.7, 0.65 + i * 0.48, -0.55), 0.58, n=8, r=0.018, h=0.025)
sphere(C, "TowerCap", 0.5, (-0.7, 2.95, -0.55), "FF_copper", verts=14)
cyl(C, "TowerSecond", 0.4, 0.45, 1.85, (0.72, 0.15, -0.65), "FF_iron", verts=16)
for i in range(3):
    cyl(C, "TrayRing2", 0.46, 0.46, 0.05, (0.72, 0.55 + i * 0.48, -0.65), "FF_brass", verts=16)

for y in (1.75, 2.45):
    pipe(C, "Crossover", 0.07, (-0.7, y, -0.55), (0.72, y, -0.65), "FF_copper")

box(C, "Heater", (1.15, 0.95, 0.88), (0.28, 0.62, 0.88), "FF_rust", bevel=0.04)
box(C, "HeaterDoor", (0.48, 0.45, 0.07), (0.28, 0.52, 1.32), "FF_soot", bevel=0.015)
glow_plane(C, "GlowFire", 0.32, 0.28, (0.28, 0.52, 1.38))
chimney(C, (0.85, 1.1, 0.7), r=0.11, h=1.35, material="FF_rust")

box(C, "Platform", (2.5, 0.07, 0.65), (0, 1.68, -0.55), "FF_iron", bevel=0.008)
for ix in range(6):
    box(C, "RailPost", (0.04, 0.45, 0.04), (-1.15 + ix * 0.46, 1.92, -0.28), "FF_brass", bevel=0.004)
box(C, "RailTop", (2.5, 0.04, 0.04), (0, 2.16, -0.28), "FF_brass", bevel=0.004)
lamp(C, (1.12, 1.28, 0.85), r=0.06)
gauge(C, (0.85, 0.95, 1.2), facing="z", r=0.07)
valve(C, (0.0, 1.95, -0.15), r=0.09)
# catwalk stairs hint
box(C, "Stair", (0.35, 0.08, 0.7), (-1.2, 0.9, 0.4), "FF_iron", bevel=0.008)

frame_camera_target(target=(0, 1.3, 0), dist=8.5)
print("refinery done")
