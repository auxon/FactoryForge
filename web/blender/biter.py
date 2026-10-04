# Biter, spitter, nest: armored steampunk-mutant fauna. Forward = +Z.
import os
import sys
import math as _m

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
import fac
importlib.reload(fac)
from fac import *  # noqa

ensure_base_materials()


def _leg(C, s, z, lift=0.0):
    """Two-bone insect leg. s = -1 left / +1 right."""
    hip = (s * 0.22, 0.28 + lift, z)
    knee = (s * 0.38, 0.18 + lift * 0.4, z + 0.02)
    foot = (s * 0.42, 0.03, z + 0.06)
    sphere(C, "Hip", 0.045, hip, "FF_chitin_dark", verts=8)
    pipe(C, "Femur", 0.028, hip, knee, "FF_chitin", verts=7)
    sphere(C, "Knee", 0.038, knee, "FF_chitin_dark", verts=8)
    bolt(C, (knee[0], knee[1], knee[2] + s * 0.02), r=0.012, h=0.02, material="FF_brass")
    pipe(C, "Shin", 0.022, knee, foot, "FF_chitin_dark", verts=6)
    box(C, "Claw", (0.06, 0.04, 0.08), foot, "FF_bone", bevel=0.008)


def build_biter(cname, sac=False):
    C = col(cname)
    wipe_collection(cname)

    # abdomen segments
    sphere(C, "Abdomen", 0.28, (0, 0.32, -0.28), "FF_chitin",
           scale=(1.05, 0.85, 1.35), verts=18)
    sphere(C, "Abdomen2", 0.20, (0, 0.30, -0.52), "FF_chitin_dark",
           scale=(0.9, 0.7, 1.1), verts=14)
    # dorsal plates with brass bolts
    for i, z in enumerate([-0.18, -0.36, -0.52]):
        box(C, "Carapace", (0.36 - i * 0.04, 0.06, 0.16),
            (0, 0.50 - i * 0.02, z), "FF_chitin_dark", bevel=0.016)
        rivet_row(C, (-0.10, 0.54 - i * 0.02, z), (0.10, 0.54 - i * 0.02, z),
                  n=3, r=0.012, h=0.018)

    # thorax
    sphere(C, "Thorax", 0.26, (0, 0.38, 0.08), "FF_chitin",
           scale=(1.15, 0.9, 1.05), verts=16)
    box(C, "Sternum", (0.22, 0.08, 0.16), (0, 0.52, 0.10), "FF_chitin_dark", bevel=0.014)
    rivet_row(C, (-0.08, 0.56, 0.10), (0.08, 0.56, 0.10), n=3, r=0.012, h=0.018)

    # steampunk vents / gills along the flanks
    for s in (-1, 1):
        for z in (-0.22, 0.02):
            cyl(C, "Vent", 0.03, 0.022, 0.08, (s * 0.24, 0.38, z), "FF_brass", verts=8)
        pipe(C, "Gill", 0.014, (s * 0.22, 0.36, -0.30), (s * 0.22, 0.36, 0.12),
             "FF_copper", verts=6)

    # head + mandibles
    head = sphere(C, "Head", 0.16, (0, 0.40, 0.36), "FF_chitin_dark",
                  scale=(1.05, 0.85, 1.15), verts=14)
    box(C, "Brow", (0.22, 0.05, 0.10), (0, 0.50, 0.42), "FF_chitin", bevel=0.01)
    for s in (-1, 1):
        jaw = cone(C, "Jaw", 0.045, 0.26, (s * 0.08, 0.28, 0.48), "FF_bone", verts=7)
        jaw.rotation_euler = (1.25, 0, s * -0.28)
        cone(C, "Fang", 0.02, 0.10, (s * 0.07, 0.24, 0.66), "FF_bone", verts=6)
        sphere(C, "Eye", 0.04, (s * 0.09, 0.48, 0.46), "FF_redlamp", verts=10)
        torus(C, "EyeRing", 0.045, 0.008, (s * 0.09, 0.48, 0.46), "FF_brass",
              major_seg=10, minor_seg=5)

    # dorsal spikes
    for i, z in enumerate([-0.42, -0.22, -0.02, 0.16]):
        spike = cone(C, "Spike", 0.045, 0.20 - i * 0.02, (0, 0.52, z),
                     "FF_chitin_dark", verts=7)
        spike.rotation_euler = (-0.45, 0, 0)
        if i % 2 == 0:
            bolt(C, (0.0, 0.56, z), r=0.012, h=0.02, material="FF_brass")

    # tail stinger
    tail = cone(C, "Stinger", 0.05, 0.36, (0, 0.28, -0.72), "FF_chitin_dark", verts=8)
    tail.rotation_euler = (-1.85, 0, 0)
    sphere(C, "StingerTip", 0.03, (0, 0.18, -0.92), "FF_amber", verts=8)

    # six jointed legs
    for s in (-1, 1):
        _leg(C, s, -0.28, lift=0.02)
        _leg(C, s, -0.02, lift=0.04)
        _leg(C, s, 0.22, lift=0.0)

    if sac:
        sphere(C, "Sac", 0.18, (0, 0.58, -0.18), "FF_sac",
               scale=(1.05, 0.95, 1.25), verts=14)
        sphere(C, "Sac2", 0.11, (0.12, 0.52, 0.02), "FF_sac", verts=12)
        sphere(C, "Sac3", 0.09, (-0.10, 0.50, -0.32), "FF_sac", verts=10)
        # spit nozzle
        nozzle = cyl(C, "Nozzle", 0.035, 0.022, 0.18, (0, 0.38, 0.52),
                     "FF_brass", verts=8, centered=True)
        nozzle.rotation_euler = (_m.pi / 2, 0, 0)
        flange(C, (0, 0.38, 0.58), r=0.05, axis="z", material="FF_brass")
        sphere(C, "GlowSpit", 0.03, (0, 0.38, 0.70), "FF_greenlamp", verts=8)


