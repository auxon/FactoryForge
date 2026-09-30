# Solar panel (3x3m): legs, tilted cell array with dividers, junction box.
import sys
sys.path.insert(0, "/home/rah/factoryforge/web/blender")
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa
import math as _m

ensure_base_materials()
plain_material("FF_solarcell", (0.08, 0.16, 0.45), metallic=0.7, roughness=0.25)
C = col("FF_solar")
wipe_collection("FF_solar")

TILT = -0.42
PIVOT_Y = 1.32


def _tilt(o, y, z):
    dy = y - PIVOT_Y
    c, s = _m.cos(TILT), _m.sin(TILT)
    o.location.y = PIVOT_Y + dy * c - z * s
    o.location.z = dy * s + z * c
    o.rotation_euler = (TILT, 0, 0)


# supports: side rails tilted with the array + vertical posts sized to meet them
# array plane: y(z) = 1.32 + z*0.448
for sx in (-1.35, 1.35):
    rail = box(C, "Rail", (0.1, 0.08, 2.9), (sx, PIVOT_Y, 0), "FF_darksteel")
    rail.rotation_euler = (TILT, 0, 0)
for sx in (-1.35, 1.35):
    for z, top in [(-1.1, 0.83), (1.1, 1.81)]:
        h = top - 0.15
        box(C, "Post", (0.12, h, 0.12), (sx, 0.15 + h / 2, z), "FF_darksteel")
# cell array (tilted as a rigid group about pivot)
for ix in range(4):
    for iz in range(3):
        cell = box(C, "Cell", (0.62, 0.04, 0.8), (-1.05 + ix * 0.7, 1.32, -0.8 + iz * 0.85),
                   "FF_solarcell", bevel=0.005)
        _tilt(cell, 1.32, -0.8 + iz * 0.85)
for name, x, z in [("FrameEdgeN", 0, 1.32), ("FrameEdgeS", 0, -1.32)]:
    e = box(C, name, (2.9, 0.1, 0.08), (x, PIVOT_Y, z), "FF_lightsteel")
    _tilt(e, PIVOT_Y, z)
for name, x in [("FrameEdgeW", -1.45), ("FrameEdgeE", 1.45)]:
    e = box(C, name, (0.08, 0.1, 2.72), (x, PIVOT_Y, 0), "FF_lightsteel")
    _tilt(e, PIVOT_Y, 0)
# junction box + cable
box(C, "Junction", (0.4, 0.25, 0.3), (0.8, 0.9, -1.0), "FF_bluepaint", bevel=0.02)

frame_camera_target(target=(0, 1.0, 0), dist=8.0)
print("solar done")
