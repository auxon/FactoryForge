# Boiler (2x3m): firebox, lagged drum, brass valves, tall stack, ember glow.
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
C = col("FF_boiler")
wipe_collection("FF_boiler")

pad(C, 2.0, 3.0)

# firebox
box(C, "Firebox", (1.55, 1.05, 1.15), (0, 0.68, 0.82), "FF_rust", bevel=0.045)
rivet_row(C, (-0.65, 1.05, 1.38), (0.65, 1.05, 1.38), n=6, r=0.03)
rivet_row(C, (-0.65, 0.42, 1.38), (0.65, 0.42, 1.38), n=6, r=0.028)
box(C, "FireDoor", (0.62, 0.55, 0.08), (0, 0.52, 1.40), "FF_soot", bevel=0.02)
box(C, "DoorHingeL", (0.06, 0.5, 0.08), (-0.36, 0.52, 1.42), "FF_brass", bevel=0.006)
box(C, "DoorHingeR", (0.06, 0.5, 0.08), (0.36, 0.52, 1.42), "FF_brass", bevel=0.006)
glow_plane(C, "GlowFire", 0.48, 0.32, (0, 0.52, 1.46))
grate(C, (0, 0.28, 0.82), 1.2, 0.7)

# water drum (horizontal)
drum = cyl(C, "Drum", 0.58, 0.58, 1.65, (0, 1.15, -0.72), "FF_iron", verts=20, centered=True)
drum.rotation_euler = (0, _m.pi / 2, 0)
lagging(C, (0, 1.15, -0.72), 1.55, 0.58, n=7, axis="x")
# drum heads
for sx in (-0.82, 0.82):
    head = cyl(C, "DrumHead", 0.6, 0.6, 0.08, (sx, 1.15, -0.72), "FF_brass", verts=18, centered=True)
    head.rotation_euler = (0, _m.pi / 2, 0)
    rivet_ring(C, (sx, 1.15, -0.72), 0.48, n=8, r=0.02, h=0.03, plane="yz")
box(C, "DrumSaddleL", (0.14, 0.42, 1.15), (-0.55, 0.36, -0.72), "FF_darkiron")
box(C, "DrumSaddleR", (0.14, 0.42, 1.15), (0.55, 0.36, -0.72), "FF_darkiron")

# steam dome
cyl(C, "Dome", 0.22, 0.24, 0.32, (0, 1.68, -0.55), "FF_brass", verts=14)
sphere(C, "DomeCap", 0.22, (0, 2.04, -0.55), "FF_brass_polish", verts=12)
valve(C, (0, 2.12, -0.55), r=0.1)

# stack
chimney(C, (0.48, 1.2, 0.82), r=0.15, h=1.75, material="FF_rust")
pipe(C, "StackFeed", 0.06, (0.2, 1.55, 0.4), (0.48, 1.55, 0.82), "FF_copper")

# steam outlet + water inlet
pipe(C, "SteamStub", 0.09, (0, 1.85, -1.35), (0, 1.85, -1.65), "FF_copper")
flange(C, (0, 1.85, -1.68), r=0.16, axis="z", material="FF_brass")
pipe(C, "WaterIn", 0.07, (-0.9, 0.42, -0.72), (-0.55, 0.42, -0.72), "FF_iron")
flange(C, (-0.92, 0.42, -0.72), r=0.13, axis="x", material="FF_brass")

# gauges + sight glass
gauge(C, (0.78, 1.05, 0.2), facing="x", r=0.09)
gauge(C, (0.78, 0.78, 0.2), facing="x", r=0.07)
cyl(C, "Sight", 0.035, 0.035, 0.55, (0.72, 0.55, -0.2), "FF_glass", verts=8)
cyl(C, "SightFluid", 0.022, 0.022, 0.32, (0.72, 0.55, -0.2), "FF_verdigris", verts=6)

# coal scuttle
box(C, "Scuttle", (0.45, 0.32, 0.4), (-0.7, 0.32, 1.15), "FF_soot", bevel=0.02)
box(C, "CoalHeap", (0.32, 0.16, 0.28), (-0.7, 0.5, 1.15), "FF_coal", bevel=0.03)

lamp(C, (-0.7, 1.25, 1.15), r=0.055)
box(C, "Stripe", (2.0, 0.02, 0.1), (0, 0.15, 1.44), "FF_bronze", bevel=0.004)

frame_camera_target(target=(0, 0.9, 0), dist=7.0)
print("boiler done")
