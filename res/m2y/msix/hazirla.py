#!/usr/bin/env python3
"""M2YDesk Hızlı Destek için Microsoft Store (MSIX) paket klasörünü hazırlar.

Kullanım (CI, QS derlemesinden sonra):
  python3 res/m2y/msix/hazirla.py --kaynak ./rustdesk --hedef ./msix --surum 1.0.3 \
      --ad "$M2Y_MSIX_NAME" --yayinci "$M2Y_MSIX_PUBLISHER" --yayinci-adi "$M2Y_MSIX_PUBLISHER_DISPLAY"
Ardından:  makeappx pack /d msix /p out/M2YDesk-QS-<sürüm>.msix /o

Paket imzasızdır: Store yüklemede Microsoft imzalar. Sürücüler (sanal ekran, yazıcı) Store paketine
konmaz; MSIX sürücü kuramaz ve Hızlı Destek bunlara ihtiyaç duymaz.
"""
import argparse
import os
import re
import shutil
import sys

from PIL import Image

for _akis in (sys.stdout, sys.stderr):
    if hasattr(_akis, "reconfigure"):
        _akis.reconfigure(encoding="utf-8", errors="replace")

BURASI = os.path.dirname(os.path.abspath(__file__))
KOK = os.path.abspath(os.path.join(BURASI, "..", "..", ".."))
IKON = os.path.join(KOK, "res", "m2y", "icons", "qs", "icon.png")

# Store paketine girmeyecek içerik (sürücüler ve sürücü kurulum araçları)
DISLA = {"drivers", "usbmmidd_v2", "printer_driver_adapter.dll"}

# (dosya adı, genişlik, yükseklik, kenar boşluğu oranı)
VARLIKLAR = [
    ("StoreLogo.png", 50, 50, 0.0),
    ("Square44x44Logo.png", 44, 44, 0.0),
    ("Square44x44Logo.targetsize-24_altform-unplated.png", 24, 24, 0.0),
    ("Square44x44Logo.targetsize-32_altform-unplated.png", 32, 32, 0.0),
    ("Square44x44Logo.targetsize-48_altform-unplated.png", 48, 48, 0.0),
    ("Square44x44Logo.targetsize-256_altform-unplated.png", 256, 256, 0.0),
    ("Square150x150Logo.png", 150, 150, 0.12),
    ("Wide310x150Logo.png", 310, 150, 0.12),
]


def hata(mesaj):
    print(f"[HATA] {mesaj}", file=sys.stderr)
    sys.exit(1)


def msix_surumu(surum):
    s = surum.strip().lstrip("vV")
    if not re.fullmatch(r"\d+\.\d+\.\d+", s):
        hata(f"sürüm x.y.z olmalı: {surum!r}")
    return s + ".0"  # MSIX dört parçalı sürüm ister; dördüncü parça Store için 0 olmalı


def varlik(ikon, ad, w, h, bosluk, hedef):
    tuval = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    kenar = int(min(w, h) * (1 - 2 * bosluk))
    kucuk = ikon.resize((kenar, kenar), Image.LANCZOS)
    tuval.paste(kucuk, ((w - kenar) // 2, (h - kenar) // 2), kucuk)
    tuval.save(os.path.join(hedef, ad))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--kaynak", required=True, help="derlenmiş QS klasörü (M2YDeskQS.exe içerir)")
    ap.add_argument("--hedef", required=True)
    ap.add_argument("--surum", required=True)
    ap.add_argument("--ad", required=True, help="Package/Identity/Name")
    ap.add_argument("--yayinci", required=True, help="Package/Identity/Publisher (CN=...)")
    ap.add_argument("--yayinci-adi", required=True, help="PublisherDisplayName")
    a = ap.parse_args()

    for deger, ad in ((a.ad, "--ad"), (a.yayinci, "--yayinci"), (a.yayinci_adi, "--yayinci-adi")):
        if not deger.strip():
            hata(f"{ad} boş (Partner Center değerleri GitHub Variables'a girilmeli)")
    if not a.yayinci.startswith("CN="):
        hata("--yayinci 'CN=' ile başlamalı")
    if not os.path.isfile(os.path.join(a.kaynak, "M2YDeskQS.exe")):
        hata(f"{a.kaynak}/M2YDeskQS.exe yok")

    if os.path.exists(a.hedef):
        shutil.rmtree(a.hedef)
    shutil.copytree(a.kaynak, a.hedef, ignore=lambda d, adlar: [x for x in adlar if x in DISLA])

    assets = os.path.join(a.hedef, "Assets")
    os.makedirs(assets, exist_ok=True)
    ikon = Image.open(IKON).convert("RGBA")
    for ad, w, h, bosluk in VARLIKLAR:
        varlik(ikon, ad, w, h, bosluk, assets)

    with open(os.path.join(BURASI, "AppxManifest.xml"), encoding="utf-8") as f:
        manifest = f.read()
    from xml.sax.saxutils import escape
    for anahtar, deger in {
        "NAME": a.ad.strip(),
        "PUBLISHER": a.yayinci.strip(),
        "PUBLISHER_DISPLAY": a.yayinci_adi.strip(),
        "VERSION": msix_surumu(a.surum),
    }.items():
        manifest = manifest.replace("{{" + anahtar + "}}", escape(deger, {'"': "&quot;"}))
    if "{{" in manifest:
        hata("manifestte doldurulmamış alan kaldı")
    with open(os.path.join(a.hedef, "AppxManifest.xml"), "w", encoding="utf-8") as f:
        f.write(manifest)
    print(f"[TAMAM] MSIX klasörü hazır: {a.hedef} (sürüm {msix_surumu(a.surum)})")


if __name__ == "__main__":
    main()