build_biter("FF_biter", sac=False)
build_biter("FF_spitter", sac=True)

# nest: hive mound with bone spires, sacs, rusted rebar
C = col("FF_nest")
wipe_collection("FF_nest")
sphere(C, "Mound", 1.25, (0, 0.18, 0), "FF_chitin", scale=(1.15, 0.48, 1.05), verts=24)
sphere(C, "MoundCore", 0.85, (0, 0.28, 0.05), "FF_chitin_dark",
       scale=(1.1, 0.55, 1.0), verts=18)
box(C, "Rim", (2.2, 0.12, 2.0), (0, 0.08, 0), "FF_soot", bevel=0.03)
for x, z, h, tilt in [
    (-0.75, 0.45, 1.05, 0.25), (0.68, -0.42, 1.25, -0.2),
    (0.15, 0.85, 0.85, 0.15), (-0.48, -0.72, 0.95, -0.18),
    (0.82, 0.52, 0.72, 0.22), (-0.15, 0.15, 0.55, 0.05),
]:
    spike = cone(C, "NestSpike", 0.16, h, (x, 0.22, z), "FF_bone", verts=8)
    spike.rotation_euler = (tilt, 0, -z * 0.12)
    bolt(C, (x, 0.28 + h * 0.35, z), r=0.02, h=0.03, material="FF_rust")
for x, z, r in [(-0.28, 0.12, 0.22), (0.38, -0.14, 0.20), (0.05, -0.42, 0.16),
                (-0.55, -0.15, 0.14)]:
    sphere(C, "NestSac", r, (x, 0.42, z), "FF_sac", verts=12)
# rusted rebar / scrap
for x, z, h in [(-0.95, -0.2, 0.7), (0.9, 0.15, 0.55), (0.35, -0.9, 0.45)]:
    bar = cyl(C, "Rebar", 0.03, 0.03, h, (x, 0.08, z), "FF_rust", verts=6)
    bar.rotation_euler = (0.35, 0.2, 0.4)
pipe(C, "NestPipe", 0.04, (-0.6, 0.25, 0.4), (0.5, 0.45, -0.3), "FF_copper", verts=8)
valve(C, (0.15, 0.62, 0.05), r=0.08)

frame_camera_target(target=(0, 0.45, 0), dist=3.8)
print("biters done")
