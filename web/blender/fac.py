# FactoryForge Blender factory: shared helpers for hard-surface buildings.
# Game coords: (x, up, z), 1 unit = 1 metre = 1 game tile.
# Mapped to Blender Z-up internally. Animatable parts are separate
# objects named: Rotor | Wheel | Beam | Arm | ArmTip | Head | Rocket | Glow*
import bpy
import math


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
    m = bpy.data.materials.get(name)
    assert m, f"material {name} missing"
    return m


def _own(o, coll):
    for c in list(o.users_collection):
        if c != coll:
            c.objects.unlink(o)
    if o.name not in coll.objects:
        coll.objects.link(o)


TEX_WORLD = {
    "rusty_metal_02": 1.0, "metal_plate": 0.5, "blue_metal_plate": 2.5,
    "concrete_floor": 2.08, "leafy_grass": 2.0, "dirt": 2.0,
    "sand_03": 2.0, "rock_01": 1.5,
}


def _finish(o, coll, bevel=0.0, tex_world=None):
    if bevel > 0:
        mod = o.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
    if tex_world is None:
        try:
            tex_world = TEX_WORLD.get(o.material_slots[0].material.name, 1.0)
        except Exception:
            tex_world = 1.0
    boxmap_uv(o, tex_world)
    return o


def boxmap_uv(o, tex_world=1.0):
    """World-scale box-projected UVs: uniform texture density on every face."""
    import bmesh
    me = o.data
    bm = bmesh.new()
    bm.from_mesh(me)
    uv_layer = bm.loops.layers.uv.verify()
    for face in bm.faces:
        n = face.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for loop in face.loops:
            co = loop.vert.co
            u, v = ((co.y, co.z) if ax == 0 else
                    (co.x, co.z) if ax == 1 else (co.x, co.y))
            loop[uv_layer].uv = (u / tex_world, v / tex_world)
    bm.to_mesh(me)
    bm.free()
    me.update()


