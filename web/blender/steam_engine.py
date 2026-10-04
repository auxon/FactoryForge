# Steam engine (3x5m): lagged cylinder, brass fittings, spinning flywheel.
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
C = col("FF_steam_engine")
wipe_collection("FF_steam_engine")

pad(C, 3.0, 5.0)

# heavy frame rails
for sx in (-1.15, 1.15):
    box(C, "FrameRail", (0.22, 0.28, 4.6), (sx, 0.28, 0), "FF_darkiron", bevel=0.02)
    rivet_row(C, (sx, 0.44, -2.1), (sx, 0.44, 2.1), n=8, r=0.028)

# lagged high-pressure cylinder (front)
box(C, "CylBlock", (1.7, 1.15, 1.7), (0, 0.82, 1.45), "FF_brass", bevel=0.05)
lagging(C, (0, 0.82, 1.45), 1.5, 0.72, n=6, axis="z")
rivet_row(C, (-0.75, 1.25, 2.25), (0.75, 1.25, 2.25), n=6, r=0.03)
# cylinder head + glands
cyl(C, "CylHead", 0.62, 0.62, 0.18, (0, 0.55, 2.22), "FF_brass", verts=16, centered=True)
_ch = bpy.context.view_layer.objects.active
_ch.rotation_euler = (_m.pi / 2, 0, 0)
flange(C, (0, 0.82, 2.32), r=0.42, axis="z", material="FF_brass")

# steam dome + whistle
cyl(C, "Dome", 0.32, 0.36, 0.45, (0, 1.38, 1.45), "FF_brass", verts=16)
sphere(C, "DomeCap", 0.32, (0, 1.88, 1.45), "FF_brass_polish", verts=14)
cyl(C, "Whistle", 0.04, 0.05, 0.28, (0.18, 1.85, 1.45), "FF_brass_polish", verts=8)
box(C, "WhistleSlot", (0.08, 0.04, 0.04), (0.18, 2.08, 1.45), "FF_bronze", bevel=0.005)

# inlet manifold + valves
pipe(C, "Inlet", 0.08, (0.55, 1.55, 2.15), (0.55, 1.55, 2.55), "FF_copper")
pipe(C, "InletDrop", 0.08, (0.55, 1.55, 2.55), (0.55, 1.15, 2.55), "FF_copper")
valve(C, (0.55, 1.72, 2.35), r=0.11)
gauge(C, (0.72, 1.15, 2.28), facing="z", r=0.09)

# crosshead / slide bars
for sx in (-0.28, 0.28):
    box(C, "Slide", (0.08, 0.08, 1.3), (sx, 0.62, 0.45), "FF_iron", bevel=0.006)
box(C, "Crosshead", (0.55, 0.22, 0.28), (0, 0.62, 0.55), "FF_brass", bevel=0.02)

# crank shaft
shaft = cyl(C, "Shaft", 0.08, 0.08, 2.3, (0, 0.72, -0.15), "FF_darkiron", verts=10, centered=True)
shaft.rotation_euler = (0, _m.pi / 2, 0)

# flywheel (animated Wheel) — heavy rim, spokes, counterweight
wheel = torus(C, "Wheel", 0.82, 0.11, (1.22, 0.72, -0.15), "FF_soot",
              major_seg=28, minor_seg=10, rot=(0, _m.pi / 2, 0))
for a in range(6):
    sp = box(C, "Spoke", (0.07, 1.45, 0.07), (1.22, 0.72, -0.15), "FF_iron", bevel=0.008)
    sp.rotation_euler = (a * _m.pi / 6, 0, 0)
    parent_keep(sp, wheel)
cw = box(C, "Counter", (0.16, 0.38, 0.22), (1.22, 0.38, -0.15), "FF_bronze", bevel=0.02)
parent_keep(cw, wheel)
hub = cyl(C, "WheelHub", 0.16, 0.16, 0.22, (1.22, 0.72, -0.15), "FF_brass", verts=12, centered=True)
hub.rotation_euler = (0, _m.pi / 2, 0)
parent_keep(hub, wheel)

# connecting rod (visual, not animated independently)
box(C, "ConRod", (0.1, 0.1, 1.15), (0.55, 0.7, 0.15), "FF_iron", bevel=0.01)

# generator / dynamo hall (rear)
box(C, "GenHall", (2.35, 1.45, 2.15), (0, 0.95, -1.35), "FF_iron", bevel=0.05)
box(C, "GenRoof", (2.5, 0.12, 2.3), (0, 1.74, -1.35), "FF_copper")
rivet_row(C, (-1.05, 1.55, -0.3), (1.05, 1.55, -0.3), n=7, r=0.028)
for i in range(4):
    box(C, "Louver", (0.55, 0.07, 0.05), (-0.55, 0.85 + i * 0.18, -0.26), "FF_brass", bevel=0.004)
# dynamo drum
cyl(C, "Dynamo", 0.42, 0.42, 1.1, (0, 0.85, -1.35), "FF_brass", verts=16, centered=True)
_dyn = bpy.context.view_layer.objects.active
_dyn.rotation_euler = (0, _m.pi / 2, 0)
# copper windings
cyl(C, "Windings", 0.44, 0.44, 0.35, (0, 0.85, -1.35), "FF_copper", verts=16, centered=True)
bpy.context.view_layer.objects.active.rotation_euler = (0, _m.pi / 2, 0)

# exhaust stack + steam
chimney(C, (-0.85, 1.4, 1.1), r=0.13, h=1.35, material="FF_rust")
pipe(C, "Exhaust", 0.07, (-0.85, 1.4, 1.45), (-0.85, 1.4, 1.1), "FF_copper")

# nameplate, lamp, oil cups
box(C, "Nameplate", (0.7, 0.16, 0.03), (0, 0.95, 2.28), "FF_brass_polish", bevel=0.006)
lamp(C, (1.05, 1.45, -0.28), r=0.07)
cyl(C, "OilCup", 0.04, 0.05, 0.1, (-0.7, 1.4, 1.7), "FF_brass_polish", verts=8)
gauge(C, (-0.85, 1.05, 2.22), facing="z", r=0.08)

box(C, "Stripe", (3.0, 0.02, 0.1), (0, 0.15, 2.42), "FF_bronze", bevel=0.004)

frame_camera_target(target=(0, 0.9, 0), dist=10.0)
print("steam engine done")
