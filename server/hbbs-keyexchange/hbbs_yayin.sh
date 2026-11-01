set -e
cd /opt/m2ydesk/hbbs-src
printf 'FROM rustdesk/rustdesk-server:latest\nCOPY hbbs-m2y /usr/bin/hbbs\n' > Dockerfile.m2y
docker build -q -f Dockerfile.m2y -t m2y-hbbs:yerel .
cd /opt/m2ydesk/server
cp docker-compose.yml docker-compose.yml.bak-20261101
python3 - <<'EOF'
import pathlib
p = pathlib.Path("/opt/m2ydesk/server/docker-compose.yml")
s = p.read_text()
blok = s.split("  hbbs:", 1)
eski = "image: rustdesk/rustdesk-server:${RUSTDESK_SURUM:-latest}"
assert eski in blok[1].split("  hbbr:", 1)[0]
blok[1] = blok[1].replace(eski, "image: ${M2Y_HBBS_IMAJ:-m2y-hbbs:yerel}  # KeyExchange yamali hbbs (/opt/m2ydesk/hbbs-src)", 1)
p.write_text("  hbbs:".join(blok))
EOF
grep -n 'image:' docker-compose.yml
docker compose up -d hbbs
sleep 4
docker logs --tail 5 hbbs 2>&1
# ilk mesaj KeyExchange mi? (protobuf alan etiketi gelmeli)
timeout 3 bash -c 'exec 3<>/dev/tcp/127.0.0.1/21116; head -c 80 <&3 | od -An -tx1 | head -3' || true
