# Electric furnace (3x3m): big industrial oven, element Glow strips, cabinet.
import sys
sys.path.insert(0, "/home/rah/factoryforge/web/blender")
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa

ensure_base_materials()
C = col("FF_electric_furnace")
wipe_collection("FF_electric_furnace")

pad(C, 3.0, 3.0)
# main oven block
box(C, "Body", (2.4, 1.7, 2.4), (0, 1.0, 0), "FF_lightsteel", bevel=0.06)
box(C, "BaseFrame", (2.55, 0.25, 2.55), (0, 0.27, 0), "FF_darksteel")
box(C, "TopCap", (2.55, 0.2, 2.55), (0, 1.95, 0), "FF_darksteel")
# door + heating element strips (emissive)
box(C, "Door", (1.2, 1.1, 0.12), (0, 0.95, 1.2), "FF_darksteel", bevel=0.03)
for i in range(3):
    glow_plane(C, f"GlowElement{i}", 0.9, 0.12, (0, 0.7 + i * 0.28, 1.28))
box(C, "DoorFrame", (1.4, 1.3, 0.08), (0, 0.95, 1.18), "FF_steel", bevel=0.02)
# roof vents + exhaust
for sx in (-0.7, 0.7):
    box(C, "RoofVent", (0.5, 0.25, 0.5), (sx, 2.15, -0.6), "FF_darksteel", bevel=0.02)
chimney(C, (0.8, 2.05, -0.8), r=0.14, h=0.9, material="FF_steel")
# control cabinet + lamp + coil details
box(C, "Cabinet", (0.6, 1.2, 0.5), (-1.35, 0.75, 0.6), "FF_bluepaint", bevel=0.04)
sphere(C, "Lamp", 0.07, (-1.35, 1.45, 0.6), "FF_greenlamp")
cyl(C, "Coil", 0.16, 0.16, 0.9, (1.32, 0.5, -0.8), "FF_copper", verts=14)
box(C, "Stripe", (3.0, 0.02, 0.14), (0, 0.16, 1.43), "FF_hazard", bevel=0.005)

frame_camera_target(target=(0, 1.1, 0), dist=8.0)
print("electric furnace done")
