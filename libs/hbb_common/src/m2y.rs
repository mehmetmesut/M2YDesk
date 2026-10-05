//! M2YDesk: üye olmayan (girişsiz) kullanıcı kuralları ve engel listesi.
//!
//! Mantık burada saf fonksiyonlardır (birim testli); ana crate yalnızca çağırır.
//! DİKKAT: İstemci kaynağı açıktır, bu sınırlar değiştirilmiş istemciyle atlatılabilir.
//! Sunucu tarafı denetim (relay :21127 bağlantı sınırı) ayrıca gerekir.
use crate::{
    config::{Config, LocalConfig},
    sha256_hex,
};
use serde_derive::Deserialize;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

/// Sınır kuralları yalnızca bu seçenek "Y" ise çalışır (API/üye girişi hazır olana kadar kapalı).
pub const OPT_NONMEMBER_LIMIT: &str = "m2y-nonmember-limit";
/// Yerel yapılandırmada saklanan bekleme bitiş zamanı (Unix saniye).
pub const OPT_BLOCK_UNTIL: &str = "m2y-block-until";

/// Cihaz bilgisi raporlama anahtarı (derleme zamanı, yapılandırma JSON'u): "Y" ise kullanıcı onayı sorulur.
pub const OPT_REPORT_DEVICE: &str = "m2y-report-device";
/// Kullanıcı onayı ("Y"); arayüzden `set_option` ile yazılır, hizmet sürecine IPC ile ulaşır.
pub const OPT_REPORT_CONSENT: &str = "m2y-report-consent";

pub const NONMEMBER_SESSION: Duration = Duration::from_secs(5 * 60);
pub const NONMEMBER_WARN_AT: Duration = Duration::from_secs(4 * 60 + 30);
pub const NONMEMBER_BLOCK: Duration = Duration::from_secs(2 * 60);
pub const NONMEMBER_RELAY_PORT: u16 = 21127;

pub fn limits_enabled() -> bool {
    Config::get_option(OPT_NONMEMBER_LIMIT) == "Y"
}

/// Cihaz bilgisi (ID, IP, MAC, ad, işletim sistemi, çevrimiçi durum) sunucuya YALNIZCA
/// derleme anahtarı açık **ve** kullanıcı açıkça onay verdiyse gönderilir (KVKK).
pub fn device_report_allowed() -> bool {
    Config::get_option(OPT_REPORT_DEVICE) == "Y" && Config::get_option(OPT_REPORT_CONSENT) == "Y"
}

/// Üye = hesap girişi yapılmış (`access_token` ve `user_info` dolu).
pub fn is_member() -> bool {
    !LocalConfig::get_option("access_token").is_empty()
        && !LocalConfig::get_option("user_info").is_empty()
}

/// Sınır kuralları bu istemci için geçerli mi?
pub fn nonmember_limited() -> bool {
    limits_enabled() && !is_member()
}

#[derive(Debug, PartialEq, Eq, Clone, Copy)]
pub enum SessionState {
    Running,
    /// Süre dolmak üzere (uyarı zamanı geçti).
    Warn,
    Expired,
}

pub fn session_state(elapsed: Duration) -> SessionState {
    if elapsed >= NONMEMBER_SESSION {
        SessionState::Expired
    } else if elapsed >= NONMEMBER_WARN_AT {
        SessionState::Warn
    } else {
        SessionState::Running
    }
}

fn now_secs() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or_default()
}

/// Bekleme bitişine kalan saniye (0 = engel yok). Saat geriye alınırsa süre `NONMEMBER_BLOCK` ile sınırlanır.
pub fn block_remaining(now: u64, until: u64) -> u64 {
    until.saturating_sub(now).min(NONMEMBER_BLOCK.as_secs())
}

pub fn remaining_block_secs() -> u64 {
    let until = LocalConfig::get_option(OPT_BLOCK_UNTIL)
        .parse::<u64>()
        .unwrap_or_default();
    block_remaining(now_secs(), until)
}

