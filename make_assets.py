"""Generates the app icon (a brass padlock on leather) and the launch images (header, leather, footer; iOS 6 adds the icon gloss and rounding itself)."""
import random
from PIL import Image, ImageDraw, ImageFilter, ImageChops

S = 1024  # master canvas

def vgrad(w, h, top, bot):
    im = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(im)
    for y in range(h):
        t = y / max(1, h - 1)
        d.line([(0, y), (w, y)], fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))
    return im

def leather(w, h, base=(58, 31, 26), seed=3):
    rnd = random.Random(seed)
    im = Image.new("RGB", (w, h), base)
    # pebble grain at 1x then upscaled would blur; draw directly
    dim = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(dim)
    n = int(w * h / 90)
    for _ in range(n):
        x, y, r = rnd.randrange(w), rnd.randrange(h), rnd.choice((2, 3, 3, 4))
        d.ellipse([x, y, x + r, y + r], fill=(0, 0, 0, 52))
        d.arc([x - 1, y - 1, x + r, y + r], 200, 340, fill=(255, 190, 150, 26))
    im = Image.alpha_composite(im.convert("RGBA"), dim).convert("RGB")
    return im

def radial_light(w, h, cx, cy, r, alpha):
    lay = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(lay)
    for i in range(40, 0, -1):
        rr = r * i / 40
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=int(alpha * (1 - i / 40) ** 1.6 * 255 / max(alpha, 0.001) * alpha))
    return lay

def draw_padlock(base, scale_px, cx, cy):
    """Draws the padlock on `base` (RGB) centred at cx, cy with a body width of scale_px."""
    k = scale_px / 560.0
    W, H = base.size
    def P(x, y): return (cx + x * k, cy + y * k)
    # --- shadow of the whole lock
    sh = Image.new("L", (W, H), 0)
    sd = ImageDraw.Draw(sh)
    body = [P(-280, 20)[0], P(-280, 20)[1], P(280, 20)[0], P(280, 400)[1]]
    sd.rounded_rectangle(body, radius=70 * k, fill=255)
    for dx in (-170, 170): sd.line([P(dx, 40), P(dx, -120)], fill=255, width=int(88 * k))
    sd.arc([P(-170 - 44, -330)[0], P(0, -330)[1], P(170 + 44, 0)[0], P(0, 0)[1] + 0], 180, 360, fill=255, width=int(88 * k))
    sh = sh.filter(ImageFilter.GaussianBlur(26 * k)).point(lambda v: int(v * 0.7))
    sh = ImageChops.offset(sh, 0, int(22 * k))
    base.paste((8, 4, 3), (0, 0), sh)
    d = ImageDraw.Draw(base)
    # --- shackle: stacked strokes, dark rim to bright core, gives a polished tube
    layers = [(96, (24, 26, 32)), (86, (84, 90, 102)), (70, (140, 148, 162)), (52, (196, 202, 214)), (34, (232, 236, 244)), (16, (255, 255, 255))]
    cxl, cxr = P(-170, 0)[0], P(170, 0)[0]
    top = P(0, -330)[1]; arc_r = (cxr - cxl) / 2
    ycen = top + arc_r
    for i, (w, col) in enumerate(layers):
        off = (i / (len(layers) - 1)) * 10 * k   # highlight drifts toward the light
        wid = int(w * k)
        d.line([(cxl - off, ycen), (cxl - off, P(0, 80)[1])], fill=col, width=wid)
        d.line([(cxr - off, ycen), (cxr - off, P(0, 80)[1])], fill=col, width=wid)
        d.arc([cxl - off - wid / 2, top - wid / 2, cxr - off + wid / 2, ycen + arc_r + wid / 2], 180, 360, fill=col, width=wid)
    # the shackle disappears into the body: darken where it enters
    # --- brass body
    x0, y0, x1, y1 = body
    bw, bh = int(x1 - x0), int(y1 - y0)
    face = vgrad(bw, bh, (252, 226, 148), (150, 102, 28))
    # brushed texture
    rnd = random.Random(9)
    fd = ImageDraw.Draw(face, "RGBA")
    for _ in range(900):
        y = rnd.randrange(bh); x = rnd.randrange(bw); l = rnd.randrange(40, 260)
        c = (255, 244, 200, 18) if rnd.random() < .5 else (90, 56, 10, 20)
        fd.line([(x, y), (x + l, y)], fill=c, width=max(1, int(2 * k)))
    # soft highlight band and lower falloff
    hl = Image.new("L", (bw, bh), 0); hd = ImageDraw.Draw(hl)
    hd.rounded_rectangle([int(bw * .04), int(bh * .05), int(bw * .96), int(bh * .42)], radius=int(60 * k), fill=120)
    hl = hl.filter(ImageFilter.GaussianBlur(14 * k))
    face.paste((255, 250, 225), (0, 0), hl)
    bm = Image.new("L", (bw, bh), 0)
    ImageDraw.Draw(bm).rounded_rectangle([0, 0, bw - 1, bh - 1], radius=int(70 * k), fill=255)
    # bevel: dark outline, light inner rim on top
    rim = Image.new("L", (bw, bh), 0)
    rd = ImageDraw.Draw(rim)
    rd.rounded_rectangle([0, 0, bw - 1, bh - 1], radius=int(70 * k), outline=255, width=max(2, int(8 * k)))
    face.paste((96, 58, 10), (0, 0), rim)
    inner = Image.new("L", (bw, bh), 0)
    ImageDraw.Draw(inner).rounded_rectangle([int(10 * k), int(10 * k), bw - int(10 * k), bh - int(10 * k)], radius=int(62 * k), outline=140, width=max(2, int(5 * k)))
    inner = ImageChops.multiply(inner, vgrad(bw, bh, (255, 255, 255), (0, 0, 0)).convert("L"))
    face.paste((255, 246, 210), (0, 0), inner)
    # screws/rivets at the corners
    fd = ImageDraw.Draw(face)
    for sx, sy in ((.12, .17), (.88, .17), (.12, .83), (.88, .83)):
        r = int(15 * k); px, py = int(bw * sx), int(bh * sy)
        fd.ellipse([px - r, py - r + int(3 * k), px + r, py + r + int(3 * k)], fill=(255, 238, 190))
        fd.ellipse([px - r, py - r, px + r, py + r], fill=(176, 126, 44), outline=(82, 52, 8), width=max(1, int(2 * k)))
        fd.line([(px - r * .6, py - r * .1), (px + r * .6, py + r * .1)], fill=(70, 44, 6), width=max(1, int(3 * k)))
    base.paste(face, (int(x0), int(y0)), bm)
    # --- keyhole: dark socket with a bright lower lip
    kx, ky = P(0, 168)
    kr = 44 * k
    d = ImageDraw.Draw(base)
    d.ellipse([kx - kr - 6 * k, ky - kr + 4 * k, kx + kr + 6 * k, ky + kr + 12 * k], fill=(255, 236, 180))
    slot = [(kx - 20 * k, ky + 10 * k), (kx + 20 * k, ky + 10 * k), (kx + 34 * k, ky + 128 * k), (kx - 34 * k, ky + 128 * k)]
    d.polygon([(a, b + 6 * k) for a, b in slot], fill=(255, 236, 180))
    kh = Image.new("L", (W, H), 0); kd = ImageDraw.Draw(kh)
    kd.ellipse([kx - kr, ky - kr, kx + kr, ky + kr], fill=255); kd.polygon(slot, fill=255)
    fillk = vgrad(W, H, (10, 6, 3), (58, 36, 12))
    base.paste(fillk, (0, 0), kh)
    kd2 = ImageDraw.Draw(base)
    kd2.arc([kx - kr, ky - kr, kx + kr, ky + kr], 200, 340, fill=(0, 0, 0), width=int(6 * k))

