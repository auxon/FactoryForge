# Rocket silo (9x9m): iron pit, brass gantry, Rocket (animated rise).
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa
import math as _m

ensure_base_materials()
C = col("FF_silo")
wipe_collection("FF_silo")

pad(C, 9.0, 9.0)
cyl(C, "PitRing", 2.15, 2.35, 0.48, (0, 0.14, 0), "FF_darkiron", verts=28)
cyl(C, "PitCollar", 1.65, 1.65, 0.65, (0, 0.14, 0), "FF_brass", verts=28)
rivet_ring(C, (0, 0.6, 0), 1.7, n=16, r=0.03, h=0.04)

# RocketRig groups all rising parts
rig = box(C, "RocketRig", (0.08, 0.08, 0.08), (0, 0.4, 0), "FF_iron", bevel=0.0)
rig.hide_render = True
body = cyl(C, "RocketBody", 0.68, 0.68, 2.55, (0, 0.58, 0), "FF_iron", verts=18)
parent_keep(body, rig)
nose = cone(C, "RocketNose", 0.68, 0.95, (0, 3.15, 0), "FF_copper", verts=18)
parent_keep(nose, rig)
for i in range(4):
    fin = box(C, "RocketFin", (0.07, 0.85, 0.48),
              (0.72 * _m.cos(i * _m.pi / 2), 0.98, 0.72 * _m.sin(i * _m.pi / 2)),
              "FF_brass", bevel=0.015)
    fin.rotation_euler = (0, -i * _m.pi / 2, 0)
    parent_keep(fin, rig)
bell = cyl(C, "RocketBell", 0.48, 0.26, 0.38, (0, 0.24, 0), "FF_soot", verts=14)
parent_keep(bell, rig)
gl = glow_plane(C, "RocketGlow", 0.45, 0.45, (0, 0.2, 0.52))
parent_keep(gl, rig)
# brass banding on rocket
band = cyl(C, "RocketBand", 0.7, 0.7, 0.08, (0, 1.6, 0), "FF_brass", verts=18)
parent_keep(band, rig)

box(C, "Gantry", (0.75, 5.1, 0.75), (-2.55, 2.7, -2.55), "FF_iron", bevel=0.03)
rivet_row(C, (-2.55, 0.5, -2.15), (-2.55, 5.0, -2.15), n=8, r=0.025)
for y in (1.95, 3.3, 4.55):
    arm = box(C, "CraneArm", (2.15, 0.16, 0.16), (-1.45, y, -1.45), "FF_brass", bevel=0.015)
    arm.rotation_euler = (0, 0.6, 0)
box(C, "GantryTop", (0.95, 0.28, 0.95), (-2.55, 5.35, -2.55), "FF_darkiron")
sphere(C, "Beacon", 0.09, (-2.55, 5.6, -2.55), "FF_redlamp", verts=10)
for i in range(8):
    a = i * _m.pi / 4
    box(C, "RingDash", (0.65, 0.02, 0.22), (3.35 * _m.cos(a), 0.15, 3.35 * _m.sin(a)),
        "FF_bronze", bevel=0.004)
for sx, sz in [(-3.9, 3.9), (3.9, -3.9)]:
    cyl(C, "FloodPole", 0.055, 0.075, 2.55, (sx, 0.14, sz), "FF_iron", verts=8)
    sphere(C, "FloodHead", 0.12, (sx, 2.75, sz), "FF_amber", verts=10)

frame_camera_target(target=(0, 2.0, 0), dist=16.0)
print("silo done")