/// Süre dolduğunda çağrılır: bu cihaz 2 dakika yeni bağlantı kuramaz.
pub fn start_block() {
    LocalConfig::set_option(
        OPT_BLOCK_UNTIL.to_owned(),
        (now_secs() + NONMEMBER_BLOCK.as_secs()).to_string(),
    );
}

/// `host` veya `host:port` veya IPv6 adresindeki portu değiştirir.
pub fn relay_with_port(addr: &str, port: u16) -> String {
    let addr = addr.trim();
    if addr.is_empty() {
        return String::new();
    }
    if let Some(rest) = addr.strip_prefix('[') {
        // [::1]:21117 veya [::1]
        let host = rest.split(']').next().unwrap_or_default();
        return format!("[{host}]:{port}");
    }
    match addr.matches(':').count() {
        0 => format!("{addr}:{port}"),
        1 => format!("{}:{port}", addr.split(':').next().unwrap_or_default()),
        _ => format!("[{addr}]:{port}"), // köşeli parantezsiz IPv6
    }
}

/// Üye olmayan kullanıcı için relay adresi ikinci relay'e (:21127) yönlendirilir.
pub fn relay_for_session(addr: &str) -> String {
    if nonmember_limited() {
        relay_with_port(addr, NONMEMBER_RELAY_PORT)
    } else {
        addr.to_owned()
    }
}

/// `engel.json`: her liste SHA-256 özetlerinden oluşur (küçük harf, kırpılmış değerin özeti).
#[derive(Debug, Default, Clone, Deserialize)]
pub struct BlockList {
    #[serde(default)]
    pub id: Vec<String>,
    #[serde(default)]
    pub uuid: Vec<String>,
    #[serde(default)]
    pub mac: Vec<String>,
}

fn hash_value(v: &str) -> String {
    sha256_hex(v.trim().to_lowercase().as_bytes())
}

impl BlockList {
    pub fn is_blocked(&self, id: &str, uuid: &str, mac: &str) -> bool {
        let hit = |list: &Vec<String>, v: &str| {
            !v.trim().is_empty() && {
                let h = hash_value(v);
                list.iter().any(|x| x.trim().eq_ignore_ascii_case(&h))
            }
        };
        hit(&self.id, id) || hit(&self.uuid, uuid) || hit(&self.mac, mac)
    }
}

pub fn block_list_url() -> String {
    format!("https://{}/guncelleme/engel.json", crate::m2y_update_host())
}

/// `surum.json` / `engel.json` imzası için gömülü Ed25519 açık anahtarları
/// (derleme zamanı `M2Y_UPDATE_PUBKEYS`, virgülle ayrılmış base64 32 bayt; birden çok = anahtar döndürme).
pub fn update_pubkeys() -> &'static str {
    match option_env!("M2Y_UPDATE_PUBKEYS") {
        Some(v) => v,
        None => "",
    }
}

/// Ayrık imza dosyasının adresi (`<url>.sig`).
pub fn sig_url(url: &str) -> String {
    format!("{url}.sig")
}

/// `data` ham baytları üzerindeki ayrık Ed25519 imzasını (`sig_b64`, base64) `pubkeys`
/// (virgülle ayrılmış base64 açık anahtarlar) içinden herhangi biriyle doğrular.
/// Anahtar yok, imza/anahtar bozuk veya eşleşme yoksa `false` (güvenli varsayılan).
pub fn verify_detached(data: &[u8], sig_b64: &str, pubkeys: &str) -> bool {
    use sodiumoxide::{base64, crypto::sign};
    use std::convert::TryFrom;
    let sig = match base64::decode(sig_b64.trim(), base64::Variant::Original)
        .ok()
        .and_then(|b| sign::Signature::try_from(b.as_slice()).ok())
    {
        Some(sig) => sig,
        None => return false,
    };
    pubkeys
        .split(',')
        .map(str::trim)
        .filter(|k| !k.is_empty())
        .filter_map(|k| base64::decode(k, base64::Variant::Original).ok())
        .filter_map(|b| sign::PublicKey::from_slice(&b))
        .any(|pk| sign::verify_detached(&sig, data, &pk))
}

