# Electric mining drill (3x3m): blue rig, motor + copper coils, big Rotor.
import sys
sys.path.insert(0, "/home/rah/factoryforge/web/blender")
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa

ensure_base_materials()
C = col("FF_electric_drill")
wipe_collection("FF_electric_drill")

pad(C, 3.0, 3.0)
for sx in (-1.25, 1.25):
    for sz in (-1.25, 1.25):
        box(C, "Post", (0.2, 2.2, 0.2), (sx, 1.25, sz), "FF_bluepaint")
        bolt(C, (sx, 0.2, sz))
box(C, "TopFrame", (2.8, 0.22, 2.8), (0, 2.4, 0), "FF_darksteel")
# main housing
box(C, "Housing", (1.7, 1.2, 1.7), (0, 0.95, 0), "FF_bluepaint", bevel=0.06)
box(C, "HousingBand", (1.78, 0.16, 1.78), (0, 0.45, 0), "FF_darksteel")
# vent slats
for i in range(4):
    box(C, "Vent", (0.7, 0.08, 0.06), (-0.45, 0.9 + i * 0.16, 0.86), "FF_darksteel", bevel=0.01)
# motor + copper coils on top
cyl(C, "Motor", 0.45, 0.5, 0.7, (0, 1.55, 0), "FF_darksteel", verts=20)
cyl(C, "Coil", 0.47, 0.47, 0.3, (0, 1.62, 0), "FF_copper", verts=20)
sphere(C, "MotorCap", 0.3, (0, 1.95, 0), "FF_bluepaint")
# Rotor: heavy auger
cyl(C, "Rotor", 0.12, 0.12, 2.6, (0, -0.7, 0), "FF_steel", verts=12)
cyl(C, "RotorBit", 0.03, 0.3, 0.9, (0, -0.75, 0), "FF_darksteel", verts=12)
# side cabinet + lamp + stripes
box(C, "Cabinet", (0.5, 0.9, 0.7), (1.05, 0.6, -1.0), "FF_bluepaint", bevel=0.04)
sphere(C, "Lamp", 0.07, (1.05, 1.15, -1.0), "FF_greenlamp")
box(C, "Stripe", (3.0, 0.02, 0.14), (0, 0.16, 1.43), "FF_hazard", bevel=0.005)

frame_camera_target(target=(0, 1.2, 0), dist=8.0)
print("electric drill done")
