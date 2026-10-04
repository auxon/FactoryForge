# FactoryForge Blender factory: steampunk hard-surface helpers.
# Game coords: (x, up, z), 1 unit = 1 metre = 1 game tile.
# Mapped to Blender Z-up internally. Animatable parts are separate
# objects named: Rotor | Wheel | Beam | Arm | ArmTip | Head | Rocket | Glow*
# Character joints: Torso | Head | ArmL/ArmR | Leg* | Jaw* (tiny pivot meshes).
from __future__ import annotations

import math
import os

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
TEX_DIR = os.path.join(HERE, "tex")

ANIM_PREFIXES = (
    "Rotor", "Wheel", "Beam", "Arm", "Head", "Rocket", "Glow", "Lamp",
    "Leg", "Jaw", "Torso",
)


def B(x, up, z):
    """Game coords -> Blender Z-up coords."""
    return (x, z, up)


def col(name):
    c = bpy.data.collections.get(name)
    if not c:
        c = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(c)
    return c


def wipe_collection(name):
    c = bpy.data.collections.get(name)
    if c:
        for o in list(c.objects):
            bpy.data.objects.remove(o, do_unlink=True)


def mat(name):
    ensure_base_materials()
    alias = MAT_ALIAS.get(name, name)
    m = bpy.data.materials.get(alias) or bpy.data.materials.get(name)
    if m:
        return m
    return bpy.data.materials.get("FF_iron")


def _own(o, coll):
    for c in list(o.users_collection):
        if c != coll:
            c.objects.unlink(o)
    if o.name not in coll.objects:
        coll.objects.link(o)


MAT_ALIAS = {
    "rusty_metal_02": "FF_rust",
    "metal_plate": "FF_iron",
    "blue_metal_plate": "FF_iron",
    "concrete_floor": "FF_concrete",
    "FF_darksteel": "FF_darkiron",
    "FF_steel": "FF_iron",
    "FF_bluepaint": "FF_iron",
    "FF_lightsteel": "FF_brass",
    "FF_hazard": "FF_brass",
    "FF_orange": "FF_bronze",
    "FF_gunmetal": "FF_soot",
    "FF_pearl": "FF_brass_polish",
    "FF_refpurple": "FF_copper",
    "FF_chemgreen": "FF_verdigris",
    "FF_solarcell": "FF_glass",
    "FF_nest": "FF_chitin_dark",
}


def _finish(o, coll, bevel=0.0, tex_world=1.0):
    if bevel > 0:
        mod = o.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
        mod.harden_normals = True
    boxmap_uv(o, tex_world)
    return o


def boxmap_uv(o, tex_world=1.0):
    """World-scale box-projected UVs: uniform texture density on every face."""
    import bmesh
    me = o.data
    bm = bmesh.new()
    bm.from_mesh(me)
    uv_layer = bm.loops.layers.uv.verify()
    scale = max(tex_world, 1e-4)
    for face in bm.faces:
        n = face.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for loop in face.loops:
            co = loop.vert.co
            u, v = ((co.y, co.z) if ax == 0 else
                    (co.x, co.z) if ax == 1 else (co.x, co.y))
            loop[uv_layer].uv = (u / scale, v / scale)
    bm.to_mesh(me)
    bm.free()
    me.update()


def _deselect():
    for o in bpy.context.selected_objects:
        o.select_set(False)


