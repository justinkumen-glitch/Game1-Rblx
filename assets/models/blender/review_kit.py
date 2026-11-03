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
order = ["Cottage", "Townhouse", "WhiteTower", "GothicTower"]
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
    x += 70.0

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

CYAN = emit_mat("Magic_Cyan", (0.25, 0.85, 1.0), 2.5)
VIOLET = emit_mat("Magic_Violet", (0.65, 0.3, 1.0), 2.5)
GOLD = emit_mat("Magic_Gold", (1.0, 0.75, 0.25), 2.5)

CRIMSON = emit_mat("Magic_Crimson", (1.0, 0.02, 0.06), 3)
GHOST = emit_mat("Magic_Ghost", (0.25, 1.0, 0.4), 2.5)
magic = new_col("Magic")


def spinner(name, cx, z, speed_turns, tilt_deg):
    e = bpy.data.objects.new(name, None)
    magic.objects.link(e)
    e.location = (cx, 0, z)
    e.rotation_mode = "XYZ"
    e.rotation_euler = (math.radians(tilt_deg), 0, 0)
    sc = bpy.context.scene
    e.keyframe_insert("rotation_euler", index=2, frame=1)
    e.rotation_euler[2] = math.tau * speed_turns
    e.keyframe_insert("rotation_euler", index=2, frame=240)
    try:
        for fc in e.animation_data.action.fcurves:
            for k in fc.keyframe_points:
                k.interpolation = "LINEAR"
    except Exception:
        pass
    return e


def attach_magic(glb_key, anchor_key, spec):
    """spec: {module_suffix: (spinner_name, z, turns, tilt, material or None)}; modules sharing a spinner_name spin together."""
    path = os.path.join(ROOT, KIT, f"{glb_key}_All.glb")
    if not os.path.exists(path):
        path = os.path.join(ROOT, KIT, glb_key, f"{glb_key}_All.glb")
    anchor = anchors.get(anchor_key)
    if not (os.path.exists(path) and anchor):
        print("skip magic", glb_key); return
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    move_to(new, magic)
    spinners = {}
    for o in new:
        if o.parent is not None:
            continue
        for suffix, (nm, z, turns, tilt, mat) in spec.items():
            if o.name.split(".")[0].endswith(suffix):
                key = f"{anchor_key}_{nm}"
                if key not in spinners:
                    spinners[key] = spinner(key, anchor.location.x, z, turns, tilt)
                o.parent = spinners[key]
                o.location = (0, 0, 0)
                if mat:
                    for slot in o.material_slots:
                        slot.material = mat


# Light magic around the white city tower
attach_magic("MagicRings", "WhiteTower", {
    "_RuneBand": ("RuneBand", 22, 1, 6, CYAN),
    "_Halo": ("Halo", 64, -1.5, -10, VIOLET),
    "_Crystals": ("Crystals", 34, 2, 0, GOLD),
})
# Sinister magic around the gothic citadel tower: slower, counter-spinning, wobbling
attach_magic("DarkMagic", "GothicTower", {
    "_ThornBand": ("Thorns", 20, -0.75, 9, CRIMSON),
    "_Crown": ("Crown", 72, 0.5, -5, GHOST),
    "_Shards": ("Shards", 38, 1.25, 4, None),
    "_ShardGlow": ("Shards", 38, 1.25, 4, CRIMSON),
})

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
