# Laser turret (2x2m): brass coil emitter, capacitor jars, rotating Head.
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa
import math as _m

ensure_base_materials()
C = col("FF_laser_turret")
wipe_collection("FF_laser_turret")

pad(C, 2.0, 2.0)
cyl(C, "Pedestal", 0.42, 0.55, 0.88, (0, 0.14, 0), "FF_iron", verts=18)
rivet_ring(C, (0, 0.55, 0), 0.48, n=8, r=0.025, h=0.03)
box(C, "CapBank", (1.08, 0.55, 0.48), (0, 0.52, -0.62), "FF_iron", bevel=0.03)
for i in range(3):
    cyl(C, "Jar", 0.1, 0.1, 0.42, (-0.32 + i * 0.32, 0.42, -0.62), "FF_glass", verts=10)
    cyl(C, "Capacitor", 0.06, 0.06, 0.35, (-0.32 + i * 0.32, 0.55, -0.62), "FF_copper", verts=8)
box(C, "CapTop", (1.12, 0.07, 0.52), (0, 0.88, -0.62), "FF_brass")

box(C, "YokeL", (0.12, 0.48, 0.28), (-0.38, 1.22, 0), "FF_brass", bevel=0.02)
box(C, "YokeR", (0.12, 0.48, 0.28), (0.38, 1.22, 0), "FF_brass", bevel=0.02)
head = box(C, "Head", (0.52, 0.42, 0.66), (0, 1.22, 0.08), "FF_iron", bevel=0.045)
em = cyl(C, "Emitter", 0.14, 0.18, 0.28, (0, 1.22, 0.48), "FF_brass", verts=14, centered=True)
em.rotation_euler = (_m.pi / 2, 0, 0)
parent_keep(em, head)
gl = glow_plane(C, "GlowLens", 0.18, 0.18, (0, 1.22, 0.64))
parent_keep(gl, head)
fin = box(C, "HeadFin", (0.09, 0.28, 0.45), (0, 1.42, -0.08), "FF_copper", bevel=0.015)
parent_keep(fin, head)
coil = torus(C, "HeadCoil", 0.2, 0.035, (0, 1.22, 0.35), "FF_copper", major_seg=14, minor_seg=6)
parent_keep(coil, head)

c = cyl(C, "PowerCable", 0.035, 0.035, 0.65, (-0.48, 0.2, -0.38), "FF_copper", verts=8)
c.rotation_euler = (0, 0, 0.45)
lamp(C, (0.52, 0.98, -0.62), r=0.055)

frame_camera_target(target=(0, 0.9, 0), dist=6.0)
print("laser turret done")
