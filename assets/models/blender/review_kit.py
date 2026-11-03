"""Game1 — Blender review scene (runs inside Justin's Blender on the Mac).
Imports the kit GLBs side by side and adds the 'city magic' concept: rune rings + crystals orbiting the white tower.
Press Space (play) in the viewport to watch the magic circle.
"""
import bpy, math, os, glob

ROOT = os.environ.get("GAME1_ROOT", "/Users/ceojs/Game Ideas/Roblox Builder/Games/Game1/Assets/Models")
KIT = os.environ.get("GAME1_KIT", "Kit1_v2")

# --- clean scene -------------------------------------------------------------
for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob, do_unlink=True)
for col in list(bpy.data.collections):
    bpy.data.collections.remove(col)

def new_col(name):
    c = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(c)
    return c

def move_to(obs, col):
    for o in obs:
        for c in list(o.users_collection):
            c.objects.unlink(o)
        col.objects.link(o)

# --- import the kit in a row -----------------------------------------------
order = ["Cottage", "Townhouse", "WhiteTower", "GothicTower", "DarkSpire"]
x = 0.0
anchors = {}
for key in order:
    path = os.path.join(ROOT, KIT, f"{key}_All.glb")
    if not os.path.exists(path):
        path = os.path.join(ROOT, KIT, key, f"{key}_All.glb")
    if not os.path.exists(path):
        print("missing", key); continue
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    col = new_col(key)
    move_to(new, col)
    root = bpy.data.objects.new(f"{key}_Root", None)
    col.objects.link(root)
    for o in new:
        if o.parent is None:
            o.parent = root
    root.location = (x, 0, 0)
    anchors[key] = root
    x += 45.0

# --- city magic: rune rings + orbiting crystals ----------------------------
def emit_mat(name, rgb, strength):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*rgb, 1)
    em.inputs["Strength"].default_value = strength
    nt.links.new(em.outputs[0], out.inputs[0])
    return m

CYAN = emit_mat("Magic_Cyan", (0.25, 0.85, 1.0), 6)
VIOLET = emit_mat("Magic_Violet", (0.65, 0.3, 1.0), 6)
GOLD = emit_mat("Magic_Gold", (1.0, 0.75, 0.25), 4)

magic = new_col("CityMagic")
centre = anchors.get("WhiteTower")
cx = centre.location.x if centre else 0

def spinner(name, z, speed_turns, tilt_deg):
    e = bpy.data.objects.new(name, None)
    magic.objects.link(e)
    e.location = (cx, 0, z)
    e.rotation_euler = (math.radians(tilt_deg), 0, 0)
    # linear spin over the timeline
    sc = bpy.context.scene
    e.rotation_mode = "XYZ"
    e.keyframe_insert("rotation_euler", index=2, frame=sc.frame_start)
    e.rotation_euler[2] = math.tau * speed_turns
    e.keyframe_insert("rotation_euler", index=2, frame=sc.frame_end)
    try:
        for fc in e.animation_data.action.fcurves:
            for k in fc.keyframe_points:
                k.interpolation = "LINEAR"
    except Exception:
        pass
    return e

def torus(name, major, minor, parent, mat):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=48, minor_segments=6)
    o = bpy.context.active_object
    o.name = name
    move_to([o], magic)
    o.parent = parent
    o.data.materials.append(mat)
    return o

def block(name, loc, size, rot_z, parent, mat):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=(0, 0, rot_z))
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    move_to([o], magic)
    o.parent = parent
    o.data.materials.append(mat)
    return o

def crystal(name, loc, h, parent, mat):
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.9, radius2=0, depth=h, location=loc)
    top = bpy.context.active_object
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.9, radius2=0, depth=h * 0.6,
                                    location=(loc[0], loc[1], loc[2] - h * 0.8), rotation=(math.pi, 0, 0))
    bot = bpy.context.active_object
    bpy.ops.object.select_all(action="DESELECT")
    top.select_set(True); bot.select_set(True)
    bpy.context.view_layer.objects.active = top
    bpy.ops.object.join()
    top.name = name
    move_to([top], magic)
    top.parent = parent
    top.data.materials.append(mat)
    return top

rings_path = os.path.join(ROOT, KIT, "MagicRings_All.glb")
if not os.path.exists(rings_path):
    rings_path = os.path.join(ROOT, KIT, "MagicRings", "MagicRings_All.glb")
if os.path.exists(rings_path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=rings_path)
    new = [o for o in bpy.data.objects if o not in before]
    move_to(new, magic)
    spec = {"RuneBand": ("RuneRing_Low", 22, 1, 6), "Halo": ("RuneRing_High", 64, -1.5, -10), "Crystals": ("CrystalOrbit", 34, 2, 0)}
    for o in new:
        for key, (nm, z, turns, tilt) in spec.items():
            if key in o.name and o.parent is None:
                o.parent = spinner(nm, z, turns, tilt)
                o.location = (0, 0, 0)
                for slot in o.material_slots:
                    slot.material = {"RuneBand": CYAN, "Halo": VIOLET, "Crystals": GOLD}[key]
else:
    # Ring 1: big cyan rune band, slow, slightly tilted
    r1 = spinner("RuneRing_Low", 22, 1, 6)
    torus("RuneBand_Low", 20, 0.25, r1, CYAN)
    for i in range(16):
        a = math.tau * i / 16
        block(f"Rune_{i}", (math.cos(a) * 20, math.sin(a) * 20, 0), (1.6, 0.25, 2.2 if i % 2 else 1.2), a + math.pi / 2, r1, CYAN)

    # Ring 2: violet halo higher up, counter-spin, opposite tilt
    r2 = spinner("RuneRing_High", 64, -1.5, -10)
    torus("RuneBand_High", 13, 0.18, r2, VIOLET)
    torus("RuneBand_High2", 14.5, 0.12, r2, VIOLET)

    # Orbiting crystals (gold), faster
    r3 = spinner("CrystalOrbit", 34, 2, 0)
    for i in range(6):
        a = math.tau * i / 6
        crystal(f"Crystal_{i}", (math.cos(a) * 26, math.sin(a) * 26, math.sin(a * 2) * 3), 4.5, r3, GOLD)


# --- look --------------------------------------------------------------------
sc = bpy.context.scene
sc.frame_end = 240
try:
    sc.eevee.use_bloom = True  # older Eevee
except Exception:
    pass
world = sc.world or bpy.data.worlds.new("World")
sc.world = world
world.use_nodes = True
bg = world.node_tree.nodes.get("Background")
if bg:
    bg.inputs[0].default_value = (0.9, 0.55, 0.3, 1)  # golden hour
    bg.inputs[1].default_value = 0.6
sun = bpy.data.lights.new("Sun", "SUN"); sun.energy = 3.5; sun.color = (1.0, 0.82, 0.6)
so = bpy.data.objects.new("Sun", sun); so.rotation_euler = (math.radians(55), 0, math.radians(35))
sc.collection.objects.link(so)

for area in bpy.context.screen.areas:
    if area.type == "VIEW_3D":
        for space in area.spaces:
            if space.type == "VIEW_3D":
                space.shading.type = "MATERIAL"
                space.clip_end = 5000
        region = next(r for r in area.regions if r.type == "WINDOW")
        with bpy.context.temp_override(area=area, region=region):
            bpy.ops.object.select_all(action="SELECT")
            bpy.ops.view3d.view_selected()
            bpy.ops.object.select_all(action="DESELECT")
print("Game1 review scene ready")