/// Gömülü anahtarlarla doğrular; başarısızlıkta uyarı günlüğe yazılır (`what`: dosya adı).
pub fn verify_signed(what: &str, data: &[u8], sig_b64: &str) -> bool {
    if update_pubkeys().trim().is_empty() {
        log::warn!("M2YDesk: M2Y_UPDATE_PUBKEYS derlemeye gömülmedi; {what} reddedildi");
        return false;
    }
    let ok = verify_detached(data, sig_b64, update_pubkeys());
    if !ok {
        log::warn!("M2YDesk: {what} imzası doğrulanamadı; dosya reddedildi");
    }
    ok
}

// --- M2YDesk: zorunlu e-posta + kod oturumu (saf yardımcılar) ---

/// Son başarılı sunucu doğrulaması (Unix sn, `LocalConfig`).
pub const OPT_LAST_AUTH_OK: &str = "m2y-last-auth-ok";
/// Hatırlanan son e-posta (`LocalConfig`); "Bu cihazdan e-postamı unut" ile silinir.
pub const OPT_LAST_EMAIL: &str = "m2y-last-email";
/// Bağlantı kapısını (`stop-service`) bu akış kapattıysa "Y" (`LocalConfig`); kullanıcının
/// bilinçli "hizmeti durdur" seçimi oturum açılınca geri alınmasın diye ayrı tutulur.
pub const OPT_GATE_STOPPED: &str = "m2y-gate-stopped";
/// Çevrimdışı tolerans: son başarılı doğrulamadan itibaren 7 gün (kayan).
pub const AUTH_OFFLINE_GRACE: Duration = Duration::from_secs(7 * 24 * 60 * 60);
/// Saat ileri/geri oynamalarına izin verilen pay (gelecekteki damga bundan büyükse geçersiz).
const AUTH_CLOCK_SKEW_SECS: u64 = 24 * 60 * 60;

/// `last_ok` (Unix sn) üzerinden oturumun süresi doldu mu? Hiç doğrulanmamış (0) ya da
/// gelecekte kalan (saat geri alınmış/elle yazılmış) damga geçersiz sayılır.
pub fn auth_expired(now: u64, last_ok: u64) -> bool {
    if last_ok == 0 || last_ok > now.saturating_add(AUTH_CLOCK_SKEW_SECS) {
        return true;
    }
    now.saturating_sub(last_ok) > AUTH_OFFLINE_GRACE.as_secs()
}

/// `LocalConfig` metin değerinden (boş/bozuk = 0) süre denetimi.
pub fn auth_expired_str(now: u64, last_ok: &str) -> bool {
    auth_expired(now, last_ok.trim().parse::<u64>().unwrap_or_default())
}

/// E-posta normalizasyonu: kırp + küçük harf.
pub fn normalize_email(email: &str) -> String {
    email.trim().to_lowercase()
}

/// Sabit parola kuralı: tam 6 hane, yalnızca ASCII rakam (`^[0-9]{6}$`).
pub fn is_fixed_password(p: &str) -> bool {
    p.len() == 6 && p.bytes().all(|b| b.is_ascii_digit())
}

