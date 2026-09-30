# Steel furnace (2x2m): dark steel35200 body, brick throat, tall stack.
import sys
sys.path.insert(0, "/home/rah/factoryforge/web/blender")
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa

ensure_base_materials()
C = col("FF_steel_furnace")
wipe_collection("FF_steel_furnace")

pad(C, 2.0, 2.0)
box(C, "Body", (1.6, 1.5, 1.6), (0, 0.9, 0), "FF_darksteel", bevel=0.05)
# brick throat visible at mouth
box(C, "Throat", (0.8, 0.6, 0.12), (0, 0.5, 0.78), "FF_brick", bevel=0.02)
box(C, "MouthInset", (0.6, 0.42, 0.1), (0, 0.48, 0.8), "FF_darksteel", bevel=0.02)
glow_plane(C, "GlowFire", 0.45, 0.3, (0, 0.48, 0.86))
box(C, "Lintel", (0.85, 0.12, 0.18), (0, 0.78, 0.8), "FF_steel")
# hazard bands + rivet rows
box(C, "BandLow", (1.68, 0.14, 1.68), (0, 0.3, 0), "FF_hazard", bevel=0.01)
box(C, "BandHigh", (1.68, 0.14, 1.68), (0, 1.5, 0), "FF_hazard", bevel=0.01)
for i in range(5):
    bolt(C, (-0.7 + i * 0.35, 1.62, 0.82), r=0.04)
# tall stack + cap
chimney(C, (-0.45, 1.65, -0.55), r=0.2, h=1.3, material="FF_darksteel")
# side control box + lamp
box(C, "ControlBox", (0.4, 0.6, 0.3), (0.85, 0.45, -0.5), "FF_steel", bevel=0.03)
sphere(C, "Lamp", 0.06, (0.85, 0.85, -0.5), "FF_greenlamp")

frame_camera_target(target=(0, 0.9, 0), dist=6.0)
print("steel furnace done")
