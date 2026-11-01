docker run --rm -v /opt/m2ydesk/hbbs-src:/src -v m2y-cargo-cache:/usr/local/cargo/registry \
  -v m2y-hbbs-target:/src/target -e OPENSSL_STATIC=1 -w /src rust:1-alpine \
  sh -c 'apk add -q musl-dev protobuf-dev perl make openssl-dev openssl-libs-static >/dev/null && cargo test --release --lib m2y_ 2>&1 | grep -E "^test |test result|error" '