/// Bağlantı kapısı geçişi. Girdi: istenen durum, mevcut `stop-service` ve kapı işareti.
/// Çıktı: değişiklik gerekiyorsa yeni (`stop-service`, işaret) çifti.
/// - Kapat: hizmet zaten durdurulmuşsa (kullanıcı seçimi) dokunulmaz.
/// - Aç: yalnızca bu akış kapattıysa açılır; kullanıcı seçimi korunur.
pub fn gate_transition(
    closed: bool,
    stop_service: &str,
    gate_marker: &str,
) -> Option<(&'static str, &'static str)> {
    let stopped = stop_service == "Y";
    let ours = gate_marker == "Y";
    match (closed, stopped, ours) {
        (true, false, _) => Some(("Y", "Y")),
        // Kendi kapattığımızı aç; hizmet başka yoldan açılmışsa eski işareti temizle.
        (false, _, true) => Some(("", "")),
        (true, true, _) | (false, _, false) => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn auth_expiry_window() {
        let week = AUTH_OFFLINE_GRACE.as_secs();
        let now = 1_800_000_000;
        assert!(auth_expired(now, 0));
        assert!(!auth_expired(now, now));
        assert!(!auth_expired(now, now - week));
        assert!(auth_expired(now, now - week - 1));
        // küçük saat kayması kabul, uzak gelecek reddedilir
        assert!(!auth_expired(now, now + 3600));
        assert!(auth_expired(now, now + 2 * 24 * 3600));
        assert!(auth_expired_str(now, ""));
        assert!(auth_expired_str(now, "abc"));
        assert!(!auth_expired_str(now, &format!(" {} ", now - 10)));
    }

    #[test]
    fn email_and_password_rules() {
        assert_eq!(normalize_email("  Ali.Veli@Ornek.COM "), "ali.veli@ornek.com");
        assert!(is_fixed_password("012345"));
        assert!(!is_fixed_password("12345"));
        assert!(!is_fixed_password("1234567"));
        assert!(!is_fixed_password("12a456"));
        assert!(!is_fixed_password(" 12345"));
        assert!(!is_fixed_password("١٢٣٤٥٦")); // ASCII dışı rakamlar
    }

    #[test]
    fn gate_transitions() {
        // kapat: açık hizmet bizim işaretimizle durdurulur
        assert_eq!(gate_transition(true, "", ""), Some(("Y", "Y")));
        // kapat: kullanıcı zaten durdurmuş → dokunma (işaret konmaz)
        assert_eq!(gate_transition(true, "Y", ""), None);
        assert_eq!(gate_transition(true, "Y", "Y"), None);
        // aç: yalnızca bizim kapattığımız açılır
        assert_eq!(gate_transition(false, "Y", "Y"), Some(("", "")));
        assert_eq!(gate_transition(false, "Y", ""), None);
        assert_eq!(gate_transition(false, "", ""), None);
        // eski işaret temizlenir (hizmet zaten açık)
        assert_eq!(gate_transition(false, "", "Y"), Some(("", "")));
    }

    #[test]
    fn session_states() {
        assert_eq!(session_state(Duration::from_secs(0)), SessionState::Running);
        assert_eq!(session_state(Duration::from_secs(269)), SessionState::Running);
        assert_eq!(session_state(Duration::from_secs(270)), SessionState::Warn);
        assert_eq!(session_state(Duration::from_secs(299)), SessionState::Warn);
        assert_eq!(session_state(Duration::from_secs(300)), SessionState::Expired);
    }

    #[test]
    fn block_math() {
        assert_eq!(block_remaining(100, 220), 120);
        assert_eq!(block_remaining(100, 150), 50);
        assert_eq!(block_remaining(100, 100), 0);
        assert_eq!(block_remaining(300, 100), 0);
        // saat geri alınmış: uzun bekleme yazılmışsa 2 dk ile sınırlanır
        assert_eq!(block_remaining(100, 100_000), 120);
    }

    #[test]
    fn relay_ports() {
        assert_eq!(relay_with_port("desk.example.com", 21127), "desk.example.com:21127");
        assert_eq!(relay_with_port("desk.example.com:21117", 21127), "desk.example.com:21127");
        assert_eq!(relay_with_port("1.2.3.4:21117", 21127), "1.2.3.4:21127");
        assert_eq!(relay_with_port("[::1]:21117", 21127), "[::1]:21127");
        assert_eq!(relay_with_port("[::1]", 21127), "[::1]:21127");
        assert_eq!(relay_with_port("2001:db8::1", 21127), "[2001:db8::1]:21127");
        assert_eq!(relay_with_port("", 21127), "");
    }

    #[test]
    fn block_list_matching() {
        let l: BlockList = serde_json::from_str(&format!(
            r#"{{"id":["{}"],"mac":["{}"]}}"#,
            hash_value("123456789"),
            hash_value("aa:bb:cc:dd:ee:ff").to_uppercase()
        ))
        .unwrap();
        assert!(l.is_blocked(" 123456789 ", "", ""));
        assert!(l.is_blocked("", "", "AA:BB:CC:DD:EE:FF"));
        assert!(!l.is_blocked("987654321", "x", "11:22:33:44:55:66"));
        // boş değer asla eşleşmez
        assert!(!BlockList { id: vec![hash_value("")], ..Default::default() }.is_blocked("", "", ""));
        assert!(!BlockList::default().is_blocked("1", "2", "3"));
    }

    fn signed(data: &[u8]) -> (String, String) {
        use sodiumoxide::{base64, crypto::sign};
        let (pk, sk) = sign::gen_keypair();
        let sig = sign::sign_detached(data, &sk);
        (
            base64::encode(&pk.0, base64::Variant::Original),
            base64::encode(sig.to_bytes(), base64::Variant::Original),
        )
    }

    #[test]
    fn detached_signature() {
        let data = br#"{"version":"1.0.2"}"#;
        let (pk, sig) = signed(data);
        let (other_pk, _) = signed(data);
        // geçerli imza (tek anahtar, döndürme listesi, sondaki satır sonu)
        assert!(verify_detached(data, &sig, &pk));
        assert!(verify_detached(data, &format!("{sig}\n"), &format!("{other_pk}, {pk}")));
        // bozuk veri
        assert!(!verify_detached(br#"{"version":"9.9.9"}"#, &sig, &pk));
        // yanlış anahtar
        assert!(!verify_detached(data, &sig, &other_pk));
        // boş anahtar listesi
        assert!(!verify_detached(data, &sig, ""));
        assert!(!verify_detached(data, &sig, " , "));
        // bozuk base64 (imza ve anahtar)
        assert!(!verify_detached(data, "!!not-base64!!", &pk));
        assert!(!verify_detached(data, "", &pk));
        assert!(!verify_detached(data, &sig, "!!not-base64!!"));
        // geçerli base64 ama yanlış uzunluk
        assert!(!verify_detached(data, "AAAA", &pk));
        assert!(!verify_detached(data, &sig, "AAAA"));
    }
}

// ---- Yetkili hesap belirteci (m2y_auth) ----
// Biçim m2y-api `service/m2y_yetki.go` ile birebir aynıdır:
//   belirteç = base64url(yük) + "." + base64url(imza)   (dolgusuz base64url)
//   yük      = {"e": e-posta, "h": hedef cihaz ID'si, "x": son geçerlilik (Unix sn), "n": rastgele}
//   imza     = Ed25519(özel anahtar, yük JSON baytları) → 1. parçanın ÇÖZÜLMÜŞ baytları doğrulanır.

/// Gelen bağlantıda yetki belirteci zorunluluğu (gömülü yapılandırma, "Y" ise zorunlu).
pub const OPT_REQUIRE_AUTH: &str = "m2y-require-auth";
/// Kontrol edilen tarafın belirteç geçersizken gönderdiği oturum açma hatası.
pub const AUTH_REJECTED: &str = "Bu cihaza yalnızca yetkili danışmanlar bağlanabilir";
/// Denetleyen tarafın kullanıcıya gösterdiği açıklama.
pub const AUTH_REJECTED_LOCAL: &str = "Bu cihaza bağlanma yetkiniz yok veya sunucuya ulaşılamadı";
/// Saat sapması toleransı (sn).
pub const AUTH_CLOCK_SKEW: u64 = 60;

pub fn require_auth() -> bool {
    Config::get_option(OPT_REQUIRE_AUTH) == "Y"
}

/// Yetki belirteci imza açık anahtarları (derleme zamanı `M2Y_AUTH_PUBKEYS`, virgüllü base64 32 bayt).
pub fn auth_pubkeys() -> &'static str {
    match option_env!("M2Y_AUTH_PUBKEYS") {
        Some(v) => v,
        None => "",
    }
}

#[derive(Debug, Deserialize)]
struct AuthPayload {
    #[serde(default)]
    e: String,
    #[serde(default)]
    h: String,
    #[serde(default)]
    x: i64,
}

/// Belirteci doğrular; başarıda e-postayı döndürür. Sıra m2y-api başvurusuyla aynıdır:
/// imza (yük baytları üzerinde) → JSON → `x + tolerans > now`, `h == my_id`, `e` boş değil.
pub fn verify_m2y_auth(
    token: &[u8],
    my_id: &str,
    now: u64,
    pubkeys: &str,
) -> Result<String, &'static str> {
    use sodiumoxide::{base64, crypto::sign};
    use std::convert::TryFrom;
    if token.is_empty() {
        return Err("belirteç yok");
    }
    let token = std::str::from_utf8(token).map_err(|_| "biçim geçersiz")?;
    let mut parts = token.trim().split('.');
    let (payload_b64, sig_b64) = match (parts.next(), parts.next(), parts.next()) {
        (Some(p), Some(s), None) => (p, s),
        _ => return Err("biçim geçersiz"),
    };
    let payload = base64::decode(payload_b64, base64::Variant::UrlSafeNoPadding)
        .map_err(|_| "biçim geçersiz")?;
    let sig = base64::decode(sig_b64, base64::Variant::UrlSafeNoPadding)
        .ok()
        .and_then(|b| sign::Signature::try_from(b.as_slice()).ok())
        .ok_or("biçim geçersiz")?;
    let mut keys = pubkeys
        .split(',')
        .map(str::trim)
        .filter(|k| !k.is_empty())
        .filter_map(|k| base64::decode(k, base64::Variant::Original).ok())
        .filter_map(|b| sign::PublicKey::from_slice(&b))
        .peekable();
    if keys.peek().is_none() {
        return Err("açık anahtar yok");
    }
    if !keys.any(|pk| sign::verify_detached(&sig, &payload, &pk)) {
        return Err("imza geçersiz");
    }
    let p: AuthPayload = serde_json::from_slice(&payload).map_err(|_| "biçim geçersiz")?;
    if p.e.is_empty() {
        return Err("e-posta yok");
    }
    if p.h.is_empty() || p.h != my_id {
        return Err("hedef uyuşmuyor");
    }
    if p.x <= 0 || (p.x as u64).saturating_add(AUTH_CLOCK_SKEW) <= now {
        return Err("süresi dolmuş");
    }
    Ok(p.e)
}

/// Gömülü anahtarlar ve sistem saatiyle doğrular.
pub fn verify_m2y_auth_now(token: &[u8], my_id: &str) -> Result<String, &'static str> {
    verify_m2y_auth(token, my_id, now_secs(), auth_pubkeys())
}

