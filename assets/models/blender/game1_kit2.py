"""Game1 Kit 2 (v2 of Kit 1): lighter houses, gothic citadel tower, city magic rings.
Based on Kit 1: settlement buildings (village cottage, city townhouse, white city tower, dark citadel spire).
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


def build_house(name, *, hx, hy, eave_z, pitch, stone, mortar, quoin, roof_cols, roof_style, ridge, storeys, seed, course_h=2.0, block_len=(3.8, 5.8), row_w=2.4):
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
                                      openings=openings, colours=stone, mortar=mortar, quoin=quoin,
                                      course_h=course_h, block_len=block_len)
    lh.foundation(base, hx, hy, t / 2, height=plinth, colour=H("#4a4440"))
    lh.gable_roof(roof, gable, hy + t / 2, style=roof_style, rows=dict(width=row_w, thick=0.22, tilt=4, colours=roof_cols),
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


def build_gothic_tower(name, seed):
    """Asymmetric gothic citadel tower: octagonal shaft, buttresses, two offset turrets, crooked spires, glowing slits."""
    from mathutils import Matrix
    rng = random.Random(seed)
    body = lh.MeshBuilder(f"{name}_Body", rng)
    roof = lh.MeshBuilder(f"{name}_Roof", rng)
    glow = lh.MeshBuilder(f"{name}_Glow", rng)
    dark = lh.by_normal(H("#4a4048"), H("#383039"), H("#1d181e"))
    trimc = H("#231c24")
    slate = lh.by_normal(H("#3a2f45"), H("#2c2336"), H("#1a1420"))
    lit = H("#ffc65a")

    def Rz(a):
        return Matrix.Rotation(a, 3, "Z")

    def slits(cx, cy, r, zs, n, phase, size=(0.6, 1.0, 3.2)):
        for z in zs:
            for k in range(n):
                a = phase + 2 * math.pi * k / n + z * 0.37
                glow.obox((cx + math.cos(a) * r, cy + math.sin(a) * r, z), size, Rz(a), lit)

    # main shaft
    body.cyl((0, 0, 0), (0, 0, 3.0), 8.2, 8, dark, trimc, trimc)
    body.cyl((0, 0, 3.0), (0, 0, 42.0), 6.2, 8, dark, trimc, trimc, r1=5.4)
    for z in (16.0, 29.0):
        body.cyl((0, 0, z), (0, 0, z + 0.9), 6.3 - (z / 42) * 0.8 + 0.35, 8, trimc, trimc, trimc)
    body.cyl((0, 0, 42.0), (0, 0, 44.0), 6.6, 8, trimc, trimc, trimc)
    for k in range(8):                                   # spiky merlons
        a = 2 * math.pi * k / 8 + math.pi / 8
        body.cone((math.cos(a) * 6.2, math.sin(a) * 6.2, 44.0), (math.cos(a) * 6.4, math.sin(a) * 6.4, 47.5), 0.8, 4, trimc)
    roof.cone((0, 0, 44.0), (1.8, 0.9, 72.0), 5.2, 8, slate)               # crooked main spire
    roof.cyl((1.8, 0.9, 71.5), (2.0, 1.0, 76.0), 0.15, 4, H("#8a6a3a"))
    # buttresses (stepped, leaning in)
    for k, a in enumerate((math.pi * 0.25, math.pi * 0.75, math.pi * 1.25, math.pi * 1.75)):
        h = 14.0 + (k % 2) * 6.0
        r = 7.6
        body.obox((math.cos(a) * r, math.sin(a) * r, h / 2), (3.2, 1.8, h), Rz(a), dark)
        top = Rz(a) @ Matrix.Rotation(math.radians(-35), 3, "Y")
        body.obox((math.cos(a) * (r - 1.0), math.sin(a) * (r - 1.0), h + 1.4), (3.0, 1.6, 3.6), top, trimc)
    # turret A (tall, east)
    ax, ay = 6.4, 2.6
    body.cyl((ax, ay, 14.0), (ax, ay, 50.0), 2.7, 8, dark, trimc, trimc)
    body.cone((ax, ay, 14.0), (ax - 1.0, ay - 0.4, 9.0), 2.7, 8, trimc)       # corbel
    body.cyl((ax, ay, 50.0), (ax, ay, 51.2), 3.1, 8, trimc, trimc, trimc)
    roof.cone((ax, ay, 51.2), (ax + 1.2, ay + 0.6, 64.0), 3.0, 8, slate)
    slits(ax, ay, 2.72, (24.0, 36.0, 46.0), 3, 0.2, (0.5, 0.8, 2.4))
    # turret B (short, west)
    bx, by = -5.8, -3.6
    body.cyl((bx, by, 0.0), (bx, by, 32.0), 3.2, 8, dark, trimc, trimc)
    body.cyl((bx, by, 32.0), (bx, by, 33.2), 3.6, 8, trimc, trimc, trimc)
    roof.cone((bx, by, 33.2), (bx - 0.8, by - 1.0, 44.0), 3.5, 8, slate)
    slits(bx, by, 3.22, (10.0, 22.0), 3, 1.1, (0.5, 0.8, 2.4))
    # bartizan (small hanging turret, south)
    cx_, cy_ = 0.8, -6.4
    body.cyl((cx_, cy_, 30.0), (cx_, cy_, 35.0), 1.7, 8, dark, trimc, trimc)
    body.cone((cx_, cy_, 30.0), (cx_, cy_ + 0.4, 26.0), 1.7, 8, trimc)
    roof.cone((cx_, cy_, 35.0), (cx_ + 0.3, cy_ - 0.3, 41.0), 1.9, 8, slate)
    # main shaft windows
    slits(0, 0, 5.8, (9.0, 22.0, 35.0), 4, 0.4)
    glow.obox((0, -5.95, 3.0 + 3.2), (3.0, 0.6, 6.4), Rz(0), H("#ff9d3a"))          # lit doorway
    return [b.to_object() for b in (body, roof, glow)]


def ring_segments(b, r, z, n, w, h, col, tilt=0.0):
    from mathutils import Matrix
    for k in range(n):
        a = 2 * math.pi * k / n
        seg = 2 * math.pi * r / n * 1.04
        p = (math.cos(a) * r, math.sin(a) * r, z + math.sin(a) * math.tan(tilt) * r)
        M = Matrix.Rotation(a, 3, "Z") @ Matrix.Rotation(-math.atan(math.tan(tilt) * math.cos(a)), 3, "X")
        b.obox(p, (w, seg, h), M, col)


def build_magic_rings(name, seed):
    """City magic: rune band (low), double halo (high), orbit crystals. Separate modules so Studio can spin each."""
    from mathutils import Matrix
    rng = random.Random(seed)
    low = lh.MeshBuilder(f"{name}_RuneBand", rng)
    high = lh.MeshBuilder(f"{name}_Halo", rng)
    crys = lh.MeshBuilder(f"{name}_Crystals", rng)
    cyan, violet, gold = H("#5fe3ff"), H("#b07bff"), H("#ffd36b")
    ring_segments(low, 20.0, 0.0, 40, 0.5, 0.5, cyan)
    for k in range(16):                                   # rune plates on the band
        a = 2 * math.pi * k / 16
        low.obox((math.cos(a) * 20.0, math.sin(a) * 20.0, 0.0), (0.4, 1.6, 2.4 if k % 2 else 1.4),
                 Matrix.Rotation(a, 3, "Z"), cyan)
    ring_segments(high, 13.0, 0.0, 32, 0.35, 0.35, violet)
    ring_segments(high, 14.6, 0.0, 32, 0.25, 0.25, violet)
    for k in range(6):                                    # double-pointed crystals
        a = 2 * math.pi * k / 6
        x, y, z = math.cos(a) * 26.0, math.sin(a) * 26.0, 0.0
        crys.cone((x, y, z), (x, y, z + 3.2), 1.0, 4, gold)
        crys.cone((x, y, z), (x, y, z - 2.0), 1.0, 4, gold)
    return [b.to_object() for b in (low, high, crys)]


def build_dark_magic(name, seed):
    """Sinister citadel magic: broken crimson thorn band, downward-spiked ghost-green crown, jagged obsidian shards
    with crimson tips. Same layout as MagicRings so it spins the same way in Studio."""
    from mathutils import Matrix
    rng = random.Random(seed)
    band = lh.MeshBuilder(f"{name}_ThornBand", rng)
    crown = lh.MeshBuilder(f"{name}_Crown", rng)
    shards = lh.MeshBuilder(f"{name}_Shards", rng)
    tips = lh.MeshBuilder(f"{name}_ShardGlow", rng)
    crimson, ghost, obsidian = H("#ff2238"), H("#6bff8f"), lh.by_normal(H("#2a2030"), H("#1c1522"), H("#0e0a12"))
    # broken band: 5 arcs with gaps, thorns pointing out and up
    r = 19.0
    for arc in range(5):
        a0 = 2 * math.pi * arc / 5 + rng.uniform(-0.08, 0.08)
        n = 6
        for k in range(n):
            a = a0 + (2 * math.pi / 5) * 0.72 * k / (n - 1)
            seg = 2 * math.pi * r / 5 * 0.72 / (n - 1) * 1.05
            z = math.sin(a * 3) * 0.6                                    # wobble, not a clean circle
            band.obox((math.cos(a) * r, math.sin(a) * r, z), (0.6, seg, 0.6), Matrix.Rotation(a, 3, "Z"), crimson)
            if k % 2 == 0:
                out = r + rng.uniform(2.2, 3.6)
                band.cone((math.cos(a) * r, math.sin(a) * r, z), (math.cos(a) * out, math.sin(a) * out, z + rng.uniform(0.5, 2.0)),
                          0.45, 4, crimson)
    # crown above the spire: jagged ring with spikes hanging DOWN
    rc = 9.0
    for k in range(28):
        a = 2 * math.pi * k / 28
        seg = 2 * math.pi * rc / 28 * 1.05
        crown.obox((math.cos(a) * rc, math.sin(a) * rc, 0.0), (0.35, seg, 0.35), Matrix.Rotation(a, 3, "Z"), ghost)
    for k in range(9):
        a = 2 * math.pi * k / 9 + 0.2
        L = rng.uniform(2.0, 4.5)
        crown.cone((math.cos(a) * rc, math.sin(a) * rc, 0.0), (math.cos(a) * rc * 0.92, math.sin(a) * rc * 0.92, -L), 0.4, 4, ghost)
        crown.cone((math.cos(a + 0.35) * rc, math.sin(a + 0.35) * rc, 0.0),
                   (math.cos(a + 0.35) * rc * 1.05, math.sin(a + 0.35) * rc * 1.05, 1.4), 0.3, 4, ghost)
    # obsidian shards, uneven sizes and heights, crimson glowing tips
    for k in range(7):
        a = 2 * math.pi * k / 7 + rng.uniform(-0.2, 0.2)
        rr = rng.uniform(23.0, 28.0)
        x, y, z = math.cos(a) * rr, math.sin(a) * rr, rng.uniform(-4.0, 4.0)
        h = rng.uniform(3.0, 6.0)
        lean = (rng.uniform(-0.8, 0.8), rng.uniform(-0.8, 0.8))
        shards.cone((x, y, z), (x + lean[0], y + lean[1], z + h * 0.7), 1.1, 4, obsidian)
        shards.cone((x, y, z), (x - lean[0] * 0.4, y - lean[1] * 0.4, z - h * 0.45), 1.1, 4, obsidian)
        tips.cone((x + lean[0] * 0.7, y + lean[1] * 0.7, z + h * 0.49), (x + lean[0], y + lean[1], z + h * 0.7 + 0.15), 0.36, 4, crimson)
    return [b.to_object() for b in (band, crown, shards, tips)]


MAGIC_GLOW = {
    "MagicRings_RuneBand": (0.37, 0.89, 1.0), "MagicRings_Halo": (0.69, 0.48, 1.0), "MagicRings_Crystals": (1.0, 0.83, 0.42),
    "DarkMagic_ThornBand": (1.0, 0.08, 0.15), "DarkMagic_Crown": (0.42, 1.0, 0.56), "DarkMagic_ShardGlow": (1.0, 0.08, 0.15),
}


def finish(mods):
    glow = tuple(m.name for m in mods if m.name.endswith("_Glow") or (m.name in MAGIC_GLOW))
    fin = {m.name: (dict(style="faceted") if m.name.endswith(("_Walls", "_Body")) or m.name.startswith(("MagicRings_", "DarkMagic_")) else dict(style="soft", bevel_width=0.06, smooth_angle=35)) for m in mods}
    lh.recentre(mods)
    lh.finish_modules(mods, fin, glow=glow)
    for m in mods:
        if m.name in MAGIC_GLOW:
            lh.glow_material(m, rgb=MAGIC_GLOW[m.name], strength=6.0, name=f"Glow_{m.name}")


ONLY = sys.argv[2].split(",") if len(sys.argv) > 2 else None


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
        "GothicTower": lambda: build_gothic_tower("GothicTower", 9),
        "MagicRings": lambda: build_magic_rings("MagicRings", 4),
        "DarkMagic": lambda: build_dark_magic("DarkMagic", 13),
    }
    report = {}
    for key, fn in builds.items():
        if ONLY and key not in ONLY:
            continue
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
        floating = lh.floating_shells(mods, base_names=tuple(m.name for m in mods if "Foundation" in m.name or "Body" in m.name or m.name.startswith(("MagicRings_", "DarkMagic_"))))
        lh.render_preview(mods, os.path.join(OUT, f"{key}_preview.png"), size=(900, 900))
        lh.export_modules(mods, os.path.join(OUT, key), combined=f"{key}_All")
        report[key] = dict(tris=tris, floating=floating if isinstance(floating, int) else (len(floating) if hasattr(floating, "__len__") else floating))
    print("REPORT", report)


run()
