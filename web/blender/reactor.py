# Nuclear reactor (5x5m): iron containment, brass dome, glowing core, pipes.
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa
import math as _m

ensure_base_materials()
C = col("FF_reactor")
wipe_collection("FF_reactor")

pad(C, 5.0, 5.0)
cyl(C, "Containment", 1.55, 1.65, 2.55, (0, 0.14, 0), "FF_iron", verts=28)
sphere(C, "Dome", 1.55, (0, 2.7, 0), "FF_copper", scale=(1, 0.52, 1), verts=28)
cyl(C, "DomeRim", 1.62, 1.62, 0.1, (0, 2.68, 0), "FF_brass", verts=28)
rivet_ring(C, (0, 2.68, 0), 1.6, n=16, r=0.03, h=0.04)
for i in range(8):
    a = i * _m.pi / 4
    glow_plane(C, f"GlowCore{i}", 0.36, 0.22,
               (1.62 * _m.cos(a), 1.45, 1.62 * _m.sin(a)), rot_y=_m.pi / 2 - a)
    rivet_row(C, (1.58 * _m.cos(a), 0.5, 1.58 * _m.sin(a)),
              (1.58 * _m.cos(a), 2.3, 1.58 * _m.sin(a)), n=5, r=0.02)
for i in range(4):
    a = i * _m.pi / 2 + _m.pi / 4
    x, z = 1.95 * _m.cos(a), 1.95 * _m.sin(a)
    cyl(C, "CoolPipe", 0.11, 0.11, 2.15, (x, 0.14, z), "FF_copper", verts=12)
    flange(C, (x, 2.25, z), r=0.16, axis="y", material="FF_brass")
box(C, "Annex", (1.35, 1.05, 0.95), (0, 0.68, 2.25), "FF_iron", bevel=0.04)
box(C, "AnnexDoor", (0.48, 0.75, 0.07), (0, 0.52, 2.74), "FF_darkiron", bevel=0.015)
valve(C, (0.55, 1.25, 2.25), r=0.1)
lamp(C, (0.58, 1.32, 2.25), r=0.065)
gauge(C, (-0.5, 1.05, 2.74), facing="z", r=0.08)
for i in range(12):
    a = i * _m.pi / 6
    box(C, "RingDash", (0.48, 0.02, 0.16), (2.85 * _m.cos(a), 0.15, 2.85 * _m.sin(a)),
        "FF_bronze", bevel=0.004)

frame_camera_target(target=(0, 1.5, 0), dist=13.0)
print("reactor done")