def box(coll, name, dims, loc, material, bevel=0.02):
    """dims=(w, h, d), loc=(x, up, z)."""
    _deselect()
    bpy.ops.mesh.primitive_cube_add(size=1, location=B(*loc))
    o = bpy.context.view_layer.objects.active
    o.name = name
    o.dimensions = (dims[0], dims[2], dims[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.clear()
    o.data.materials.append(mat(material))
    _own(o, coll)
    return _finish(o, coll, bevel, _tex_world(material))


def cyl(coll, name, r_top, r_bot, depth, loc, material, verts=16, bevel=0.012,
        centered=False):
    """Vertical cylinder. loc=(x, up, z): base center by default."""
    _deselect()
    up = loc[1] if centered else loc[1] + depth / 2
    bpy.ops.mesh.primitive_cylinder_add(
        radius=r_bot, depth=depth, vertices=verts,
        location=(loc[0], loc[2], up))
    o = bpy.context.view_layer.objects.active
    o.name = name
    if abs(r_top - r_bot) > 1e-6 and r_bot != 0:
        me = o.data
        top_z = max(v.co.z for v in me.vertices)
        f = r_top / r_bot
        for v in me.vertices:
            if v.co.z > top_z - 1e-4:
                v.co.x *= f
                v.co.y *= f
        me.update()
    o.data.materials.clear()
    o.data.materials.append(mat(material))
    _own(o, coll)
    return _finish(o, coll, bevel, _tex_world(material))


def sphere(coll, name, r, loc, material, scale=(1, 1, 1), verts=16, bevel=0.0):
    _deselect()
    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=r, segments=verts, ring_count=max(8, verts // 2),
        location=(loc[0], loc[2], loc[1]))
    o = bpy.context.view_layer.objects.active
    o.name = name
    o.scale = (scale[0], scale[2], scale[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.clear()
    o.data.materials.append(mat(material))
    _own(o, coll)
    return _finish(o, coll, bevel, _tex_world(material))


def cone(coll, name, r, depth, loc, material, verts=12, bevel=0.01):
    _deselect()
    bpy.ops.mesh.primitive_cone_add(
        radius1=r, radius2=0.01, depth=depth, vertices=verts,
        location=(loc[0], loc[2], loc[1] + depth / 2))
    o = bpy.context.view_layer.objects.active
    o.name = name
    o.data.materials.clear()
    o.data.materials.append(mat(material))
    _own(o, coll)
    return _finish(o, coll, bevel, _tex_world(material))


def torus(coll, name, major, minor, loc, material, major_seg=24, minor_seg=10,
          rot=(0, 0, 0)):
    _deselect()
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major, minor_radius=minor,
        major_segments=major_seg, minor_segments=minor_seg,
        location=B(*loc))
    o = bpy.context.view_layer.objects.active
    o.name = name
    o.rotation_euler = rot
    o.data.materials.clear()
    o.data.materials.append(mat(material))
    _own(o, coll)
    return _finish(o, coll, 0.0, _tex_world(material))


def bolt(coll, loc, r=0.04, h=0.055, material="FF_brass"):
    return cyl(coll, "Bolt", r, r, h, loc, material, verts=6, bevel=0.004)


def rivet_row(coll, a, b, n=5, r=0.032, h=0.045, material="FF_brass"):
    """Row of hex rivets from game-point a to b (inclusive)."""
    for i in range(n):
        t = i / max(n - 1, 1)
        loc = (a[0] + (b[0] - a[0]) * t,
               a[1] + (b[1] - a[1]) * t,
               a[2] + (b[2] - a[2]) * t)
        bolt(coll, loc, r=r, h=h, material=material)


def rivet_ring(coll, center, radius, n=8, r=0.03, h=0.04, material="FF_brass",
               plane="xz"):
    cx, cy, cz = center
    for i in range(n):
        a = i * math.tau / n
        if plane == "xz":
            loc = (cx + radius * math.cos(a), cy, cz + radius * math.sin(a))
        elif plane == "xy":
            loc = (cx + radius * math.cos(a), cy + radius * math.sin(a), cz)
        else:
            loc = (cx, cy + radius * math.sin(a), cz + radius * math.cos(a))
        bolt(coll, loc, r=r, h=h, material=material)


def pipe(coll, name, r, a, b, material="FF_copper", verts=10):
    """Cylinder from game-point a to b."""
    ax, ay, az = a
    bx, by, bz = b
    dx, dy, dz = bx - ax, by - ay, bz - az
    length = math.sqrt(dx * dx + dy * dy + dz * dz)
    if length < 1e-5:
        return None
    mid = ((ax + bx) / 2, (ay + by) / 2, (az + bz) / 2)
    o = cyl(coll, name, r, r, length, mid, material, verts=verts,
            bevel=0.006, centered=True)
    # align +Z (Blender cylinder axis) to game vector (dx, dy, dz)
    # Blender location is (x, z, up) so game (dx,dy,dz) -> blender (dx, dz, dy)
    target = Vector((dx, dz, dy)).normalized()
    o.rotation_euler = target.to_track_quat("Z", "Y").to_euler()
    return o


def elbow(coll, name, r, center, axis_from, axis_to, material="FF_copper"):
    """90-degree pipe elbow. axis_from/to are unit game vectors."""
    # Approximate with a short bent pair + torus segment
    fx, fy, fz = axis_from
    tx, ty, tz = axis_to
    # torus in the plane of the two axes
    o = torus(coll, name, r * 1.35, r, center, material, major_seg=10, minor_seg=8)
    # orient: default torus is in XY (Blender), which is XZ game
    # rotate so its plane matches from->to
    a = Vector((fx, fz, fy))
    b = Vector((tx, tz, ty))
    n = a.cross(b)
    if n.length > 1e-5:
        o.rotation_euler = n.normalized().to_track_quat("Z", "Y").to_euler()
    return o


def flange(coll, loc, r=0.18, axis="z", material="FF_brass"):
    o = cyl(coll, "Flange", r, r, 0.06, loc, material, verts=14, centered=True)
    if axis == "x":
        o.rotation_euler = (0, math.pi / 2, 0)
    elif axis == "z":
        o.rotation_euler = (math.pi / 2, 0, 0)
    rivet_ring(coll, loc, r * 0.78, n=6, r=0.018, h=0.03, material="FF_brass",
               plane="xy" if axis == "y" else "xz")
    return o


def valve(coll, loc, r=0.14, material="FF_brass"):
    """Handwheel valve standing on +Y (up)."""
    x, y, z = loc
    torus(coll, "ValveRim", r, r * 0.16, (x, y, z), material, major_seg=16, minor_seg=8)
    box(coll, "ValveHub", (r * 0.35, r * 0.22, r * 0.35), (x, y, z), "FF_bronze", bevel=0.01)
    for i in range(4):
        a = i * math.pi / 2
        spoke = box(coll, "ValveSpoke", (r * 1.7, r * 0.1, r * 0.12),
                    (x, y, z), material, bevel=0.004)
        spoke.rotation_euler = (0, a, 0)
    return None


def gauge(coll, loc, facing="z", r=0.11):
    """Brass pressure gauge with glass and needle. facing +z or +x."""
    x, y, z = loc
    body = cyl(coll, "GaugeBody", r, r, 0.06, (x, y, z), "FF_brass", verts=16, centered=True)
    glass = cyl(coll, "GaugeGlass", r * 0.78, r * 0.78, 0.02,
                (x, y, z), "FF_glass", verts=14, centered=True)
    needle = box(coll, "GaugeNeedle", (0.012, r * 0.7, 0.012),
                 (x, y, z), "FF_soot", bevel=0.0)
    if facing == "z":
        body.rotation_euler = (math.pi / 2, 0, 0)
        glass.rotation_euler = (math.pi / 2, 0, 0)
        needle.location = B(x, y, z + 0.04)
        torus(coll, "GaugeBezel", r * 0.95, 0.015, (x, y, z + 0.04),
              "FF_brass_polish", major_seg=16, minor_seg=6)
    else:
        body.rotation_euler = (0, math.pi / 2, 0)
        glass.rotation_euler = (0, math.pi / 2, 0)
        needle.location = B(x + 0.04, y, z)
        torus(coll, "GaugeBezel", r * 0.95, 0.015, (x + 0.04, y, z),
              "FF_brass_polish", major_seg=16, minor_seg=6,
              rot=(0, math.pi / 2, 0))
    return glass


def gear(coll, name, r_outer, teeth, depth, loc, material="FF_brass",
         r_inner=None, axis="y"):
    """Spur gear. axis: y=up (game), x or z = horizontal."""
    import bmesh
    r_inner = r_inner if r_inner is not None else r_outer * 0.38
    r_root = r_outer * 0.78
    bm = bmesh.new()
    verts_outer = []
    for i in range(teeth * 2):
        a = i * math.pi / teeth
        r = r_outer if i % 2 == 0 else r_root
        # slight tooth width by offsetting even verts
        verts_outer.append(bm.verts.new((r * math.cos(a), r * math.sin(a), 0)))
    bm.verts.ensure_lookup_table()
    face = bm.faces.new(verts_outer)
    geom = bmesh.ops.extrude_face_region(bm, geom=[face])
    for v in [e for e in geom["geom"] if isinstance(e, bmesh.types.BMVert)]:
        v.co.z = depth
    # hub hole as inset-ish: skip, add a hub cylinder later
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    o.location = B(loc[0], loc[1], loc[2])
    if axis == "x":
        o.rotation_euler = (0, math.pi / 2, 0)
    elif axis == "z":
        o.rotation_euler = (math.pi / 2, 0, 0)
    o.data.materials.append(mat(material))
    _own(o, coll)
    boxmap_uv(o, 0.8)
    hub = cyl(coll, name + "Hub", r_inner, r_inner, depth * 1.15,
              loc, "FF_bronze", verts=12, centered=True)
    if axis == "x":
        hub.rotation_euler = (0, math.pi / 2, 0)
    elif axis == "z":
        hub.rotation_euler = (math.pi / 2, 0, 0)
    return o


def ibeam(coll, name, length, loc, material="FF_iron", axis="x"):
    # I-profile: web + two flanges
    if axis == "x":
        box(coll, name + "Web", (length, 0.22, 0.05), loc, material, bevel=0.008)
        box(coll, name + "FlTop", (length, 0.04, 0.16),
            (loc[0], loc[1] + 0.12, loc[2]), material, bevel=0.006)
        box(coll, name + "FlBot", (length, 0.04, 0.16),
            (loc[0], loc[1] - 0.12, loc[2]), material, bevel=0.006)
    else:
        box(coll, name + "Web", (0.05, 0.22, length), loc, material, bevel=0.008)
        box(coll, name + "FlTop", (0.16, 0.04, length),
            (loc[0], loc[1] + 0.12, loc[2]), material, bevel=0.006)
        box(coll, name + "FlBot", (0.16, 0.04, length),
            (loc[0], loc[1] - 0.12, loc[2]), material, bevel=0.006)


def pad(coll, w, d, material="FF_concrete"):
    o = box(coll, "Pad", (w, 0.12, d), (0, 0.06, 0), material, bevel=0.008)
    # worn iron edge channel
    box(coll, "PadLipN", (w * 0.98, 0.04, 0.06), (0, 0.14, d * 0.48), "FF_soot", bevel=0.004)
    box(coll, "PadLipS", (w * 0.98, 0.04, 0.06), (0, 0.14, -d * 0.48), "FF_soot", bevel=0.004)
    box(coll, "PadLipE", (0.06, 0.04, d * 0.9), (w * 0.48, 0.14, 0), "FF_soot", bevel=0.004)
    box(coll, "PadLipW", (0.06, 0.04, d * 0.9), (-w * 0.48, 0.14, 0), "FF_soot", bevel=0.004)
    return o


def chimney(coll, loc, r=0.16, h=1.6, material="FF_rust"):
    c = cyl(coll, "Chimney", r, r * 1.12, h, loc, material, verts=14)
    cyl(coll, "ChimneyBand", r * 1.18, r * 1.18, 0.07,
        (loc[0], loc[1] + h * 0.45, loc[2]), "FF_brass")
    cyl(coll, "ChimneyLip", r * 1.28, r * 1.05, 0.12,
        (loc[0], loc[1] + h, loc[2]), "FF_soot")
    rivet_ring(coll, (loc[0], loc[1] + h * 0.45, loc[2]), r * 1.2, n=6,
               r=0.02, h=0.03, material="FF_brass")
    return c


def glow_plane(coll, name, w, h, loc, rot_z=0.0, rot_y=0.0):
    m = mat("FF_fire")
    _deselect()
    bpy.ops.mesh.primitive_plane_add(size=1, location=B(*loc))
    o = bpy.context.view_layer.objects.active
    o.name = name
    o.dimensions = (w, h, h)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.rotation_euler = (0, rot_y, rot_z)
    o.data.materials.clear()
    o.data.materials.append(m)
    _own(o, coll)
    return o


def parent_keep(child, parent):
    if child is None or parent is None:
        return
    mw = child.matrix_world.copy()
    child.parent = parent
    child.matrix_parent_inverse = parent.matrix_world.inverted()
    child.matrix_world = mw


def pivot(coll, name, loc):
    """Tiny joint mesh. Rotate this object in the web view to swing a limb."""
    return box(coll, name, (0.008, 0.008, 0.008), loc, "FF_darkiron", bevel=0.0)


def snapshot(coll):
    return {id(o) for o in coll.objects}


def parent_created(coll, parent, before):
    """Parent every object created after snapshot `before` onto `parent`."""
    for o in list(coll.objects):
        if id(o) not in before and o is not parent and o.parent is None:
            parent_keep(o, parent)


def parent_name(child_name_prefix, parent):
    for o in list(parent.users_collection[0].objects) if parent.users_collection else []:
        if o.name.startswith(child_name_prefix) or o.name.split(".")[0] == child_name_prefix:
            if o != parent:
                parent_keep(o, parent)


def lamp(coll, loc, material="FF_greenlamp", r=0.06):
    return sphere(coll, "Lamp", r, loc, material, verts=10)


def lagging(coll, loc, length, r, n=5, material="FF_wood", axis="x"):
    """Wood insulation bands around a boiler drum."""
    for i in range(n):
        t = (i + 0.5) / n
        if axis == "x":
            p = (loc[0] - length / 2 + t * length, loc[1], loc[2])
            o = cyl(coll, "Lag", r * 1.06, r * 1.06, 0.08, p, material,
                    verts=14, centered=True)
            o.rotation_euler = (0, math.pi / 2, 0)
        else:
            p = (loc[0], loc[1], loc[2] - length / 2 + t * length)
            o = cyl(coll, "Lag", r * 1.06, r * 1.06, 0.08, p, material,
                    verts=14, centered=True)
            o.rotation_euler = (math.pi / 2, 0, 0)


def grate(coll, loc, w, d, material="FF_iron"):
    box(coll, "GrateFrame", (w, 0.05, d), loc, material, bevel=0.008)
    n = max(3, int(w / 0.12))
    for i in range(n):
        x = loc[0] - w / 2 + (i + 0.5) * (w / n)
        box(coll, "GrateBar", (0.03, 0.04, d * 0.9),
            (x, loc[1] + 0.02, loc[2]), "FF_soot", bevel=0.002)


def _tex_world(material):
    name = MAT_ALIAS.get(material, material)
    return {
        "FF_iron": 0.85, "FF_darkiron": 0.85, "FF_soot": 0.9,
        "FF_brass": 0.7, "FF_brass_polish": 0.7, "FF_bronze": 0.7,
        "FF_copper": 0.65, "FF_verdigris": 0.7, "FF_rust": 0.75,
        "FF_wood": 0.9, "FF_brick": 0.8, "FF_concrete": 1.4,
        "FF_leather": 0.6,
        "FF_chitin": 0.55, "FF_chitin_dark": 0.55, "FF_flesh": 0.5,
        "FF_sac": 0.5, "FF_bone": 0.7, "FF_visor": 0.4,
    }.get(name, 1.0)


def _load_image(path):
    name = os.path.basename(path)
    existing = bpy.data.images.get(name)
    if existing:
        return existing
    if not os.path.isfile(path):
        return None
    img = bpy.data.images.load(path)
    img.pack()
    return img


def _tex_nodes(m, kind, metallic=0.85, rough_mul=1.0, color=None, emissive=None):
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    out.location = (420, 0)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (80, 0)
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    if color:
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = 0.45
    if emissive:
        bsdf.inputs["Emission Color"].default_value = (*emissive, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 4.0
    d = _load_image(os.path.join(TEX_DIR, f"{kind}_d.jpg")) if kind else None
    n = _load_image(os.path.join(TEX_DIR, f"{kind}_n.png")) if kind else None
    r = _load_image(os.path.join(TEX_DIR, f"{kind}_r.jpg")) if kind else None
    if d:
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = d
        tex.location = (-420, 120)
        if color:
            mixn = nt.nodes.new("ShaderNodeMixRGB")
            mixn.blend_type = "MULTIPLY"
            mixn.inputs["Fac"].default_value = 0.55
            mixn.inputs["Color2"].default_value = (*color, 1.0)
            mixn.location = (-120, 80)
            nt.links.new(tex.outputs["Color"], mixn.inputs["Color1"])
            nt.links.new(mixn.outputs["Color"], bsdf.inputs["Base Color"])
        else:
            nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if r:
        rtex = nt.nodes.new("ShaderNodeTexImage")
        rtex.image = r
        rtex.location = (-420, -80)
        if hasattr(rtex, "image") and rtex.image:
            rtex.image.colorspace_settings.name = "Non-Color"
        mul = nt.nodes.new("ShaderNodeMath")
        mul.operation = "MULTIPLY"
        mul.inputs[1].default_value = rough_mul
        mul.location = (-120, -80)
        nt.links.new(rtex.outputs["Color"], mul.inputs[0])
        nt.links.new(mul.outputs["Value"], bsdf.inputs["Roughness"])
    if n:
        ntex = nt.nodes.new("ShaderNodeTexImage")
        ntex.image = n
        ntex.location = (-420, -260)
        if ntex.image:
            ntex.image.colorspace_settings.name = "Non-Color"
        nmap = nt.nodes.new("ShaderNodeNormalMap")
        nmap.inputs["Strength"].default_value = 1.15
        nmap.location = (-120, -260)
        nt.links.new(ntex.outputs["Color"], nmap.inputs["Color"])
        nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    return m


def plain_material(name, base, metallic=0.0, roughness=0.6, emissive=None):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*base, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emissive:
        bsdf.inputs["Emission Color"].default_value = (*emissive, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 3.5
    return m


_MATERIALS_READY = False


def ensure_base_materials():
    global _MATERIALS_READY
    if _MATERIALS_READY and bpy.data.materials.get("FF_iron"):
        return
    specs = [
        ("FF_iron", "iron", 0.62, 1.0, (0.72, 0.68, 0.62)),
        ("FF_darkiron", "iron", 0.7, 1.05, (0.42, 0.40, 0.38)),
        ("FF_soot", "soot", 0.55, 1.1, (0.32, 0.28, 0.24)),
        ("FF_brass", "brass", 0.78, 0.85, (1.0, 0.78, 0.32)),
        ("FF_brass_polish", "brass", 0.85, 0.5, (1.0, 0.86, 0.42)),
        ("FF_bronze", "brass", 0.72, 1.0, (0.72, 0.42, 0.16)),
        ("FF_copper", "copper", 0.8, 0.9, (0.92, 0.48, 0.24)),
        ("FF_verdigris", "copper", 0.4, 1.1, (0.28, 0.55, 0.40)),
        ("FF_rust", "rust", 0.28, 1.15, (0.72, 0.38, 0.14)),
        ("FF_wood", "wood", 0.02, 1.0, (0.55, 0.36, 0.16)),
        ("FF_brick", "brick", 0.0, 1.0, (0.72, 0.36, 0.22)),
        ("FF_concrete", "concrete", 0.0, 1.0, (0.62, 0.58, 0.52)),
        ("FF_leather", "leather", 0.05, 1.0, (0.42, 0.24, 0.12)),
        ("FF_chitin", "chitin", 0.18, 1.0, (0.52, 0.34, 0.18)),
        ("FF_chitin_dark", "chitin", 0.22, 1.05, (0.32, 0.18, 0.10)),
        ("FF_flesh", "flesh", 0.04, 0.85, (0.72, 0.28, 0.24)),
        ("FF_sac", "flesh", 0.06, 0.7, (0.42, 0.72, 0.22)),
        ("FF_bone", "bone", 0.02, 1.0, (0.82, 0.74, 0.56)),
    ]
    for name, kind, metal, rm, colr in specs:
        m = bpy.data.materials.get(name)
        if m:
            continue
        m = bpy.data.materials.new(name)
        _tex_nodes(m, kind, metallic=metal, rough_mul=rm, color=colr)
    plain_material("FF_glass", (0.55, 0.72, 0.78), metallic=0.15, roughness=0.08)
    g = bpy.data.materials.get("FF_glass")
    if g and g.use_nodes:
        bsdf = next(n for n in g.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        if "Transmission Weight" in bsdf.inputs:
            bsdf.inputs["Transmission Weight"].default_value = 0.65
        elif "Transmission" in bsdf.inputs:
            bsdf.inputs["Transmission"].default_value = 0.65
        g.blend_method = "BLEND"
    plain_material("FF_fire", (1.0, 0.38, 0.04), metallic=0.0, roughness=0.4,
                   emissive=(1.0, 0.32, 0.02))
    plain_material("FF_steamglow", (0.95, 0.88, 0.7), metallic=0.0, roughness=0.3,
                   emissive=(0.9, 0.75, 0.4))
    plain_material("FF_greenlamp", (0.12, 0.85, 0.28), metallic=0.1, roughness=0.25,
                   emissive=(0.08, 0.9, 0.22))
    plain_material("FF_redlamp", (0.95, 0.12, 0.08), metallic=0.1, roughness=0.25,
                   emissive=(0.95, 0.1, 0.05))
    plain_material("FF_amber", (1.0, 0.55, 0.12), metallic=0.15, roughness=0.3,
                   emissive=(1.0, 0.45, 0.08))
    plain_material("FF_visor", (0.25, 0.72, 0.85), metallic=0.2, roughness=0.08,
                   emissive=(0.15, 0.55, 0.7))
    visor = bpy.data.materials.get("FF_visor")
    if visor and visor.use_nodes:
        bsdf = next(n for n in visor.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        if "Transmission Weight" in bsdf.inputs:
            bsdf.inputs["Transmission Weight"].default_value = 0.45
        visor.blend_method = "BLEND"
    sac = bpy.data.materials.get("FF_sac")
    if sac and sac.use_nodes:
        bsdf = next((n for n in sac.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf:
            bsdf.inputs["Emission Color"].default_value = (0.35, 0.85, 0.18, 1.0)
            bsdf.inputs["Emission Strength"].default_value = 1.6
    plain_material("FF_coal", (0.04, 0.04, 0.045), metallic=0.15, roughness=0.75)
    # keep old names so leftover scripts don't crash
    for old, new in MAT_ALIAS.items():
        if not bpy.data.materials.get(old) and bpy.data.materials.get(new):
            bpy.data.materials[new].name  # touch
    _MATERIALS_READY = True


def isolate(name):
    c = bpy.data.collections.get(name)
    for o in bpy.data.objects:
        if o.type == "MESH":
            o.hide_viewport = not (c and o.name in c.objects)
    if c:
        for o in c.objects:
            o.hide_viewport = False


def prep_web(collection_name):
    c = bpy.data.collections.get(collection_name)
    keep = ("diff", "nor", "rough", "alpha", "mask", "metal", "_d.", "_n.", "_r.")
    for o in c.objects:
        for slot in o.material_slots:
            m = slot.material
            if not m or m.name.endswith("_WEB"):
                continue
            w = m.copy()
            w.name = m.name + "_WEB"
            slot.material = w
            if w.use_nodes:
                dead = [n for n in w.node_tree.nodes
                        if n.type == "TEX_IMAGE" and n.image
                        and not any(k in n.image.name.lower() for k in keep)]
                for n in dead:
                    w.node_tree.nodes.remove(n)
    return c


def apply_mods(o):
    if not o.modifiers:
        return
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    for m in list(o.modifiers):
        try:
            bpy.ops.object.modifier_apply(modifier=m.name)
        except Exception:
            o.modifiers.remove(m)
    o.select_set(False)


def _is_anim(o):
    n = o.name.split(".")[0]
    if any(n.startswith(p) for p in ANIM_PREFIXES):
        return True
    cur = o.parent
    while cur:
        pn = cur.name.split(".")[0]
        if any(pn.startswith(p) for p in ANIM_PREFIXES):
            return True
        cur = cur.parent
    return False


def join_static(coll):
    """Collapse non-animated meshes that share a material into fewer objects."""
    groups = {}
    for o in list(coll.objects):
        if o.type != "MESH" or _is_anim(o) or o.parent:
            continue
        key = o.data.materials[0].name if o.data.materials else "_none"
        groups.setdefault(key, []).append(o)
    for objs in groups.values():
        if len(objs) < 2:
            continue
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        try:
            bpy.ops.object.join()
        except Exception:
            pass


def export_collection(collection_name, path):
    """Export one collection to a GLB, applying bevels, keeping anim names."""
    c = bpy.data.collections.get(collection_name)
    if not c:
        raise RuntimeError(f"missing collection {collection_name}")
    for o in list(c.objects):
        if o.type == "MESH":
            apply_mods(o)
    join_static(c)
    bpy.ops.object.select_all(action="DESELECT")
    for o in c.objects:
        if o.type == "MESH":
            o.select_set(True)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_texcoords=True,
        export_normals=True,
        export_materials="EXPORT",
        export_cameras=False,
        export_extras=False,
        export_yup=True,
    )
    print("exported", path, "objects", len([o for o in c.objects if o.type == "MESH"]))


def frame_camera_target(target=(0, 1, 0), dist=7.0, yaw=0.785, pitch=0.9):
    cam = bpy.data.objects.get("Camera")
    if not cam:
        cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
        bpy.context.scene.collection.objects.link(cam)
    tx, ty, tz = target[0], target[2], target[1]
    cx = tx + dist * math.cos(yaw) * math.cos(pitch)
    cy = ty + dist * math.sin(yaw) * math.cos(pitch)
    cz = tz + dist * math.sin(pitch)
    cam.location = (cx, cy, cz)
    d = Vector((tx - cx, ty - cy, tz - cz))
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam
    for area in bpy.context.screen.areas:
        if area.type == "VIEW_3D":
            for space in area.spaces:
                if space.type == "VIEW_3D":
                    r3d = space.region_3d
                    r3d.view_location = (tx, ty, tz)
                    r3d.view_distance = dist
                    dvec = Vector((tx - cx, ty - cy, tz - cz))
                    r3d.view_rotation = dvec.to_track_quat("-Z", "Y")
                    r3d.view_perspective = "PERSP"
                    try:
                        space.shading.type = "MATERIAL"
                    except Exception:
                        pass
            break
