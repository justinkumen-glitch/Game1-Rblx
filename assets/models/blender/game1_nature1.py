"""Game1 Nature Kit 1: stylised trees, plants and rocks for all 7 biomes (refs: floating-island + stylised town).
Recipe from the vault (Low-Poly Tree Set Worked Example / Low-Poly and Stylized Modeling):
faceted tapered trunks with root flare, canopy of overlapping displaced icospheres, darker low / lighter on top,
flat shaded, pivot at the trunk base, 150-1,500 tris each. Vertex colours (one material) -> MeshPart.Color white.
1 unit = 1 stud. Run: blenv/bin/python game1_nature1.py <out_dir>
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "lib"))
import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Euler, Matrix, Vector  # noqa: E402

import lihfolk_bpy as lf  # noqa: E402
import lihfolk_curves as lc  # noqa: E402
import lihfolk_house as lh  # noqa: E402

OUT = sys.argv[1] if len(sys.argv) > 1 else "/home/claude/blender/out_nature"
os.makedirs(OUT, exist_ok=True)
H = lc.hex_rgb


def clear():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)


# -- helpers: every face gets a colour; at the end colours go into the "Col" corner attribute --
class Kit:
    def __init__(self, name, seed):
        self.name = name
        self.bm = bmesh.new()
        self.rng = random.Random(seed)
        self.cols = {}  # face -> rgb

    def paint(self, faces, rgb):
        for f in faces:
            self.cols[f] = rgb

    def trunk(self, base, top, r0, r1, sides, rgb, flare=0.0, lean=Vector(), rings=4):
        bm = self.bm
        rs = []
        for i in range(rings + 1):
            t = i / rings
            c = base.lerp(top, t) + lean * (t * t)
            r = r0 + (r1 - r0) * t
            ring = []
            for k in range(sides):
                a = k / sides * math.tau + i * 0.3
                rr = r * (1 + (flare if (i == 0 and k % 2 == 0) else 0) + (flare * 0.4 if (i == 0 and k % 2) else 0))
                ring.append(bm.verts.new(c + Vector((math.cos(a) * rr, math.sin(a) * rr, 0))))
            rs.append(ring)
        faces = [bm.faces.new(list(reversed(rs[0])))]
        for a, b in zip(rs, rs[1:]):
            for k in range(sides):
                faces.append(bm.faces.new((a[k], a[(k + 1) % sides], b[(k + 1) % sides], b[k])))
        faces.append(bm.faces.new(rs[-1]))
        self.paint(faces, rgb)
        return faces

    def blob(self, c, radii, rgb, jitter=0.14, sub=2, flat_under=0.82):
        res = bmesh.ops.create_icosphere(self.bm, subdivisions=sub, radius=1.0)
        for v in res["verts"]:
            n = v.co.normalized()
            d = 1 + self.rng.uniform(-jitter, jitter)
            if n.z < -0.4:
                d *= flat_under
            v.co = Vector((n.x * radii[0] * d, n.y * radii[1] * d, n.z * radii[2] * d)) + Vector(c)
        faces = list({f for v in res["verts"] for f in v.link_faces})
        self.paint(faces, rgb)
        return faces

    def cone(self, z, r, h, segs, rgb, rot=0.0, centre=(0, 0), ragged=0.0, tip=None):
        m = Matrix.Translation((centre[0], centre[1], z + h / 2)) @ Euler((0, 0, rot)).to_matrix().to_4x4()
        res = bmesh.ops.create_cone(self.bm, cap_ends=True, segments=segs, radius1=r, radius2=0.0, depth=h, matrix=m)
        for v in res["verts"]:
            if ragged and v.co.z < z + 0.05:
                k = math.atan2(v.co.y - centre[1], v.co.x - centre[0])
                v.co.z -= ragged * (0.5 + 0.5 * math.sin(k * 4 + rot * 3))
            if tip is not None and v.co.z > z + h - 0.01:
                v.co.x += tip[0]
                v.co.y += tip[1]
        faces = list({f for v in res["verts"] for f in v.link_faces})
        self.paint(faces, rgb)
        return faces

    def box(self, centre, size, rgb, rot=(0, 0, 0)):
        m = Matrix.Translation(centre) @ Euler(rot).to_matrix().to_4x4() @ Matrix.Diagonal((*size, 1))
        res = bmesh.ops.create_cube(self.bm, size=1, matrix=m)
        faces = list({f for v in res["verts"] for f in v.link_faces})
        self.paint(faces, rgb)
        return faces

    def ico(self, c, r, rgb, sub=1, squash=(1, 1, 1), jitter=0.18):
        return self.blob(c, (r * squash[0], r * squash[1], r * squash[2]), rgb, jitter=jitter, sub=sub, flat_under=1.0)

    def shade_by_height(self, faces, z_lo, z_hi, dark, mid, light):
        for f in faces:
            z = f.calc_center_median().z
            t = (z - z_lo) / max(1e-4, z_hi - z_lo)
            up = f.normal.z
            self.cols[f] = dark if (t < 0.35 or up < -0.35) else (light if (t > 0.7 and up > 0.2) else mid)

    def finish(self):
        bm = self.bm
        bm.normal_update()
        me = bpy.data.meshes.new(self.name)
        # write colours via a face-indexed list before converting
        bm.faces.index_update()
        face_cols = [self.cols.get(f, (1, 0, 1)) for f in bm.faces]
        bm.to_mesh(me)
        bm.free()
        attr = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
        for poly in me.polygons:
            rgb = face_cols[poly.index]
            for li in poly.loop_indices:
                attr.data[li].color_srgb = (*rgb, 1.0)
        me.color_attributes.active_color = attr
        for p in me.polygons:
            p.use_smooth = False
        o = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(o)
        lc.vertex_color_material(o)
        me.calc_loop_triangles()
        return o, len(me.loop_triangles)


def lc_lin(rgb):
    # hex_rgb already returns linear floats for Blender colour attributes
    return rgb


# ------------------------------------------------------------------ palette
BARK = H("#6e4630"); BARK_D = H("#4f3121"); BIRCH = H("#e6e0d2"); MARK = H("#2a2420")
G_D, G_M, G_L = H("#2f6e2a"), H("#4e9a36"), H("#86c449")
A_D, A_M, A_L = H("#c4501c"), H("#f08a2a"), H("#ffc04a")
P_D, P_M, P_L = H("#1f5a3a"), H("#2f7a48"), H("#4c9a58")
SNOW, SNOW_S = H("#f4f8ff"), H("#cfe0f0")
DEAD = H("#2e2630"); DEAD_L = H("#463a48")
CACT, CACT_L = H("#3f8f4a"), H("#5cb05e")
PALM_B, PALM_L, PALM_D = H("#a07850"), H("#5cb845"), H("#3c8a33")
MUSH_STEM, MUSH_CAP, MUSH_CAP_D, MUSH_DOT = H("#efe6d6"), H("#d64ad2"), H("#9a2aa0"), H("#ffd0ff")
RED, RED_D, WHITE = H("#e0343e"), H("#a82030"), H("#ffffff")
STONE, STONE_L, STONE_D = H("#8f8c96"), H("#b2afb8"), H("#6c6a74")
ICE, ICE_L = H("#9fd4f4"), H("#d6f0ff")
CRYST, CRYST_L = H("#c44cff"), H("#f0a8ff")
OBS, LAVA = H("#221c26"), H("#ff3a2a")
FLOWERS = [H("#ffe866"), H("#ff8cc0"), H("#b48cff"), H("#ffffff"), H("#ff9a4a")]
STEM = H("#3f8a34")


# ------------------------------------------------------------------ models
def oak(name, seed, d, m, l, h=6.5):
    k = Kit(name, seed)
    k.trunk(Vector((0, 0, 0)), Vector((0, 0, h)), 1.0, 0.55, 7, BARK, flare=0.55)
    for dv, hh, ll in ((Vector((1, 0.3, 0.9)), h * 0.58, 2.6), (Vector((-0.9, -0.4, 1.0)), h * 0.7, 2.2)):
        k.trunk(Vector((0, 0, hh)), Vector((0, 0, hh)) + dv.normalized() * ll, 0.38, 0.2, 6, BARK, rings=2)
    leaves = []
    top = h + 2.1
    for i, (c, r) in enumerate((((0, 0, top), (3.8, 3.6, 3.0)), ((2.7, 0.8, top - 1.2), (2.5, 2.3, 2.1)),
                                ((-2.6, -0.9, top - 0.8), (2.4, 2.4, 2.1)), ((0.6, -2.4, top - 0.6), (2.3, 2.1, 2.0)),
                                ((-0.4, 2.0, top + 1.2), (2.3, 2.1, 1.9)))):
        leaves += k.blob(c, r, m)
    k.shade_by_height(leaves, top - 3, top + 3.3, d, m, l)
    return k.finish()


def pine(name, seed, snow=False, tall=1.0):
    k = Kit(name, seed)
    k.trunk(Vector((0, 0, 0)), Vector((0, 0, 3.2 * tall)), 0.65, 0.42, 6, BARK_D, flare=0.4)
    tiers = [(2.4, 4.1, 3.2), (4.3, 3.4, 3.0), (6.0, 2.7, 2.8), (7.6, 2.0, 2.6), (9.0, 1.3, 2.4)]
    for i, (z, r, h) in enumerate(tiers):
        z *= tall
        fs = k.cone(z, r, h, 8, P_M, rot=i * 0.39, ragged=0.35)
        for f in fs:
            if f.normal.z < -0.2:
                k.cols[f] = P_D
            elif snow and f.normal.z > 0.45:
                k.cols[f] = SNOW if i >= 1 else SNOW_S
            else:
                k.cols[f] = P_L if i >= 3 else P_M
    return k.finish()


def birch(name, seed):
    k = Kit(name, seed)
    lean = Vector((0.9, 0.2, 0))
    k.trunk(Vector((0, 0, 0)), Vector((0, 0, 8.0)), 0.5, 0.28, 6, BIRCH, flare=0.35, lean=lean)
    for i in range(6):
        t = 0.12 + i * 0.13
        c = Vector((0, 0, 8.0 * t)) + lean * (t * t)
        a = k.rng.uniform(0, math.tau)
        r = 0.5 + (0.28 - 0.5) * t
        k.box(c + Vector((math.cos(a) * r, math.sin(a) * r, 0)), (0.14, 0.42, 0.11), MARK, rot=(0, 0, a))
    k.trunk(Vector((0.25, 0.05, 5.0)), Vector((-1.6, 0.4, 7.4)), 0.2, 0.1, 5, BIRCH, rings=2)
    leaves = []
    top = Vector((0, 0, 8.0)) + lean
    for o, r in (((0, 0, 1.2), (2.4, 2.3, 2.2)), ((-1.9, 0.4, -0.2), (1.8, 1.7, 1.6)), ((1.5, -0.8, 0.0), (1.7, 1.6, 1.5)), ((0.3, 1.2, 2.6), (1.5, 1.4, 1.4))):
        leaves += k.blob(top + Vector(o), r, A_M, jitter=0.22)
    k.shade_by_height(leaves, top.z - 1.8, top.z + 4.0, A_D, A_M, A_L)
    return k.finish()


def dead_tree(name, seed):
    k = Kit(name, seed)
    lean = Vector((0.8, -0.3, 0))
    k.trunk(Vector((0, 0, 0)), Vector((0, 0, 9.0)), 0.8, 0.18, 6, DEAD, flare=0.7, lean=lean)
    for (h, d, l, r) in ((4.0, (1, 0.2, 0.9), 3.6, 0.3), (5.5, (-1, 0.5, 0.8), 3.0, 0.26), (7.0, (0.2, -1, 1.1), 2.4, 0.2), (3.0, (-0.6, -0.8, 0.5), 2.2, 0.24)):
        b = Vector((0, 0, h)) + lean * ((h / 9) ** 2)
        e = b + Vector(d).normalized() * l
        k.trunk(b, e, r, 0.06, 5, DEAD_L, rings=2, lean=Vector((0, 0, -0.4)))
    return k.finish()


def cactus(name, seed):
    k = Kit(name, seed)
    k.trunk(Vector((0, 0, 0)), Vector((0, 0, 7.5)), 1.0, 0.95, 8, CACT, rings=3)
    k.ico((0, 0, 7.5), 0.95, CACT_L, sub=1, squash=(1, 1, 0.7), jitter=0.02)
    for side, h, up in ((1, 3.0, 2.8), (-1, 4.2, 2.0)):
        k.trunk(Vector((0, 0, h)), Vector((side * 2.0, 0, h + 0.3)), 0.55, 0.55, 6, CACT, rings=1)
        k.trunk(Vector((side * 2.0, 0, h)), Vector((side * 2.0, 0, h + up)), 0.55, 0.5, 6, CACT, rings=2)
        k.ico((side * 2.0, 0, h + up), 0.5, CACT_L, sub=1, squash=(1, 1, 0.7), jitter=0.02)
    return k.finish()


def palm(name, seed):
    k = Kit(name, seed)
    lean = Vector((2.4, 0.4, 0))
    k.trunk(Vector((0, 0, 0)), Vector((0, 0, 11.0)), 0.6, 0.42, 6, PALM_B, flare=0.4, lean=lean, rings=6)
    top = Vector((0, 0, 11.0)) + lean
    for i in range(7):
        a = i / 7 * math.tau + 0.2
        d = Vector((math.cos(a), math.sin(a), 0))
        # a leaf: long flat box bent down in two pieces
        mid = top + d * 2.1 + Vector((0, 0, -0.35))
        k.box(mid, (4.4, 1.6, 0.2), PALM_L, rot=(0, math.radians(16), a))
        tip = top + d * 5.3 + Vector((0, 0, -2.1))
        k.box(tip, (3.2, 1.2, 0.18), PALM_D, rot=(0, math.radians(44), a))
    k.ico(top + Vector((0, 0, -0.4)), 0.7, H("#7a5a30"), sub=1)
    return k.finish()


def giant_mushroom(name, seed):
    k = Kit(name, seed)
    k.trunk(Vector((0, 0, 0)), Vector((0.4, 0, 8.0)), 1.3, 0.9, 8, MUSH_STEM, flare=0.3)
    cap = k.blob((0.4, 0, 9.0), (5.6, 5.6, 2.8), MUSH_CAP, jitter=0.06, flat_under=0.35)
    for f in cap:
        if f.normal.z < -0.1:
            k.cols[f] = MUSH_CAP_D
    for i in range(6):
        a = i / 6 * math.tau + 0.3
        r = 3.0 + (i % 2) * 0.9
        k.ico((0.4 + math.cos(a) * r, math.sin(a) * r, 10.6 - (r - 3) * 0.5), 0.55, MUSH_DOT, sub=1)
    return k.finish()


def boulder(name, seed, s=1.0, cols=(STONE, STONE_L, STONE_D)):
    k = Kit(name, seed)
    fs = k.ico((0, 0, 1.4 * s), 2.4 * s, cols[0], sub=1, squash=(1.25, 1.0, 0.75), jitter=0.22)
    fs += k.ico((1.9 * s, 0.9 * s, 0.8 * s), 1.4 * s, cols[0], sub=1, squash=(1.1, 1.0, 0.8), jitter=0.2)
    for f in fs:
        k.cols[f] = cols[1] if f.normal.z > 0.55 else (cols[2] if f.normal.z < -0.2 else cols[0])
    return k.finish()


def flowers(name, seed):
    k = Kit(name, seed)
    for i in range(9):
        a = i * 2.39996
        r = 0.4 + (i % 4) * 0.55
        x, y = math.cos(a) * r, math.sin(a) * r
        h = 0.8 + k.rng.uniform(0, 0.6)
        k.box((x, y, h / 2), (0.12, 0.12, h), STEM)
        k.ico((x, y, h + 0.15), 0.32, FLOWERS[i % len(FLOWERS)], sub=1, squash=(1, 1, 0.6), jitter=0.05)
    for i in range(5):  # leaves
        a = i * 1.3
        k.box((math.cos(a) * 0.6, math.sin(a) * 0.6, 0.15), (0.9, 0.35, 0.08), STEM, rot=(0, 0, a))
    return k.finish()


def red_mushrooms(name, seed):
    k = Kit(name, seed)
    for (x, y, s) in ((0, 0, 1.0), (1.4, 0.7, 0.7), (-1.0, 1.1, 0.55)):
        k.trunk(Vector((x, y, 0)), Vector((x, y, 1.3 * s)), 0.35 * s, 0.3 * s, 6, MUSH_STEM, rings=1)
        cap = k.blob((x, y, 1.5 * s), (1.2 * s, 1.2 * s, 0.75 * s), RED, jitter=0.04, sub=1, flat_under=0.3)
        for f in cap:
            if f.normal.z < -0.1:
                k.cols[f] = RED_D
        for j in range(3):
            a = j * 2.1 + x
            k.ico((x + math.cos(a) * 0.6 * s, y + math.sin(a) * 0.6 * s, 1.5 * s + 0.6 * s), 0.16 * s, WHITE, sub=1, jitter=0.0)
    return k.finish()


def ice_spikes(name, seed):
    k = Kit(name, seed)
    for (x, y, r, h, tx, ty) in ((0, 0, 1.4, 8.0, 0.5, 0.2), (1.8, 0.8, 0.9, 5.0, 0.8, 0.3), (-1.4, -1.0, 0.8, 4.0, -0.6, -0.4), (0.6, -1.6, 0.6, 3.0, 0.3, -0.5)):
        fs = k.cone(0, r, h, 5, ICE, centre=(x, y), tip=(tx, ty))
        for f in fs:
            if f.normal.z > 0.3 or (f.normal.x + f.normal.y) > 0.6:
                k.cols[f] = ICE_L
    return k.finish()


def crystal_cluster(name, seed, c=CRYST, cl=CRYST_L):
    k = Kit(name, seed)
    for (x, y, r, h, tx, ty) in ((0, 0, 0.9, 5.0, 0.3, 0.1), (1.0, 0.4, 0.6, 3.2, 1.0, 0.4), (-0.8, -0.5, 0.55, 2.8, -0.9, -0.3), (0.3, -0.9, 0.45, 2.2, 0.2, -0.8)):
        for z0, hh, flip in ((0, h, 1),):
            fs = k.cone(z0, r, hh, 6, c, centre=(x, y), tip=(tx, ty))
            for f in fs:
                if f.normal.z > 0.25:
                    k.cols[f] = cl
    return k.finish()


def lava_shard(name, seed):
    k = Kit(name, seed)
    for (x, y, r, h, tx, ty) in ((0, 0, 1.3, 7.0, 0.9, 0.3), (1.4, 0.6, 0.8, 4.0, 1.2, 0.6), (-1.0, -0.7, 0.7, 3.4, -0.8, -0.6)):
        fs = k.cone(0, r, h, 5, OBS, centre=(x, y), tip=(tx, ty))
        for f in fs:
            if f.normal.z > 0.55:
                k.cols[f] = LAVA
    return k.finish()


BUILDS = {
    "Oak": lambda: oak("Oak", 1, G_D, G_M, G_L),
    "OakBig": lambda: oak("OakBig", 7, G_D, G_M, G_L, h=8.5),
    "AutumnOak": lambda: oak("AutumnOak", 2, A_D, A_M, A_L),
    "Birch": lambda: birch("Birch", 3),
    "Pine": lambda: pine("Pine", 4),
    "PineTall": lambda: pine("PineTall", 5, tall=1.35),
    "SnowPine": lambda: pine("SnowPine", 6, snow=True),
    "DeadTree": lambda: dead_tree("DeadTree", 8),
    "Cactus": lambda: cactus("Cactus", 9),
    "Palm": lambda: palm("Palm", 10),
    "GiantMushroom": lambda: giant_mushroom("GiantMushroom", 11),
    "Boulder": lambda: boulder("Boulder", 12),
    "BoulderSand": lambda: boulder("BoulderSand", 13, cols=(H("#d4a06a"), H("#e8be8a"), H("#a87a50"))),
    "BoulderDark": lambda: boulder("BoulderDark", 14, cols=(H("#3a3440"), H("#524a58"), H("#241f28"))),
    "Flowers": lambda: flowers("Flowers", 15),
    "RedMushrooms": lambda: red_mushrooms("RedMushrooms", 16),
    "IceSpikes": lambda: ice_spikes("IceSpikes", 17),
    "Crystals": lambda: crystal_cluster("Crystals", 18),
    "BlueCrystals": lambda: crystal_cluster("BlueCrystals", 19, c=H("#3aa8ff"), cl=H("#b8e4ff")),
    "LavaShard": lambda: lava_shard("LavaShard", 20),
}


def run():
    only = sys.argv[2].split(",") if len(sys.argv) > 2 else None
    lf.setup_scene()
    clear()
    objs = []
    report = {}
    for key, fn in BUILDS.items():
        if only and key not in only:
            continue
        o, tris = fn()
        report[key] = tris
        objs.append(o)
    # lineup preview: grid 5 wide
    step = 14.0
    for i, o in enumerate(objs):
        o.location = ((i % 5) * step, (i // 5) * step, 0)
    lh.render_preview(objs, os.path.join(OUT, "nature_lineup.png"), size=(1800, 1100), direction=(0.35, -1.0, 0.55), lens=40, margin=1.05)
    for o in objs:
        o.location = (0, 0, 0)
    lh.export_modules(objs, OUT, combined="Nature1_All")
    print("REPORT", report, "TOTAL", sum(report.values()))


run()
