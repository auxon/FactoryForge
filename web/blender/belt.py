# Transport belt (1x1m): frame, roller ends, chevron slats, rails.
import sys
sys.path.insert(0, "/home/rah/factoryforge/web/blender")
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa
import math as _m

ensure_base_materials()
C = col("FF_belt")
wipe_collection("FF_belt")

# side frames + legs
for s in (-1, 1):
    box(C, "Rail", (0.1, 0.22, 1.0), (s * 0.42, 0.28, 0), "FF_hazard", bevel=0.01)
    for dz in (-0.4, 0.4):
        box(C, "Leg", (0.08, 0.2, 0.08), (s * 0.42, 0.1, dz), "FF_darksteel")
# roller ends (Z-cylinder rotated about Y -> axis along X, centered)
for dz in (-0.45, 0.45):
    r = cyl(C, "RollerEnd", 0.09, 0.09, 0.74, (0, 0.35, dz), "FF_steel", verts=12, centered=True)
    r.rotation_euler = (0, _m.pi / 2, 0)
# belt bed
box(C, "Bed", (0.74, 0.06, 0.95), (0, 0.3, 0), "FF_darksteel", bevel=0.01)
# chevron slats (animated scroll handled in-engine via texture; geometry slats)
for i in range(6):
    z = -0.375 + i * 0.15
    box(C, "Slat", (0.7, 0.03, 0.06), (0, 0.35, z), "FF_steel", bevel=0.005)
# direction nub housing (yellow marker, front)
box(C, "Nub", (0.2, 0.1, 0.12), (0, 0.36, 0.5), "FF_hazard", bevel=0.01)

frame_camera_target(target=(0, 0.3, 0), dist=3.5)
print("belt done")
