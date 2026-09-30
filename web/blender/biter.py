# Biter + spitter + nest, sculpted from primitives. Forward = +Z.
import sys
sys.path.insert(0, "/home/rah/factoryforge/web/blender")
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa

ensure_base_materials()


def build_biter(cname, sac=False):
    C = col(cname)
    wipe_collection(cname)
    # body: low ellipsoid
    sphere(C, "Body", 0.34, (0, 0.42, -0.1), "FF_chitin", scale=(1, 0.82, 1.35))
    # head
    sphere(C, "Head", 0.2, (0, 0.4, 0.42), "FF_chitin_dark", scale=(1, 0.9, 1.1))
    # jaws
    for s in (-1, 1):
        jaw = cone(C, "Jaw", 0.05, 0.3, (s * 0.09, 0.32, 0.55), "FF_chitin_dark", verts=8)
        jaw.rotation_euler = (1.35, 0, s * -0.25)
    # eyes (emissive red)
    for s in (-1, 1):
        sphere(C, "Eye", 0.045, (s * 0.1, 0.5, 0.52), "FF_redlamp")
    # back spikes
    for i, z in enumerate([-0.35, -0.15, 0.05]):
        spike = cone(C, "Spike", 0.05, 0.22 - i * 0.03, (0, 0.62, z), "FF_chitin_dark", verts=8)
        spike.rotation_euler = (-0.35, 0, 0)
    # tail stinger
    tail = cone(C, "Stinger", 0.05, 0.4, (0, 0.35, -0.62), "FF_chitin_dark", verts=8)
    tail.rotation_euler = (-1.9, 0, 0)
    # 6 legs
    import math
    for s in (-1, 1):
        for i, z in enumerate([-0.3, -0.05, 0.2]):
            leg = cyl(C, "Leg", 0.03, 0.025, 0.42, (s * 0.3, 0.05, z), "FF_chitin_dark", verts=6)
            leg.rotation_euler = (0, 0, s * 0.7)
    if sac:
        sphere(C, "Sac", 0.16, (0, 0.62, -0.2), "FF_sac", scale=(1, 0.9, 1.2))
        sphere(C, "Sac2", 0.1, (0.12, 0.55, 0.02), "FF_sac")


build_biter("FF_biter", sac=False)
build_biter("FF_spitter", sac=True)

# nest mound
C = col("FF_nest")
wipe_collection("FF_nest")
sphere(C, "Mound", 1.3, (0, 0.1, 0), "FF_nest", scale=(1, 0.42, 1), verts=28)
for i, (x, z, h) in enumerate([(-0.7, 0.4, 0.9), (0.6, -0.5, 1.1), (0.1, 0.8, 0.7),
                               (-0.4, -0.7, 0.8), (0.8, 0.5, 0.6)]):
    spike = cone(C, "NestSpike", 0.16, h, (x, 0.2, z), "FF_chitin_dark", verts=8)
    spike.rotation_euler = (x * 0.2, 0, -z * 0.15)
for i, (x, z) in enumerate([(-0.3, 0.1), (0.35, -0.1), (0.0, -0.45)]):
    sphere(C, "NestSac", 0.18, (x, 0.45, z), "FF_sac")

frame_camera_target(target=(0, 0.5, 0), dist=4.0)
print("biters done")
