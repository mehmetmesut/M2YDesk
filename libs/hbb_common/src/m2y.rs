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

#[cfg(test)]
mod tests {
    use super::*;

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
