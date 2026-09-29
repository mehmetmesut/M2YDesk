#!/usr/bin/env python3
"""M2YDesk ikon üretici.

Tasarım dili: Liquid Glass (yumuşak degrade, üstte cam parlaması, geniş yuvarlatma).
Glif: monitör + onay işareti (indirme sayfasındaki favicon ile aynı).

Kullanım:  python3 res/m2y/icons/uret.py            # desk + qs setlerini üretir ve desk setini yerine kopyalar
           python3 res/m2y/icons/uret.py --uygula qs # qs setini yerine kopyalar (CI, QS derlemesinden önce)
Gereksinim: pip install pillow
"""
import os, shutil, sys
from PIL import Image, ImageDraw, ImageFilter

# Windows konsolu (cp1252) Türkçe karakterleri yazdıramaz; çıktıyı UTF-8'e sabitle
for _akis in (sys.stdout, sys.stderr):
    if hasattr(_akis, "reconfigure"):
        _akis.reconfigure(encoding="utf-8", errors="replace")

KOK = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
CIKTI = os.path.join(KOK, "res", "m2y", "icons")

VARYANTLAR = {
    # ad: (üst renk, alt renk)
    "desk": ((0x0E, 0x7C, 0xFF), (0x08, 0x62, 0xD1)),
    "qs": ((0x14, 0xB8, 0x8A), (0x0B, 0x8A, 0x63)),
}

S = 1024  # ana çözünürlük


def degrade(boyut, ust, alt):
    im = Image.new("RGBA", (boyut, boyut))
    px = im.load()
    for y in range(boyut):
        t = y / (boyut - 1)
        r = int(ust[0] + (alt[0] - ust[0]) * t)
        g = int(ust[1] + (alt[1] - ust[1]) * t)
        b = int(ust[2] + (alt[2] - ust[2]) * t)
        for x in range(boyut):
            px[x, y] = (r, g, b, 255)
    return im


def yuvarlak_maske(boyut, yaricap):
    m = Image.new("L", (boyut, boyut), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, boyut - 1, boyut - 1], radius=yaricap, fill=255)
    return m


def glif(boyut, renk=(255, 255, 255, 255), kalinlik=None, olcek=1.0):
    """Monitör + onay işareti; şeffaf zemin."""
    im = Image.new("RGBA", (boyut, boyut), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    k = kalinlik or max(2, int(boyut * 0.075))
    # Monitör gövdesi (viewBox 32: x3 y6 w26 h17 r4) -> ölçek
    u = boyut / 32 * olcek
    ofs = (boyut - 32 * u) / 2
    def P(x, y):
        return (ofs + x * u, ofs + y * u)
    d.rounded_rectangle([P(3, 6), P(29, 23)], radius=4 * u, outline=renk, width=k)
    # Ayak
    d.line([P(11, 27), P(21, 27)], fill=renk, width=k, joint="curve")
    d.line([P(16, 23.5), P(16, 27)], fill=renk, width=k)
    # Onay işareti
    d.line([P(11, 14.5), P(14, 17.5), P(21, 10.5)], fill=renk, width=int(k * 1.15), joint="curve")
    # Uçları yuvarla
    r = int(k * 1.15 / 2)
    for x, y in [(11, 14.5), (14, 17.5), (21, 10.5), (11, 27), (21, 27)]:
        cx, cy = P(x, y)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=renk)
    return im


def uygulama_ikonu(boyut, ust, alt, yuvarlak=False):
    """Degrade zemin + cam parlaması + beyaz glif."""
    im = degrade(S, ust, alt)
    # Üst cam parlaması
    parla = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(parla).ellipse([-S * 0.2, -S * 0.75, S * 1.2, S * 0.55], fill=(255, 255, 255, 60))
    parla = parla.filter(ImageFilter.GaussianBlur(S * 0.06))
    im.alpha_composite(parla)
    # Glif (gölge + beyaz)
    g = glif(S, olcek=0.78)
    golge = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    golge.paste(Image.new("RGBA", (S, S), (0, 0, 0, 90)), mask=g.split()[3])
    golge = golge.filter(ImageFilter.GaussianBlur(S * 0.015))
    im.alpha_composite(golge, (0, int(S * 0.012)))
    im.alpha_composite(g)
    # Maske
    maske = Image.new("L", (S, S), 0)
    if yuvarlak:
        ImageDraw.Draw(maske).ellipse([0, 0, S - 1, S - 1], fill=255)
    else:
        maske = yuvarlak_maske(S, int(S * 0.22))
    im.putalpha(maske)
    return im.resize((boyut, boyut), Image.LANCZOS) if boyut != S else im