/// Günlük için e-posta maskesi: `mehmet@gmail.com` → `m***@gmail.com`.
pub fn mask_email(email: &str) -> String {
    match email.split_once('@') {
        Some((user, domain)) => {
            let first: String = user.chars().take(1).collect();
            format!("{first}***@{domain}")
        }
        None => "***".to_owned(),
    }
}

#[cfg(test)]
mod auth_tests {
    use super::*;
    use sodiumoxide::{base64, crypto::sign};

    // m2y-api ile aynı biçimde (Go json.Marshal: alan sırası e,h,x,n; boşluksuz) üretilmiş sabit vektör.
    // Tohum: 32 x 0x07 (PyNaCl ile üretildi; Ed25519 deterministiktir).
    const VEC_PUBKEY: &str = "6kpsY+KcUgq+9VB7Ey7F+ZVHdq6+vnuSQh7qaRRG0iw=";
    const VEC_TOKEN: &str = "eyJlIjoibWVobWV0QGdtYWlsLmNvbSIsImgiOiIxMjM0NTY3ODkiLCJ4IjoxODAwMDAwMzAwLCJuIjoiQUFFQ0F3UUZCZ2NJQ1FvTERBME9EdyJ9.RZXOeSQnjFguco7BLTCkyacbGvpwmaWZDFvtVGrXiAz1uaus9oWtumuZMrsb-FF923eko9ex0CUNV2h4Q9a1Cg";
    const NOW: u64 = 1_800_000_000;

