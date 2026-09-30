# Burner mining drill (2x2m): rusted rig, auger Rotor, firebox Glow, chimney.
import sys
sys.path.insert(0, "/home/rah/factoryforge/web/blender")
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa

ensure_base_materials()
C = col("FF_burner_drill")
wipe_collection("FF_burner_drill")

pad(C, 2.0, 2.0)
# corner posts + top frame
for sx in (-0.8, 0.8):
    for sz in (-0.8, 0.8):
        box(C, "Post", (0.16, 1.5, 0.16), (sx, 0.9, sz), "rusty_metal_02")
        bolt(C, (sx, 0.2, sz))
box(C, "TopFrame", (1.9, 0.18, 1.9), (0, 1.65, 0), "FF_darksteel")
# housing (sits low between posts)
box(C, "Housing", (1.15, 0.85, 1.15), (0, 0.62, 0), "rusty_metal_02", bevel=0.05)
box(C, "HousingBand", (1.22, 0.14, 1.22), (0, 0.32, 0), "FF_darksteel")
# side panels (diamond plate)
box(C, "PanelL", (0.06, 0.7, 0.9), (-0.62, 1.0, 0), "metal_plate")
box(C, "PanelR", (0.06, 0.7, 0.9), (0.62, 1.0, 0), "metal_plate")
# Rotor: auger mast + bit (spins; extends into ground)
cyl(C, "Rotor", 0.09, 0.09, 1.9, (0, -0.5, 0), "FF_steel", verts=10)
cyl(C, "RotorBit", 0.02, 0.22, 0.7, (0, -0.55, 0), "FF_darksteel", verts=10)
# firebox + glow + chimney + hopper
box(C, "Firebox", (0.55, 0.5, 0.5), (0.0, 0.4, 0.85), "FF_darksteel")
glow_plane(C, "GlowFire", 0.4, 0.3, (0, 0.4, 1.11))
chimney(C, (0.55, 0.6, -0.75), r=0.13, h=1.7)
box(C, "Hopper", (0.5, 0.45, 0.6), (-0.55, 1.15, -0.7), "rusty_metal_02", bevel=0.04)
box(C, "HopperLip", (0.6, 0.08, 0.7), (-0.55, 1.4, -0.7), "FF_darksteel")
# hazard stripes on pad edge
box(C, "Stripe", (2.0, 0.02, 0.12), (0, 0.16, 0.94), "FF_hazard", bevel=0.005)

frame_camera_target(target=(0, 1.0, 0), dist=6.5)
print("burner drill done")
