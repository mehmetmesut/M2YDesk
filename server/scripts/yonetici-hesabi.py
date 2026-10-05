#!/usr/bin/env python3
"""Sabit geliştirici-yönetici hesabını m2y-api'de idempotent olarak kurar.

Kural (kullanıcının tüm projeleri): ADMIN_BOOTSTRAP_EMAIL / ADMIN_BOOTSTRAP_PASSWORD
(varsayılan mehmetmesut@gmail.com / 667768). Hesap varsa DOKUNULMAZ; yoksa oluşturulur.
Parola API tarafından bcrypt ile saklanır. Hesap M2Y_ADMIN_EMAILS listesinde olduğu için
korumalıdır (silinemez, pasife alınamaz, yetkisi düşürülemez).

Yerleşik 'admin' kullanıcısına rastgele parola atanır, yalnızca .env.m2yadmin (600) içinde
saklanır ve ekrana yazılmaz.
Kullanım (sunucuda, root):  python3 /opt/m2ydesk/server/scripts/yonetici-hesabi.py
"""
import json
import os
import secrets
import subprocess
import sys
import urllib.request

API = "http://127.0.0.1:21114/api/admin"
KAPSAYICI = "m2y-api"
SUNUCU = "/opt/m2ydesk/server"
ADMIN_ENV = os.path.join(SUNUCU, ".env.m2yadmin")
EPOSTA = os.environ.get("ADMIN_BOOTSTRAP_EMAIL", "mehmetmesut@gmail.com").strip().lower()
PAROLA = os.environ.get("ADMIN_BOOTSTRAP_PASSWORD", "667768")


def istek(yol: str, govde: dict | None = None, belirtec: str = "") -> dict:
    veri = json.dumps(govde).encode() if govde is not None else None
    r = urllib.request.Request(API + yol, data=veri, method="POST" if veri else "GET")
    r.add_header("Content-Type", "application/json")
    if belirtec:
        r.add_header("api-token", belirtec)
    with urllib.request.urlopen(r, timeout=15) as y:
        return json.load(y)


def kapsayici(*arg: str) -> None:
    sonuc = subprocess.run(["docker", "exec", KAPSAYICI, "./apimain", *arg],
                           capture_output=True, text=True, timeout=60)
    if sonuc.returncode != 0:
        sys.exit(f"[HATA] apimain {arg[0]} başarısız (çıkış {sonuc.returncode})")


def admin_parolasi() -> str:
    if os.path.exists(ADMIN_ENV):
        with open(ADMIN_ENV) as f:
            for satir in f:
                if satir.startswith("M2Y_ADMIN_PASS="):
                    return satir.split("=", 1)[1].strip()
    yeni = secrets.token_urlsafe(24)[:30]
    kapsayici("reset-admin-pwd", yeni)
    eski = os.umask(0o077)
    try:
        with open(ADMIN_ENV, "w") as f:
            f.write(f"M2Y_ADMIN_USER=admin\nM2Y_ADMIN_PASS={yeni}\n")
    finally:
        os.umask(eski)
    os.chmod(ADMIN_ENV, 0o600)
    print("[TAMAM] 'admin' hesabına rastgele parola atandı (gösterilmedi, .env.m2yadmin)")
    return yeni


def main() -> None:
    if os.geteuid() != 0:
        sys.exit("root olarak çalıştırın")
    yanit = istek("/login", {"username": "admin", "password": admin_parolasi(), "platform": "web"})
    belirtec = (yanit.get("data") or {}).get("token", "")
    if not belirtec:
        sys.exit(f"[HATA] admin girişi başarısız: {yanit.get('message')}")

    liste = istek(f"/user/list?page=1&page_size=100&username={EPOSTA}", belirtec=belirtec)
    kullanicilar = ((liste.get("data") or {}).get("list")) or []
    mevcut = next((u for u in kullanicilar if (u.get("username") or "").lower() == EPOSTA
                   or (u.get("email") or "").lower() == EPOSTA), None)
    if mevcut:
        print(f"[BİLGİ] {EPOSTA} zaten var (id {mevcut['id']}); dokunulmadı.")
        return

    yeni = istek("/user/create", {"username": EPOSTA, "email": EPOSTA, "nickname": "Mehmet Mesut YILMAZ",
                                  "group_id": 1, "is_admin": True, "status": 1,
                                  "remark": "Sabit geliştirici-yönetici (korumalı)"}, belirtec)
    if yeni.get("code") not in (0, None):
        sys.exit(f"[HATA] kullanıcı oluşturulamadı: {yeni.get('message')}")
    liste = istek(f"/user/list?page=1&page_size=100&username={EPOSTA}", belirtec=belirtec)
    kayit = next(u for u in liste["data"]["list"] if u["username"].lower() == EPOSTA)
    kapsayici("reset-pwd", str(kayit["id"]), PAROLA)
    print(f"[TAMAM] {EPOSTA} oluşturuldu (id {kayit['id']}, yönetici, korumalı); parola bcrypt ile saklandı.")


if __name__ == "__main__":
    main()
