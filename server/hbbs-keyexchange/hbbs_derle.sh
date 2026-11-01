set -e
cd /opt/m2ydesk/hbbs-src
git checkout -q src/rendezvous_server.rs
python3 /tmp/hbbs_yama.py
docker run --rm -v /opt/m2ydesk/hbbs-src:/src -v m2y-cargo-cache:/usr/local/cargo/registry -v m2y-hbbs-target:/src/target -e OPENSSL_STATIC=1 -w /src rust:1-alpine \
  sh -c 'apk add -q musl-dev protobuf-dev perl make openssl-dev openssl-libs-static >/dev/null && cargo test --release --bin hbbs m2y_ 2>&1 | tail -15 && cargo build --release --bin hbbs 2>&1 | tail -5 && cp target/release/hbbs /src/hbbs-m2y'
ls -la hbbs-m2y
file hbbs-m2y
