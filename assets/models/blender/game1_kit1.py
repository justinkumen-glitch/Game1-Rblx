"""Game1 Kit 1: settlement buildings (village cottage, city townhouse, white city tower, dark citadel spire).
Headless Blender 5.2 (bpy). 1 Blender unit = 1 stud. Uses the LihFolk house builders.
Run: blenv/bin/python game1_kit1.py <out_dir>
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "lib"))
import bpy  # noqa: E402
import lihfolk_bpy as lf  # noqa: E402
import lihfolk_curves as lc  # noqa: E402
import lihfolk_house as lh  # noqa: E402

OUT = sys.argv[1] if len(sys.argv) > 1 else "/home/claude/blender/out"
os.makedirs(OUT, exist_ok=True)
H = lc.hex_rgb


def clear():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)


GLASS = dict(frame=H("#3b2a1e"), mullion=H("#2a1d14"), glass=H("#ffb347"))
DOOR = dict(colours=[H("#6b4428"), H("#5c3a22"), H("#74492b")], batten=H("#3e2716"), frame=H("#3b2a1e"), knob=H("#c9a24a"))


def build_house(name, *, hx, hy, eave_z, pitch, stone, mortar, quoin, roof_cols, roof_style, ridge, storeys, seed):
    rng = random.Random(seed)
    t = 1.2
    plinth = 0.6
    base = lh.MeshBuilder(f"{name}_Foundation", rng)
    walls = lh.MeshBuilder(f"{name}_Walls", rng)
    roof = lh.MeshBuilder(f"{name}_Roof", rng)
    chim = lh.MeshBuilder(f"{name}_Chimney", rng)
    trim = lh.MeshBuilder(f"{name}_Trim", rng)
    glow = lh.MeshBuilder(f"{name}_Glow", rng)
    door = lh.MeshBuilder(f"{name}_Door", rng)

    gable = lh.Gable(hx + t / 2, eave_z, pitch)
    floor_h = (eave_z - plinth) / storeys
    # Openings in face coordinates (u centred on the wall, z absolute)
    front = [(-1.9, 1.9, plinth, plinth + 7.6)]
    side_w = 2.2
    win_rows = [plinth + floor_h * k + floor_h * 0.5 for k in range(storeys)]
    front_wins = []
    for k, zc in enumerate(win_rows):
        us = (-hx * 0.62, hx * 0.62) if k == 0 else (-hx * 0.62, 0.0, hx * 0.62)
        for u in us:
            if k == 0 or True:
                front_wins.append((u, zc))
    openings = {"-Y": list(front), "+X": [], "-X": []}
    for u, zc in front_wins:
        openings["-Y"].append((u - side_w / 2, u + side_w / 2, zc - 1.4, zc + 1.4))
    side_wins = []
    for zc in win_rows:
        for u in (-hy * 0.45, hy * 0.45):
            side_wins.append((u, zc))
            openings["+X"].append((u - side_w / 2, u + side_w / 2, zc - 1.4, zc + 1.4))
            openings["-X"].append((u - side_w / 2, u + side_w / 2, zc - 1.4, zc + 1.4))

    faces, ops, ch = lh.coursed_walls(walls, hx, hy, thickness=t, z0=plinth, eave_z=eave_z, gable=gable,
                                      openings=openings, colours=stone, mortar=mortar, quoin=quoin)
    lh.foundation(base, hx, hy, t / 2, height=plinth, colour=H("#4a4440"))
    lh.gable_roof(roof, gable, hy + t / 2, style=roof_style, rows=dict(width=1.3, thick=0.22, tilt=4, colours=roof_cols),
                  ridge=dict(colour=ridge, width=1.0, height=0.6), colour=roof_cols[0])
    top = gable.under(hx * 0.45) + 4.5
    lh.chimney(chim, hx * 0.45, hy * 0.55, gable.under(hx * 0.45) - 1.0, top, colours=[H("#6e665e"), H("#5f5850")],
               crown=H("#3f3a36"), flue=H("#1e1b19"))

    # Windows and door at the snapped opening centres
    for key, rects in ops.items():
        face = faces[key]
        for (u0, u1, z0, z1) in rects:
            w, h = u1 - u0, z1 - z0
            if key == "-Y" and h > 6.5:
                lh.door(door, face, (u0 + u1) / 2, z0, w, h, recess=0.3, **DOOR)
            else:
                lh.window(trim, glow, face, (u0 + u1) / 2, (z0 + z1) / 2, w - 0.1, h - 0.1, recess=t / 2,
                          colours=GLASS, shutters=None)
    mods = [b.to_object() for b in (base, walls, roof, chim, trim, glow, door)]
    return mods


def build_white_tower(name, seed):
    """Round white-stone city tower with a blue cone roof (royal castle vibe, original shape)."""
    rng = random.Random(seed)
    body = lh.MeshBuilder(f"{name}_Body", rng)
    roof = lh.MeshBuilder(f"{name}_Roof", rng)
    glow = lh.MeshBuilder(f"{name}_Glow", rng)
    stone = lh.by_normal(H("#e9e4d8"), H("#d9d2c2"), H("#a69e8e"))
    band = H("#bdb5a5")
    r, h = 6.5, 34.0
    body.cyl((0, 0, 0), (0, 0, 2.0), r + 0.9, 16, band, band, band)           # plinth
    body.cyl((0, 0, 2.0), (0, 0, h), r, 16, stone, H("#cfc8b8"), H("#cfc8b8"))
    for z in (12.0, 23.0):
        body.cyl((0, 0, z), (0, 0, z + 0.8), r + 0.35, 16, band, band, band)  # string courses
    body.cyl((0, 0, h), (0, 0, h + 2.2), r + 1.4, 16, stone, band, band)     # machicolation ring
    for i in range(10):                                                      # crenels
        a = 2 * math.pi * i / 10
        cx, cy = math.cos(a) * (r + 0.9), math.sin(a) * (r + 0.9)
        body.box((cx - 0.8, cy - 0.8, h + 2.2), (cx + 0.8, cy + 0.8, h + 4.0), stone)
    roof.cyl((0, 0, h + 2.0), (0, 0, h + 3.0), r + 0.6, 16, H("#2f4f8f"), H("#2a457d"), H("#2a457d"))
    roof.cone((0, 0, h + 3.0), (0, 0, h + 22.0), r + 0.6, 16, lh.by_normal(H("#4a73c2"), H("#3b62ad"), H("#2a457d")))
    roof.cyl((0, 0, h + 21.5), (0, 0, h + 25.0), 0.18, 6, H("#c9a24a"))       # finial
    for z in (8.0, 18.0, 28.0):                                              # lit slit windows
        for i in range(4):
            a = math.pi / 4 + 2 * math.pi * i / 4 + z
            cx, cy = math.cos(a) * (r + 0.05), math.sin(a) * (r + 0.05)
            M = lf_rot_z(a)
            glow.obox((cx, cy, z), (0.5, 1.0, 2.6), M, H("#ffd27a"))
    return [b.to_object() for b in (body, roof, glow)]


def lf_rot_z(a):
    from mathutils import Matrix
    return Matrix.Rotation(a, 3, "Z")


def build_dark_spire(name, seed):
    """Twisted dark citadel spire with glowing windows (gothic cliff-castle vibe, original shape)."""
    rng = random.Random(seed)
    body = lh.MeshBuilder(f"{name}_Body", rng)
    glow = lh.MeshBuilder(f"{name}_Glow", rng)
    dark = lh.by_normal(H("#4a3a33"), H("#3a2c27"), H("#1f1714"))
    trimc = H("#2a1f1b")
    z = 0.0
    tiers = [(9.0, 12.0), (7.0, 11.0), (5.4, 10.0), (4.2, 9.0)]
    offset = 0.0
    for i, (rad, th) in enumerate(tiers):
        x0 = offset
        body.cyl((x0, 0, z), (x0 + 0.6, 0, z + th), rad, 10, dark, trimc, trimc, r1=rad * 0.92)
        body.cyl((x0 + 0.6, 0, z + th), (x0 + 0.6, 0, z + th + 1.0), rad * 1.08, 10, trimc, trimc, trimc)
        for k in range(6):                                                     # pointed merlons
            a = 2 * math.pi * k / 6 + i * 0.4
            cx, cy = x0 + 0.6 + math.cos(a) * rad, math.sin(a) * rad
            body.cone((cx, cy, z + th + 1.0), (cx, cy, z + th + 3.2), 0.7, 5, trimc)
        for k in range(3):                                                     # glowing windows
            a = 2 * math.pi * k / 3 + i
            cx, cy = x0 + 0.3 + math.cos(a) * (rad * 0.96), math.sin(a) * (rad * 0.96)
            glow.obox((cx, cy, z + th * 0.55), (0.6, 0.9, 1.8), lf_rot_z(a), H("#ffcc55"))
        z += th + 1.0
        offset += 0.6
    body.cone((offset, 0, z), (offset + 1.2, 0, z + 14.0), 3.0, 8, dark)       # needle spire
    return [b.to_object() for b in (body, glow)]


def finish(mods):
    glow = tuple(m.name for m in mods if m.name.endswith("_Glow"))
    fin = {m.name: dict(style="soft", bevel_width=0.06, smooth_angle=35) for m in mods}
    lh.recentre(mods)
    lh.finish_modules(mods, fin, glow=glow)


def run():
    lf.setup_scene()
    builds = {
        "Cottage": lambda: build_house("Cottage", hx=6.5, hy=8.0, eave_z=9.0, pitch=50, storeys=1, seed=3,
                                       stone=[H("#b8955f"), H("#a9864f"), H("#c4a26c")], mortar=H("#5a4a38"),
                                       quoin=H("#d8c39a"), roof_cols=[H("#8a6a3a"), H("#7c5e32"), H("#95744a")],
                                       roof_style="rows", ridge=H("#5e4626")),
        "Townhouse": lambda: build_house("Townhouse", hx=7.0, hy=7.5, eave_z=17.0, pitch=48, storeys=2, seed=8,
                                         stone=[H("#e3d6bd"), H("#d6c8ad"), H("#ecdfc6")], mortar=H("#7a6c58"),
                                         quoin=H("#b9a88a"), roof_cols=[H("#c4562f"), H("#b44b28"), H("#d26338")],
                                         roof_style="rows", ridge=H("#8e3a1e")),
        "WhiteTower": lambda: build_white_tower("WhiteTower", 5),
        "DarkSpire": lambda: build_dark_spire("DarkSpire", 9),
    }
    report = {}
    for key, fn in builds.items():
        clear()
        mods = fn()
        finish(mods)
        tris = 0
        for m in mods:
            dg = bpy.context.evaluated_depsgraph_get()
            me = m.evaluated_get(dg).to_mesh()
            me.calc_loop_triangles()
            tris += len(me.loop_triangles)
            m.evaluated_get(dg).to_mesh_clear()
        floating = lh.floating_shells(mods, base_names=tuple(m.name for m in mods if "Foundation" in m.name or "Body" in m.name))
        lh.render_preview(mods, os.path.join(OUT, f"{key}_preview.png"), size=(900, 900))
        lh.export_modules(mods, os.path.join(OUT, key), combined=f"{key}_All")
        report[key] = dict(tris=tris, floating=floating if isinstance(floating, int) else (len(floating) if hasattr(floating, "__len__") else floating))
    print("REPORT", report)


run()