    fn b64url(b: &[u8]) -> String {
        base64::encode(b, base64::Variant::UrlSafeNoPadding)
    }

    /// m2y-api `m2yYetkiBelirteciImzala` ile aynı yapı.
    fn make_token(sk: &sign::SecretKey, email: &str, target: &str, x: i64) -> String {
        let payload =
            format!(r#"{{"e":"{email}","h":"{target}","x":{x},"n":"AAECAwQFBgcICQoLDA0ODw"}}"#);
        let sig = sign::sign_detached(payload.as_bytes(), sk);
        format!("{}.{}", b64url(payload.as_bytes()), b64url(&sig.to_bytes()))
    }

    fn keypair() -> (String, sign::SecretKey) {
        let (pk, sk) = sign::gen_keypair();
        (base64::encode(&pk.0, base64::Variant::Original), sk)
    }

    #[test]
    fn fixed_vector_matches_server_format() {
        let seed = sign::Seed::from_slice(&[7u8; 32]).unwrap();
        let (pk, sk) = sign::keypair_from_seed(&seed);
        assert_eq!(base64::encode(&pk.0, base64::Variant::Original), VEC_PUBKEY);
        assert_eq!(make_token(&sk, "mehmet@gmail.com", "123456789", 1_800_000_300), VEC_TOKEN);
        assert_eq!(
            verify_m2y_auth(VEC_TOKEN.as_bytes(), "123456789", NOW, VEC_PUBKEY),
            Ok("mehmet@gmail.com".to_owned())
        );
    }

    #[test]
    fn valid_token_and_key_rotation() {
        let (pk, sk) = keypair();
        let (other_pk, _) = keypair();
        let t = make_token(&sk, "a@b.com", "42", (NOW + 300) as i64);
        assert_eq!(verify_m2y_auth(t.as_bytes(), "42", NOW, &pk), Ok("a@b.com".to_owned()));
        assert_eq!(
            verify_m2y_auth(t.as_bytes(), "42", NOW, &format!("{other_pk}, {pk}")),
            Ok("a@b.com".to_owned())
        );
    }

    #[test]
    fn wrong_target() {
        let (pk, sk) = keypair();
        let t = make_token(&sk, "a@b.com", "42", (NOW + 300) as i64);
        assert_eq!(verify_m2y_auth(t.as_bytes(), "43", NOW, &pk), Err("hedef uyuşmuyor"));
        assert_eq!(verify_m2y_auth(t.as_bytes(), "", NOW, &pk), Err("hedef uyuşmuyor"));
        let t = make_token(&sk, "a@b.com", "", (NOW + 300) as i64);
        assert_eq!(verify_m2y_auth(t.as_bytes(), "", NOW, &pk), Err("hedef uyuşmuyor"));
    }

    #[test]
    fn expired_with_clock_skew() {
        let (pk, sk) = keypair();
        let t = make_token(&sk, "a@b.com", "42", NOW as i64);
        // 60 sn tolerans içinde geçerli
        assert!(verify_m2y_auth(t.as_bytes(), "42", NOW + 59, &pk).is_ok());
        assert_eq!(verify_m2y_auth(t.as_bytes(), "42", NOW + 60, &pk), Err("süresi dolmuş"));
        assert_eq!(
            verify_m2y_auth(VEC_TOKEN.as_bytes(), "123456789", NOW + 360, VEC_PUBKEY),
            Err("süresi dolmuş")
        );
        let t = make_token(&sk, "a@b.com", "42", -5);
        assert_eq!(verify_m2y_auth(t.as_bytes(), "42", NOW, &pk), Err("süresi dolmuş"));
    }

    #[test]
    fn tampered_signature_or_payload() {
        let (pk, sk) = keypair();
        let t = make_token(&sk, "a@b.com", "42", (NOW + 300) as i64);
        let (p, s) = t.split_once('.').unwrap();
        // imzanın bir baytı değişti
        let mut sig = base64::decode(s, base64::Variant::UrlSafeNoPadding).unwrap();
        sig[0] ^= 0xff;
        let bad = format!("{p}.{}", b64url(&sig));
        assert_eq!(verify_m2y_auth(bad.as_bytes(), "42", NOW, &pk), Err("imza geçersiz"));
        // yük başka hedefe çevrildi, eski imza
        let forged = make_token(&sk, "a@b.com", "43", (NOW + 300) as i64);
        let (fp, _) = forged.split_once('.').unwrap();
        let mixed = format!("{fp}.{s}");
        assert_eq!(verify_m2y_auth(mixed.as_bytes(), "43", NOW, &pk), Err("imza geçersiz"));
    }

    #[test]
    fn wrong_or_missing_key() {
        let (_, sk) = keypair();
        let (other_pk, _) = keypair();
        let t = make_token(&sk, "a@b.com", "42", (NOW + 300) as i64);
        assert_eq!(verify_m2y_auth(t.as_bytes(), "42", NOW, &other_pk), Err("imza geçersiz"));
        assert_eq!(verify_m2y_auth(t.as_bytes(), "42", NOW, ""), Err("açık anahtar yok"));
        assert_eq!(verify_m2y_auth(t.as_bytes(), "42", NOW, " , !!"), Err("açık anahtar yok"));
        assert_eq!(verify_m2y_auth(t.as_bytes(), "42", NOW, "AAAA"), Err("açık anahtar yok"));
    }

    #[test]
    fn malformed() {
        let (pk, sk) = keypair();
        let t = make_token(&sk, "a@b.com", "42", (NOW + 300) as i64);
        let (p, _) = t.split_once('.').unwrap();
        for bad in [
            String::new(),
            p.to_owned(),
            format!("{t}.x"),
            "!!.!!".to_owned(),
            format!("{p}.AAAA"),
            format!("{t}=="),
        ] {
            assert!(verify_m2y_auth(bad.as_bytes(), "42", NOW, &pk).is_err(), "{bad}");
        }
        assert_eq!(verify_m2y_auth(&[0xff, 0xfe], "42", NOW, &pk), Err("biçim geçersiz"));
        // imzalı ama JSON değil / e-posta boş
        let sig = sign::sign_detached(b"not json", &sk);
        let nj = format!("{}.{}", b64url(b"not json"), b64url(&sig.to_bytes()));
        assert_eq!(verify_m2y_auth(nj.as_bytes(), "42", NOW, &pk), Err("biçim geçersiz"));
        let t = make_token(&sk, "", "42", (NOW + 300) as i64);
        assert_eq!(verify_m2y_auth(t.as_bytes(), "42", NOW, &pk), Err("e-posta yok"));
    }

    #[test]
    fn email_mask() {
        assert_eq!(mask_email("mehmet@gmail.com"), "m***@gmail.com");
        assert_eq!(mask_email("@x.com"), "***@x.com");
        assert_eq!(mask_email("yok"), "***");
    }
}
