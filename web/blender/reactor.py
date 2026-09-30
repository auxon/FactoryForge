# Nuclear reactor (5x5m): containment cylinder + dome, core glow ring,
# cooling pipe ring, control annex, hazard perimeter.
import sys
sys.path.insert(0, "/home/rah/factoryforge/web/blender")
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa
import math as _m

ensure_base_materials()
C = col("FF_reactor")
wipe_collection("FF_reactor")

pad(C, 5.0, 5.0)
# containment: cylinder + dome cap
cyl(C, "Containment", 1.6, 1.7, 2.6, (0, 0.15, 0), "concrete_floor", verts=32)
sphere(C, "Dome", 1.6, (0, 2.75, 0), "concrete_floor", scale=(1, 0.55, 1), verts=32)
cyl(C, "DomeRim", 1.65, 1.65, 0.12, (0, 2.72, 0), "FF_hazard", verts=32)
# core glow ring (windows around middle, facing outward)
for i in range(8):
    a = i * _m.pi / 4
    glow_plane(C, f"GlowCore{i}", 0.4, 0.25, (1.68 * _m.cos(a), 1.5, 1.68 * _m.sin(a)), rot_y=_m.pi / 2 - a)
# cooling pipes ring: 4 verticals + top manifold ring
for i in range(4):
    a = i * _m.pi / 2 + _m.pi / 4
    x, z = 2.0 * _m.cos(a), 2.0 * _m.sin(a)
    cyl(C, "CoolPipe", 0.12, 0.12, 2.2, (x, 0.15, z), "FF_steel", verts=12)
# control annex + door + lamp
box(C, "Annex", (1.4, 1.1, 1.0), (0, 0.7, 2.3), "FF_bluepaint", bevel=0.05)
box(C, "AnnexDoor", (0.5, 0.8, 0.08), (0, 0.55, 2.82), "FF_darksteel", bevel=0.02)
sphere(C, "Lamp", 0.07, (0.6, 1.35, 2.3), "FF_greenlamp")
# hazard perimeter dashes
for i in range(12):
    a = i * _m.pi / 6
    box(C, "RingDash", (0.5, 0.02, 0.2), (2.9 * _m.cos(a), 0.16, 2.9 * _m.sin(a)), "FF_hazard", bevel=0.005)

frame_camera_target(target=(0, 1.5, 0), dist=13.0)
print("reactor done")
