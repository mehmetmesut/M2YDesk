#!/usr/bin/env python3
"""M2YDesk güncelleme bilgisi (surum.json) ve engel listesi (engel.json) için Ed25519 imza aracı.

İMZALAMA SUNUCUDA YAPILMAZ: kendi bilgisayarınızda veya GitHub Actions'ta çalıştırın.
Özel anahtar depoya, sohbete ve sunucuya girmez (bkz. docs/guncelleme.md "İmza").

Kullanım:
  python3 imzala.py anahtar-uret <ozel_anahtar_dosyasi>
      Yeni anahtar çifti üretir. Özel anahtar dosyaya (PEM, izin 600) yazılır ve ekrana
      BASILMAZ; açık anahtar base64 olarak basılır (GitHub Variables: M2Y_UPDATE_PUBKEYS).
  python3 imzala.py imzala <dosya> --anahtar <ozel_anahtar_dosyasi>
      Dosyanın HAM baytlarını imzalar, yanına <dosya>.sig (tek satır base64) yazar.
  python3 imzala.py dogrula <dosya> --acik-anahtar <base64[,base64...]>
      <dosya>.sig imzasını açık anahtar(lar)la denetler (yüklemeden önce kontrol için).

Gereksinim: `cryptography` paketi (pip install cryptography).
"""
import argparse
import base64
import os
import sys

try:
    from cryptography.exceptions import InvalidSignature
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.primitives.asymmetric.ed25519 import (
        Ed25519PrivateKey,
        Ed25519PublicKey,
    )
except ImportError:
    sys.exit("HATA: 'cryptography' paketi yok. Kurulum: python3 -m pip install cryptography")


def acik_anahtar_b64(ozel: Ed25519PrivateKey) -> str:
    ham = ozel.public_key().public_bytes(
        serialization.Encoding.Raw, serialization.PublicFormat.Raw
    )
    return base64.b64encode(ham).decode("ascii")


def anahtar_uret(yol: str) -> None:
    ozel = Ed25519PrivateKey.generate()
    pem = ozel.private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.PKCS8,
        serialization.NoEncryption(),
    )
    try:
        # O_EXCL: var olan anahtarın üzerine yazılmaz (kaybı önler); 0o600: yalnızca sahibi okur.
        fd = os.open(yol, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    except FileExistsError:
        sys.exit(f"HATA: {yol} zaten var; üzerine yazılmaz.")
    with os.fdopen(fd, "wb") as f:
        f.write(pem)
    print(f"Özel anahtar yazıldı: {yol} (izin 600; yedeğini güvenli yerde saklayın, kimseyle paylaşmayın)")
    print("Açık anahtar (M2Y_UPDATE_PUBKEYS):")
    print(acik_anahtar_b64(ozel))


def ozel_anahtar_oku(yol: str) -> Ed25519PrivateKey:
    try:
        with open(yol, "rb") as f:
            ozel = serialization.load_pem_private_key(f.read(), password=None)
    except (OSError, ValueError, TypeError) as e:
        sys.exit(f"HATA: özel anahtar okunamadı ({yol}): {e}")
    if not isinstance(ozel, Ed25519PrivateKey):
        sys.exit(f"HATA: {yol} bir Ed25519 özel anahtarı değil.")
    return ozel


def imzala(dosya: str, anahtar: str) -> None:
    ozel = ozel_anahtar_oku(anahtar)
    try:
        with open(dosya, "rb") as f:
            veri = f.read()
    except OSError as e:
        sys.exit(f"HATA: {dosya} okunamadı: {e}")
    imza = base64.b64encode(ozel.sign(veri)).decode("ascii")
    with open(dosya + ".sig", "w", encoding="ascii", newline="\n") as f:
        f.write(imza + "\n")
    print(f"İmza yazıldı: {dosya}.sig ({len(veri)} bayt imzalandı)")
    print(f"İmzalayan açık anahtar: {acik_anahtar_b64(ozel)}")


def dogrula(dosya: str, acik_anahtarlar: str) -> None:
    try:
        with open(dosya, "rb") as f:
            veri = f.read()
        with open(dosya + ".sig", "r", encoding="ascii") as f:
            imza = base64.b64decode(f.read().strip(), validate=True)
    except (OSError, ValueError) as e:
        sys.exit(f"HATA: {dosya} / .sig okunamadı: {e}")
    for b64 in filter(None, (k.strip() for k in acik_anahtarlar.split(","))):
        try:
            Ed25519PublicKey.from_public_bytes(base64.b64decode(b64, validate=True)).verify(imza, veri)
        except (InvalidSignature, ValueError):
            continue
        print(f"GEÇERLİ: {dosya} imzası {b64} ile doğrulandı")
        return
    sys.exit(f"GEÇERSİZ: {dosya} imzası verilen açık anahtarlarla doğrulanamadı")


def main() -> None:
    ap = argparse.ArgumentParser(description="M2YDesk surum.json / engel.json Ed25519 imza aracı")
    alt = ap.add_subparsers(dest="komut", required=True)
    p = alt.add_parser("anahtar-uret", help="anahtar çifti üret")
    p.add_argument("ozel_anahtar_dosyasi")
    p = alt.add_parser("imzala", help="dosyayı imzala (<dosya>.sig)")
    p.add_argument("dosya")
    p.add_argument("--anahtar", required=True, help="özel anahtar dosyası (PEM)")
    p = alt.add_parser("dogrula", help="<dosya>.sig imzasını denetle")
    p.add_argument("dosya")
    p.add_argument("--acik-anahtar", required=True, help="base64 açık anahtar(lar), virgülle")
    a = ap.parse_args()
    if a.komut == "anahtar-uret":
        anahtar_uret(a.ozel_anahtar_dosyasi)
    elif a.komut == "imzala":
        imzala(a.dosya, a.anahtar)
    else:
        dogrula(a.dosya, a.acik_anahtar)


if __name__ == "__main__":
    main()
