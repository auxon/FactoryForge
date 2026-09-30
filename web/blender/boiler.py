# Boiler (2x3m): firebox, water drum, tall stack, pipe stubs, ember glow.
import sys
sys.path.insert(0, "/home/rah/factoryforge/web/blender")
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa

ensure_base_materials()
C = col("FF_boiler")
wipe_collection("FF_boiler")

pad(C, 2.0, 3.0)
# firebox (front) + water drum (rear)
box(C, "Firebox", (1.5, 1.0, 1.1), (0, 0.65, 0.85), "rusty_metal_02", bevel=0.05)
box(C, "FireDoor", (0.7, 0.6, 0.1), (0, 0.55, 1.42), "FF_darksteel", bevel=0.02)
glow_plane(C, "GlowFire", 0.5, 0.35, (0, 0.55, 1.48))
cyl(C, "Drum", 0.65, 0.65, 1.5, (0, 0.35, -0.7), "FF_steel", verts=20)
# rotate drum axis along X: Z-cylinder -> rotate about Y
import math as _m
_drum = bpy.data.objects.get("Drum")
_drum.rotation_euler = (0, _m.pi / 2, 0)
box(C, "DrumSaddleL", (0.15, 0.4, 1.3), (-0.6, 0.2, -0.7), "FF_darksteel")
box(C, "DrumSaddleR", (0.15, 0.4, 1.3), (0.6, 0.2, -0.7), "FF_darksteel")
# stack on firebox
chimney(C, (0.5, 1.15, 0.85), r=0.16, h=1.8, material="rusty_metal_02")
# steam pipe stub (rear) + water inlet
_p = cyl(C, "SteamStub", 0.11, 0.11, 0.7, (0, 1.35, -0.7), "FF_copper", verts=12)
box(C, "ValveWheel", (0.22, 0.05, 0.22), (0, 1.75, -0.7), "FF_redlamp", bevel=0.01)
cyl(C, "WaterInlet", 0.09, 0.09, 0.6, (-0.85, 0.35, -0.7), "FF_steel", verts=10)
# rivets + stripe
for i in range(4):
    bolt(C, (-0.6 + i * 0.4, 1.2, 1.42), r=0.04)
box(C, "Stripe", (2.0, 0.02, 0.12), (0, 0.16, 1.44), "FF_hazard", bevel=0.005)

frame_camera_target(target=(0, 0.9, 0), dist=7.0)
print("boiler done")
