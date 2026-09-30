# Steam engine (3x5m): cylinder block, flywheel Wheel, generator hall.
import sys
sys.path.insert(0, "/home/rah/factoryforge/web/blender")
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
# cylinder block (front) with lagging bands
box(C, "CylBlock", (1.8, 1.2, 1.6), (0, 0.75, 1.5), "FF_steel", bevel=0.06)
for dz in (1.0, 2.0):
    box(C, "LagBand", (1.88, 0.12, 0.14), (0, 0.75, dz), "FF_darksteel", bevel=0.01)
# steam inlet pipe + valve
c = cyl(C, "InletPipe", 0.12, 0.12, 1.2, (0, 1.0, 2.3), "FF_copper", verts=12)
c.rotation_euler = (_m.pi / 2, 0, 0)
box(C, "ValveWheel", (0.24, 0.05, 0.24), (0, 1.35, 2.5), "FF_redlamp", bevel=0.01)
# flywheel (animated Wheel) on side shaft
shaft = cyl(C, "Shaft", 0.09, 0.09, 2.4, (0, 0.7, 0.2), "FF_darksteel", verts=10)
shaft.rotation_euler = (0, _m.pi / 2, 0)
wheel = bpy.data.objects.get("Shaft")
# torus wheel
bpy.ops.mesh.primitive_torus_add(major_radius=0.75, minor_radius=0.1,
                                 location=(1.25, 0.2, 0.7))
wh = bpy.context.view_layer.objects.active
wh.name = "Wheel"
wh.data.materials.append(mat("FF_darksteel"))
for cc in list(wh.users_collection):
    if cc != C:
        cc.objects.unlink(wh)
C.objects.link(wh)
wh.rotation_euler = (0, _m.pi / 2, 0)
for a in range(4):
    sp = box(C, "Spoke", (0.08, 1.3, 0.08), (1.25, 0.7, 0.2), "FF_steel", bevel=0.01)
    sp.rotation_euler = (_m.pi / 4 * a, 0, 0)
# generator hall (rear)
box(C, "GenHall", (2.4, 1.5, 2.2), (0, 0.9, -1.2), "FF_bluepaint", bevel=0.06)
box(C, "GenRoof", (2.6, 0.15, 2.4), (0, 1.72, -1.2), "FF_darksteel")
for i in range(3):
    box(C, "Louver", (0.5, 0.08, 0.06), (-0.6, 1.0 + i * 0.2, -0.08), "FF_darksteel", bevel=0.01)
sphere(C, "Lamp", 0.07, (1.0, 1.3, -0.08), "FF_greenlamp")
box(C, "Stripe", (3.0, 0.02, 0.14), (0, 0.16, 2.43), "FF_hazard", bevel=0.005)

frame_camera_target(target=(0, 0.9, 0), dist=10.0)
print("steam engine done")