def icon(n):
    bg = leather(S, S, seed=5)
    # warm spot light from the top left and a dark vignette
    glow = radial_light(S, S, S * 0.35, S * 0.28, S * 0.75, 0.55)
    bg.paste((255, 214, 160), (0, 0), glow.point(lambda v: int(v * 0.28)))
    vig = Image.new("L", (S, S), 0); vd = ImageDraw.Draw(vig)
    for i in range(30):
        m = int(i * 6)
        vd.rounded_rectangle([m - 60, m - 60, S - m + 60, S - m + 60], radius=300, outline=int(160 * (1 - i / 30) ** 2), width=8)
    bg.paste((0, 0, 0), (0, 0), vig.filter(ImageFilter.GaussianBlur(40)))
    draw_padlock(bg, 560, S / 2, S * 0.5)
    return bg.resize((n, n), Image.LANCZOS)

def launch(w, h, scale):
    im = leather(w, h, seed=7)
    d = ImageDraw.Draw(im, "RGBA")
    sb, nb, tb = 20 * scale, 44 * scale, 49 * scale
    # steel header
    hdr = vgrad(w, sb + nb, (222, 226, 232), (150, 156, 166))
    im.paste(hdr, (0, 0))
    rnd = random.Random(2)
    for _ in range(int(w * 1.2)):
        y = rnd.randrange(sb + nb); x = rnd.randrange(w); l = rnd.randrange(10 * scale, 60 * scale)
        d.line([(x, y), (x + l, y)], fill=(255, 255, 255, 40) if rnd.random() < .5 else (0, 0, 0, 22), width=1)
    d.line([(0, sb + nb - 1), (w, sb + nb - 1)], fill=(44, 46, 52, 255))
    # footer
    ft = vgrad(w, tb, (70, 74, 82), (30, 32, 38))
    im.paste(ft, (0, h - tb))
    d.line([(0, h - tb), (w, h - tb)], fill=(255, 255, 255, 110))
    # vignette
    vig = Image.new("L", (w, h), 0); vd = ImageDraw.Draw(vig)
    for i in range(24):
        m = i * 4 * scale
        vd.rectangle([m - 40, m - 40, w - m + 40, h - m + 40], outline=int(120 * (1 - i / 24) ** 2), width=6 * scale)
    im.paste((0, 0, 0), (0, 0), vig.filter(ImageFilter.GaussianBlur(20 * scale)))
    return im

icon(57).save("res/Icon.png")
icon(114).save("res/Icon@2x.png")
icon(512).save("build/icon512.png")
launch(320, 480, 1).save("res/Default.png")
launch(640, 960, 2).save("res/Default@2x.png")
launch(640, 1136, 2).save("res/Default-568h@2x.png")
