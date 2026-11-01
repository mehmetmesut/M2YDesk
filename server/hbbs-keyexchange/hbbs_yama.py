import pathlib

p = pathlib.Path("/opt/m2ydesk/hbbs-src/src/rendezvous_server.rs")
s = p.read_text()


def rep(old, new):
    global s
    assert s.count(old) == 1, old
    s = s.replace(old, new)


rep("use sodiumoxide::crypto::sign;",
    "use hbb_common::tcp::Encrypt;\nuse sodiumoxide::crypto::{box_, secretbox, sign};")
rep("    TcpStream(TcpStreamSink),\n",
    "    // M2Y: Encrypt, KeyExchange ile güvenli kanal kurulduysa gönderilen her çerçeveyi şifreler.\n"
    "    TcpStream(TcpStreamSink, Option<Encrypt>),\n")
rep("""                    Sink::TcpStream(s) => {
                        allow_err!(s.send(Bytes::from(bytes)).await);""",
    """                    Sink::TcpStream(s, enc) => {
                        let bytes = match enc {
                            Some(enc) => enc.enc(&bytes),
                            None => bytes,
                        };
                        allow_err!(s.send(Bytes::from(bytes)).await);""")
rep("""            let (a, mut b) = Framed::new(stream, BytesCodec::new()).split();
            sink = Some(Sink::TcpStream(a));
            while let Ok(Some(Ok(bytes))) = timeout(30_000, b.next()).await {
                if !self.handle_tcp(&bytes, &mut sink, addr, key, ws).await {
                    break;
                }
            }""",
    """            let (mut a, mut b) = Framed::new(stream, BytesCodec::new()).split();
            // M2Y: RustDesk Pro gibi önce imzalı KeyExchange gönderilir. Hesapla oturum açmış
            // istemci (resmî mobil/masaüstü) bunu bekler; yoksa "Failed to secure tcp" verir.
            // Diğer istemciler mesajı atlar ve düz kanalda devam eder.
            let mut pending = None;
            let mut key_enc = None;
            if let Some(sk) = self.inner.sk.clone() {
                let (our_pk, our_sk) = box_::gen_keypair();
                let mut msg_out = RendezvousMessage::new();
                msg_out.set_key_exchange(KeyExchange {
                    keys: vec![sign::sign(&our_pk.0, &sk).into()],
                    ..Default::default()
                });
                a.send(Bytes::from(msg_out.write_to_bytes()?)).await?;
                match timeout(30_000, b.next()).await {
                    Ok(Some(Ok(bytes))) => match RendezvousMessage::parse_from_bytes(&bytes)
                        .ok()
                        .and_then(|m| m.union)
                    {
                        Some(rendezvous_message::Union::KeyExchange(ex)) => {
                            key_enc = Some(open_key_exchange(&ex, &our_sk)?);
                        }
                        _ => pending = Some(bytes),
                    },
                    _ => return Ok(()),
                }
            }
            let mut dec = key_enc.clone().map(Encrypt::new);
            sink = Some(Sink::TcpStream(a, key_enc.map(Encrypt::new)));
            let mut open = match pending {
                Some(bytes) => self.handle_tcp(&bytes, &mut sink, addr, key, ws).await,
                None => true,
            };
            while open {
                let Ok(Some(Ok(mut bytes))) = timeout(30_000, b.next()).await else {
                    break;
                };
                if let Some(dec) = dec.as_mut() {
                    if dec.dec(&mut bytes).is_err() {
                        log::debug!("Tcp decrypt failed from {:?}", addr);
                        break;
                    }
                }
                open = self.handle_tcp(&bytes, &mut sink, addr, key, ws).await;
            }""")

s += """
// M2Y: istemcinin KeyExchange yanıtı [geçici açık anahtar, kutulanmış simetrik anahtar] taşır
// (rustdesk common::create_symmetric_key_msg ile aynı biçim, sıfır nonce).
fn open_key_exchange(ex: &KeyExchange, our_sk: &box_::SecretKey) -> ResultType<secretbox::Key> {
    if ex.keys.len() != 2 {
        bail!("Invalid key exchange message");
    }
    let Some(their_pk) = box_::PublicKey::from_slice(&ex.keys[0]) else {
        bail!("Invalid public key in key exchange");
    };
    let nonce = box_::Nonce([0u8; box_::NONCEBYTES]);
    let Ok(key) = box_::open(&ex.keys[1], &nonce, &their_pk, our_sk) else {
        bail!("Failed to open symmetric key");
    };
    let Some(key) = secretbox::Key::from_slice(&key) else {
        bail!("Invalid symmetric key length");
    };
    Ok(key)
}

#[cfg(test)]
mod m2y_key_exchange_tests {
    use super::*;

    #[test]
    fn opens_client_symmetric_key() {
        let (server_pk, server_sk) = box_::gen_keypair();
        // istemci tarafı: create_symmetric_key_msg
        let (client_pk, client_sk) = box_::gen_keypair();
        let key = secretbox::gen_key();
        let nonce = box_::Nonce([0u8; box_::NONCEBYTES]);
        let sealed = box_::seal(&key.0, &nonce, &server_pk, &client_sk);
        let ex = KeyExchange {
            keys: vec![client_pk.0.to_vec().into(), sealed.into()],
            ..Default::default()
        };
        assert_eq!(open_key_exchange(&ex, &server_sk).unwrap(), key);
        let bad = KeyExchange { keys: vec![client_pk.0.to_vec().into()], ..Default::default() };
        assert!(open_key_exchange(&bad, &server_sk).is_err());
    }

    #[test]
    fn encrypt_roundtrip_matches_framed_stream() {
        let key = secretbox::gen_key();
        let mut tx = Encrypt::new(key.clone());
        let mut rx = Encrypt::new(key);
        for msg in [b"hello".to_vec(), b"world!".to_vec()] {
            let mut buf = BytesMut::from(&tx.enc(&msg)[..]);
            rx.dec(&mut buf).unwrap();
            assert_eq!(&buf[..], &msg[..]);
        }
    }
}
"""
p.write_text(s)
print("yama uygulandi")