def tepsi_ikonu(boyut, renk):
    """Tek renk glif (tepsi/bildirim)."""
    return glif(S, renk=renk, kalinlik=int(S * 0.09), olcek=0.95).resize((boyut, boyut), Image.LANCZOS)


def uret(varyant):
    ust, alt = VARYANTLAR[varyant]
    out = os.path.join(CIKTI, varyant)
    os.makedirs(out, exist_ok=True)
    ana = uygulama_ikonu(S, ust, alt)
    ana.save(os.path.join(out, "icon.png"))
    ana.save(os.path.join(out, "mac-icon.png"))
    for b in (32, 64, 128, 256):
        ana.resize((b, b), Image.LANCZOS).save(os.path.join(out, f"{b}x{b}.png"))
    ana.save(os.path.join(out, "icon.ico"), sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    ana.resize((48, 48), Image.LANCZOS).save(os.path.join(out, "app_icon.ico"), sizes=[(16, 16), (32, 32), (48, 48)])
    # Tepsi: Windows renkli; macOS şablon (siyah/beyaz)
    ana.resize((32, 32), Image.LANCZOS).save(os.path.join(out, "tray-icon.ico"), sizes=[(16, 16), (32, 32)])
    tepsi_ikonu(60, (0, 0, 0, 255)).save(os.path.join(out, "mac-tray-dark-x2.png"))
    tepsi_ikonu(48, (255, 255, 255, 255)).convert("LA").save(os.path.join(out, "mac-tray-light-x2.png"))
    # Android
    for yog, px in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)):
        d = os.path.join(out, "android", f"mipmap-{yog}")
        os.makedirs(d, exist_ok=True)
        ana.resize((px, px), Image.LANCZOS).save(os.path.join(d, "ic_launcher.png"))
        uygulama_ikonu(px, ust, alt, yuvarlak=True).save(os.path.join(d, "ic_launcher_round.png"))
        # Adaptif ön plan: 108dp ızgara, güvenli alan 66dp -> glif ölçeği ~0.5
        fg = glif(S, olcek=0.5).resize((int(px * 108 / 48), int(px * 108 / 48)), Image.LANCZOS)
        fg.save(os.path.join(d, "ic_launcher_foreground.png"))
        stat = tepsi_ikonu(int(px / 2), (255, 255, 255, 255)).convert("LA")
        stat.save(os.path.join(d, "ic_stat_logo.png"))
    with open(os.path.join(out, "ic_launcher_background.xml"), "w") as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">#%02x%02x%02x</color>\n</resources>\n' % ust)
    print(f"[{varyant}] üretildi: {out}")


def uygula(varyant):
    """Üretilen seti depodaki gerçek konumlara kopyalar."""
    src = os.path.join(CIKTI, varyant)
    hedefler = {
        "icon.png": "res/icon.png", "mac-icon.png": "res/mac-icon.png",
        "32x32.png": "res/32x32.png", "64x64.png": "res/64x64.png",
        "128x128.png": "res/128x128.png", "256x256.png": "res/128x128@2x.png",
        "icon.ico": "res/icon.ico", "tray-icon.ico": "res/tray-icon.ico",
        "mac-tray-dark-x2.png": "res/mac-tray-dark-x2.png", "mac-tray-light-x2.png": "res/mac-tray-light-x2.png",
        "app_icon.ico": "flutter/windows/runner/resources/app_icon.ico",
        "icon.png": "flutter/assets/icon.png",
        "ic_launcher_background.xml": "flutter/android/app/src/main/res/values/ic_launcher_background.xml",
    }
    # icon.png iki hedefe gider
    for kaynak, hedef in list(hedefler.items()) + [("icon.png", "res/icon.png")]:
        shutil.copyfile(os.path.join(src, kaynak), os.path.join(KOK, hedef))
    for yog in ("mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"):
        d = os.path.join(src, "android", f"mipmap-{yog}")
        for ad in os.listdir(d):
            shutil.copyfile(os.path.join(d, ad), os.path.join(KOK, "flutter/android/app/src/main/res", f"mipmap-{yog}", ad))
    print(f"[{varyant}] depoya uygulandı")


if __name__ == "__main__":
    if len(sys.argv) >= 3 and sys.argv[1] == "--uygula":
        # Set depoda yoksa (CI temiz checkout) önce üret
        if not os.path.isfile(os.path.join(CIKTI, sys.argv[2], "icon.png")):
            uret(sys.argv[2])
        uygula(sys.argv[2])
    else:
        for v in VARYANTLAR:
            uret(v)
        uygula("desk")