def box(coll, name, dims, loc, material, bevel=0.03):
    """dims=(w, h, d), loc=(x, up, z)."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=B(*loc))
    o = bpy.context.view_layer.objects.active
    o.name = name
    o.dimensions = (dims[0], dims[2], dims[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(mat(material))
    _own(o, coll)
    return _finish(o, coll, bevel)


def cyl(coll, name, r_top, r_bot, depth, loc, material, verts=20, bevel=0.02,
        centered=False):
    """Vertical cylinder. loc=(x, up, z): base center by default,
    geometric center if centered=True (use for horizontal cylinders)."""
    up = loc[1] if centered else loc[1] + depth / 2
    bpy.ops.mesh.primitive_cylinder_add(
        radius=r_bot, depth=depth, vertices=verts,
        location=(loc[0], loc[2], up))
    o = bpy.context.view_layer.objects.active
    o.name = name
    if abs(r_top - r_bot) > 1e-6:
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="DESELECT")
        bpy.ops.object.mode_set(mode="OBJECT")
        me = o.data
        top_z = max(v.co.z for v in me.vertices)
        for v in me.vertices:
            if v.co.z > top_z - 1e-4:
                f = r_top / r_bot
                v.co.x *= f
                v.co.y *= f
        me.update()
    o.data.materials.append(mat(material))
    _own(o, coll)
    return _finish(o, coll, bevel)


def bolt(coll, loc, r=0.045, h=0.06, material="FF_darksteel"):
    return cyl(coll, "Bolt", r, r, h, loc, material, verts=6, bevel=0.005)


def sphere(coll, name, r, loc, material, scale=(1, 1, 1), verts=20, bevel=0.0):
    """loc=(x, center_up, z). scale=(sx, sy_up, sz)."""
    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=r, segments=verts, ring_count=max(8, verts // 2),
        location=(loc[0], loc[2], loc[1]))
    o = bpy.context.view_layer.objects.active
    o.name = name
    o.scale = (scale[0], scale[2], scale[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(mat(material))
    _own(o, coll)
    return _finish(o, coll, bevel)


def cone(coll, name, r, depth, loc, material, verts=12, bevel=0.01):
    """Vertical cone pointing up, loc=(x, base_up, z)."""
    bpy.ops.mesh.primitive_cone_add(
        radius1=r, radius2=0.01, depth=depth, vertices=verts,
        location=(loc[0], loc[2], loc[1] + depth / 2))
    o = bpy.context.view_layer.objects.active
    o.name = name
    o.data.materials.append(mat(material))
    _own(o, coll)
    return _finish(o, coll, bevel)


def pad(coll, w, d, material="concrete_floor"):
    return box(coll, "Pad", (w, 0.15, d), (0, 0.075, 0), material, bevel=0.01)


def chimney(coll, loc, r=0.16, h=1.6, material="rusty_metal_02"):
    """loc=(x, base_up, z)."""
    c = cyl(coll, "Chimney", r, r * 1.15, h, loc, material)
    cyl(coll, "ChimneyLip", r * 1.3, r * 1.3, 0.08,
        (loc[0], loc[1] + h, loc[2]), "FF_darksteel")
    return c


def glow_plane(coll, name, w, h, loc, rot_z=0.0, rot_y=0.0):
    m = bpy.data.materials.get("FF_fire")
    bpy.ops.mesh.primitive_plane_add(size=1, location=B(*loc))
    o = bpy.context.view_layer.objects.active
    o.name = name
    o.dimensions = (w, h, h)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.rotation_euler = (0, rot_y, rot_z)
    o.data.materials.append(m)
    _own(o, coll)
    return o


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
        bsdf.inputs["Emission Strength"].default_value = 3.0
    return m


def ensure_base_materials():
    plain_material("FF_darksteel", (0.16, 0.16, 0.18), metallic=0.85, roughness=0.45)
    plain_material("FF_steel", (0.55, 0.57, 0.6), metallic=0.9, roughness=0.35)
    plain_material("FF_bluepaint", (0.22, 0.42, 0.85), metallic=0.55, roughness=0.42)
    plain_material("FF_lightsteel", (0.7, 0.72, 0.75), metallic=0.9, roughness=0.3)
    plain_material("FF_copper", (0.72, 0.35, 0.16), metallic=0.95, roughness=0.3)
    plain_material("FF_hazard", (0.85, 0.65, 0.05), metallic=0.2, roughness=0.6)
    plain_material("FF_glass", (0.6, 0.85, 1.0), metallic=0.0, roughness=0.1)
    plain_material("FF_fire", (1.0, 0.4, 0.05), emissive=(1.0, 0.3, 0.02))
    plain_material("FF_greenlamp", (0.05, 0.8, 0.2), emissive=(0.05, 0.8, 0.2))
    plain_material("FF_redlamp", (0.9, 0.1, 0.1), emissive=(0.9, 0.1, 0.1))
    plain_material("FF_orange", (0.85, 0.45, 0.08), metallic=0.3, roughness=0.5)
    plain_material("FF_chitin", (0.35, 0.08, 0.08), metallic=0.1, roughness=0.45)
    plain_material("FF_chitin_dark", (0.2, 0.04, 0.05), metallic=0.1, roughness=0.6)
    plain_material("FF_nest", (0.3, 0.08, 0.15), metallic=0.0, roughness=0.7)
    plain_material("FF_sac", (0.4, 0.8, 0.1), emissive=(0.35, 0.75, 0.1))
    plain_material("FF_visor", (0.05, 0.1, 0.14), metallic=0.9, roughness=0.15)
    plain_material("FF_brick", (0.48, 0.27, 0.18), metallic=0.0, roughness=0.85)
    plain_material("FF_chemgreen", (0.2, 0.55, 0.3), metallic=0.5, roughness=0.45)
    plain_material("FF_gunmetal", (0.3, 0.28, 0.22), metallic=0.8, roughness=0.5)
    plain_material("FF_pearl", (0.82, 0.84, 0.88), metallic=0.4, roughness=0.3)
    plain_material("FF_refpurple", (0.45, 0.25, 0.5), metallic=0.6, roughness=0.45)
    plain_material("FF_solarcell", (0.08, 0.16, 0.45), metallic=0.7, roughness=0.25)


def isolate(name):
    """Show only this collection's objects (for review screenshots)."""
    for o in bpy.data.objects:
        if o.type == "MESH":
            o.hide_viewport = not (o.name in bpy.data.collections.get(name).objects
                                   if bpy.data.collections.get(name) else False)
    for cname in list(bpy.data.collections):
        if cname.startswith("FF_") and cname != name:
            for o in bpy.data.collections[cname].objects:
                o.hide_viewport = True
    for o in bpy.data.collections.get(name).objects:
        o.hide_viewport = False


def prep_web(collection_name):
    """Duplicate a collection's materials for web export, keeping only
    diff/normal/rough/alpha maps (drops displacement etc.). Idempotent."""
    c = bpy.data.collections.get(collection_name)
    keep = ("diff", "nor", "rough", "alpha", "mask", "metal")
    for o in c.objects:
        for slot in o.material_slots:
            m = slot.material
            if not m:
                continue
            if m.name.endswith("_WEB"):
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


def frame_camera_target(target=(0, 1, 0), dist=7.0, yaw=0.785, pitch=0.9):
    cam = bpy.data.objects.get("Camera")
    if not cam:
        cam = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
        bpy.context.scene.collection.objects.link(cam)
    tx, ty, tz = target[0], target[2], target[1]  # Blender x, y(game z), z(game up)
    cx = tx + dist * math.cos(yaw) * math.cos(pitch)
    cy = ty + dist * math.sin(yaw) * math.cos(pitch)
    cz = tz + dist * math.sin(pitch)
    cam.location = (cx, cy, cz)
    from mathutils import Vector
    d = Vector((tx - cx, ty - cy, tz - cz))
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam
    # drive the visible viewport directly (user view), not just the camera
    from mathutils import Vector, Quaternion
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
