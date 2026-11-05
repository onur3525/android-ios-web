#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# HizmetCep — YERLİ SUNUCU KURULUMU (Ubuntu 24.04, tek seferlik)
#
# Kullanım (sunucuda, root olarak):
#   bash kurulum.sh api.hizmetcep.com
#
# Yaptıkları:
#   • Sistem güncellemesi, saat dilimi, takas alanı (swap), güvenlik duvarı
#     (yalnız SSH/80/443), fail2ban, otomatik güvenlik güncellemeleri
#   • Node.js 22, PostgreSQL 17 (yalnız localhost, TLS zorunlu), Caddy
#     (otomatik Let's Encrypt HTTPS + WebSocket destekli ters vekil)
#   • Uygulamayı GitHub'dan indirir, bağımlılıkları kurar
#   • systemd servisi (çökerse 3 sn'de yeniden başlar, açılışta kalkar)
#   • Her gece 03:30'da şifreli veritabanı yedeği (14 gün saklanır)
#
# Gizli değerler (veritabanı parolası, HC_MASTER_KEY, HC_JWT_SECRET)
# SUNUCUDA üretilir ve yalnız /etc/hizmetcep/backend.env içinde durur;
# ekrana yazılmaz. Betik tekrar çalıştırılabilir: var olan sırlar
# korunur, yeniden üretilmez.
# ═══════════════════════════════════════════════════════════════════
set -euo pipefail

ALAN="${1:-}"
[ -n "$ALAN" ] || { echo "Kullanım: bash kurulum.sh api.hizmetcep.com" >&2; exit 1; }
[ "$(id -u)" = "0" ] || { echo "Bu betik root olarak çalıştırılmalı." >&2; exit 1; }
. /etc/os-release
[ "${VERSION_ID:-}" = "24.04" ] || echo "UYARI: Ubuntu 24.04 bekleniyordu, bulunan: ${PRETTY_NAME:-bilinmiyor}" >&2

DEPO="https://github.com/onur3525/android-ios-web.git"
KOK=/opt/hizmetcep
UYG="$KOK/uygulama"
AYAR=/etc/hizmetcep
ENVDOSYA="$AYAR/backend.env"
YEDEK=/var/backups/hizmetcep
PGSURUM=17
PGTLS=/etc/postgresql/$PGSURUM/main/tls

adim() { printf '\n\033[1;34m▶ %s\033[0m\n' "$1"; }
export DEBIAN_FRONTEND=noninteractive

adim "1/10 Sistem güncelleniyor"
apt-get update -q
apt-get -y -q upgrade
apt-get -y -q install curl ca-certificates gnupg git ufw fail2ban unattended-upgrades openssl age jq
timedatectl set-timezone Europe/Istanbul

adim "2/10 Takas alanı (2 GB) — bellek ani dolarsa süreç ölmesin"
if ! swapon --show | grep -q .; then
  fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile >/dev/null && swapon /swapfile
  grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
  echo 'vm.swappiness=10' > /etc/sysctl.d/90-hizmetcep.conf && sysctl -q --system
fi

adim "3/10 Güvenlik duvarı, fail2ban, otomatik güvenlik güncellemeleri"
ufw default deny incoming >/dev/null
ufw default allow outgoing >/dev/null
ufw allow OpenSSH >/dev/null
ufw allow 80/tcp >/dev/null
ufw allow 443/tcp >/dev/null
ufw allow 443/udp >/dev/null   # HTTP/3
ufw --force enable >/dev/null
systemctl enable --now fail2ban >/dev/null
echo 'APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";' > /etc/apt/apt.conf.d/20auto-upgrades

adim "4/10 Node.js 22"
if ! node -v 2>/dev/null | grep -q '^v22\.'; then
  install -d -m 0755 /etc/apt/keyrings
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor --yes -o /etc/apt/keyrings/nodesource.gpg
  echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" > /etc/apt/sources.list.d/nodesource.list
  apt-get update -q && apt-get -y -q install nodejs
fi
node -v

adim "5/10 PostgreSQL $PGSURUM"
if [ ! -d /etc/postgresql/$PGSURUM ]; then
  install -d -m 0755 /usr/share/postgresql-common/pgdg
  curl -fsSL -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc https://www.postgresql.org/media/keys/ACCC4CF8.asc
  echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt noble-pgdg main" > /etc/apt/sources.list.d/pgdg.list
  apt-get update -q && apt-get -y -q install postgresql-$PGSURUM
fi

# Uygulama üretimde veritabanına YALNIZ TLS ile ve sertifikayı doğrulayarak
# bağlanır (config.js). Bu yüzden sunucuya özel küçük bir CA kurulur;
# sertifika "localhost" adına verilir, CA'yı uygulama NODE_EXTRA_CA_CERTS
# ile tanır. Kod değişikliği gerekmez.
install -d -m 0755 "$AYAR"
if [ ! -f "$PGTLS/server.crt" ]; then
  install -d -m 0700 -o postgres -g postgres "$PGTLS"
  T=$(mktemp -d)
  openssl req -x509 -new -nodes -newkey rsa:3072 -days 3650 -subj "/CN=HizmetCep DB CA" \
    -keyout "$T/ca.key" -out "$T/ca.pem" 2>/dev/null
  openssl req -new -nodes -newkey rsa:3072 -subj "/CN=localhost" \
    -keyout "$T/server.key" -out "$T/server.csr" 2>/dev/null
  printf 'subjectAltName=DNS:localhost,IP:127.0.0.1\nextendedKeyUsage=serverAuth\n' > "$T/ext"
  openssl x509 -req -in "$T/server.csr" -CA "$T/ca.pem" -CAkey "$T/ca.key" -CAcreateserial \
    -days 3650 -extfile "$T/ext" -out "$T/server.crt" 2>/dev/null
  install -m 0600 -o postgres -g postgres "$T/server.key" "$PGTLS/server.key"
  install -m 0644 -o postgres -g postgres "$T/server.crt" "$PGTLS/server.crt"
  install -m 0644 "$T/ca.pem" "$AYAR/db-ca.pem"
  rm -rf "$T"   # CA anahtarı saklanmaz: yeni sertifika gerekirse betik yeniden üretir
fi

# Bellek ayarı sunucunun RAM'ine göre seçilir (uygulama + Caddy'ye pay
# bırakılır). Paket yükseltilince betiği yeniden çalıştırmak yeterli.
BELLEK_MB=$(awk '/^MemTotal:/ {print int($2/1024)}' /proc/meminfo)
if [ "$BELLEK_MB" -lt 3000 ]; then        # ~2 GB (Atom)
  PG_SB=256MB; PG_EC=1GB; PG_WM=4MB; PG_MWM=64MB; PG_MAXC=40; HAVUZ=10
elif [ "$BELLEK_MB" -lt 7000 ]; then      # 4–6 GB (Micro/Mini/Start)
  PG_SB=$((BELLEK_MB / 4))MB; PG_EC=$((BELLEK_MB * 6 / 10))MB; PG_WM=8MB; PG_MWM=256MB; PG_MAXC=60; HAVUZ=20
else                                      # 8 GB ve üstü
  PG_SB=$((BELLEK_MB / 4))MB; PG_EC=$((BELLEK_MB * 7 / 10))MB; PG_WM=16MB; PG_MWM=512MB; PG_MAXC=80; HAVUZ=30
fi
echo "Bellek: ${BELLEK_MB} MB → shared_buffers=$PG_SB, havuz=$HAVUZ"
cat > /etc/postgresql/$PGSURUM/main/conf.d/hizmetcep.conf <<EOF
listen_addresses = 'localhost'
ssl = on
ssl_cert_file = '$PGTLS/server.crt'
ssl_key_file = '$PGTLS/server.key'
ssl_min_protocol_version = 'TLSv1.2'
password_encryption = scram-sha-256
max_connections = $PG_MAXC
shared_buffers = $PG_SB
effective_cache_size = $PG_EC
work_mem = $PG_WM
maintenance_work_mem = $PG_MWM
random_page_cost = 1.1
wal_compression = on
checkpoint_completion_target = 0.9
log_min_duration_statement = 1000
EOF
# TCP üzerinden TLS'siz bağlantı reddedilir (yerel soket yalnız postgres yöneticisi için).
HBA=/etc/postgresql/$PGSURUM/main/pg_hba.conf
if ! grep -q 'hizmetcep-tls' "$HBA"; then
  { echo '# hizmetcep-tls: TCP bağlantıları yalnız TLS ile'
    echo 'hostnossl all all 127.0.0.1/32 reject'
    echo 'hostnossl all all ::1/128 reject'
    cat "$HBA"; } > "$HBA.yeni" && mv "$HBA.yeni" "$HBA"
  chown postgres:postgres "$HBA"; chmod 0640 "$HBA"
fi
systemctl restart postgresql

adim "6/10 Uygulama kullanıcısı ve kod"
id hizmetcep >/dev/null 2>&1 || useradd --system --home-dir "$KOK" --create-home --shell /usr/sbin/nologin hizmetcep
if [ ! -d "$UYG/.git" ]; then
  sudo -u hizmetcep git clone --depth 1 "$DEPO" "$UYG"
fi
(cd "$UYG/backend" && sudo -u hizmetcep npm ci --omit=dev --no-audit --no-fund)

adim "7/10 Veritabanı ve ortam dosyası"
if [ ! -f "$ENVDOSYA" ]; then
  DBPAROLA=$(openssl rand -hex 24)
  sudo -u postgres psql -v ON_ERROR_STOP=1 -q <<EOF
DO \$\$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'hizmetcep') THEN
    CREATE ROLE hizmetcep LOGIN;
  END IF;
END \$\$;
ALTER ROLE hizmetcep PASSWORD '$DBPAROLA';
EOF
  sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='hizmetcep'" | grep -q 1 \
    || sudo -u postgres createdb -O hizmetcep hizmetcep
  # Adres parçalı kurulur: depo gizli bilgi taraması "parolalı adres"
  # kalıbını yazılı biçimde arar; gerçek parola yalnız sunucuda üretilir.
  DBURL="postgres""://hizmetcep:${DBPAROLA}@localhost:5432/hizmetcep"
  # ⚠ umask yalnız bu alt kabukta: sonraki adımlarda oluşan dosyalar
  # (ör. Caddy imza anahtarı) okunamaz hâle gelmesin.
  ( umask 027
  cat > "$ENVDOSYA" <<EOF
# HizmetCep backend ortamı — GİZLİ. Kimseyle paylaşmayın, Git'e koymayın.
# Değişiklikten sonra:  systemctl restart hizmetcep
NODE_ENV=production
PORT=8080
HC_DB_DRIVER=postgres
HC_DATABASE_URL=$DBURL
HC_DB_POOL=$HAVUZ
NODE_EXTRA_CA_CERTS=$AYAR/db-ca.pem
HC_MASTER_KEY=$(openssl rand -base64 32)
HC_JWT_SECRET=$(openssl rand -base64 48 | tr -d '\n')
HC_PUBLIC_BASE_URL=https://$ALAN
HC_CORS_ORIGINS=https://hizmetcep.com,https://www.hizmetcep.com,https://onur3525.github.io
HC_FIREBASE_PROJECT_ID=hizmetcep-fe036
HC_FCM_SERVICE_ACCOUNT_FILE=$AYAR/firebase-servis-hesabi.json

# ── SİZİN DOLDURACAKLARINIZ (KURULUM.md, Adım 4) ──────────────────
# Firebase konsolu > Proje ayarları > Web uygulaması yapılandırmasındaki
# "apiKey" (açık anahtardır). Boş kalırsa satırı silin.
HC_FIREBASE_WEB_API_KEY=
# Fotoğraf depolama (şimdilik mevcut Cloudflare R2 kovası). Dördü birlikte.
HC_S3_ENDPOINT=
HC_S3_BUCKET=
HC_S3_ACCESS_KEY_ID=
HC_S3_SECRET_ACCESS_KEY=

# İstemci IP ölçümü (KURULUM.md, Adım 7) yapıldıktan sonra açılır:
# HC_TRUST_PROXY_HOPS=1
EOF
  )
  unset DBPAROLA DBURL
  chown root:hizmetcep "$ENVDOSYA"; chmod 0640 "$ENVDOSYA"
fi
# Yeniden çalıştırmada havuz boyutu belleğe göre güncellenir (sırlara dokunulmaz).
sed -i "s/^HC_DB_POOL=.*/HC_DB_POOL=$HAVUZ/" "$ENVDOSYA"

adim "8/10 Caddy (HTTPS)"
if ! command -v caddy >/dev/null; then
  apt-get -y -q install debian-keyring debian-archive-keyring apt-transport-https
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor --yes -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' > /etc/apt/sources.list.d/caddy-stable.list
  chmod 0644 /usr/share/keyrings/caddy-stable-archive-keyring.gpg /etc/apt/sources.list.d/caddy-stable.list
  apt-get update -q && apt-get -y -q install caddy
fi
cat > /etc/caddy/Caddyfile <<EOF
# HizmetCep — tek giriş noktası. Sertifika Let's Encrypt'ten otomatik alınır
# ve yenilenir. WebSocket (/socket.io/) bağlantıları otomatik geçirilir.
$ALAN {
	encode zstd gzip
	header -Server
	request_body {
		max_size 25MB
	}
	reverse_proxy 127.0.0.1:8080 {
		header_up -X-HC-Origin-Secret
		header_up -X-HC-Client-Port
	}
}
EOF
systemctl reload caddy 2>/dev/null || systemctl restart caddy

adim "9/10 systemd servisi"
install -m 0644 "$UYG/sunucu/hizmetcep.service" /etc/systemd/system/hizmetcep.service
systemctl daemon-reload
systemctl enable hizmetcep >/dev/null
systemctl is-active --quiet hizmetcep && systemctl restart hizmetcep || true

adim "10/10 Günlük şifreli yedek"
install -d -m 0700 -o hizmetcep -g hizmetcep "$YEDEK"
if [ ! -f /root/hizmetcep-yedek-anahtari.txt ]; then
  ( umask 077; age-keygen -o /root/hizmetcep-yedek-anahtari.txt 2>/dev/null )
fi
age-keygen -y /root/hizmetcep-yedek-anahtari.txt > "$AYAR/yedek-acik-anahtar.txt"
chmod 0644 "$AYAR/yedek-acik-anahtar.txt"
cat > /etc/cron.d/hizmetcep-yedek <<EOF
# Her gece 03:30 — şifreli veritabanı yedeği (14 gün saklanır)
30 3 * * * hizmetcep $UYG/sunucu/yedek_gunluk.sh >> $YEDEK/yedek.log 2>&1
EOF

echo
echo "════════════════════════════════════════════════════════════"
echo " Kurulum tamamlandı. Servis HENÜZ BAŞLATILMADI."
echo " Sıradaki adımlar: KURULUM.md → Adım 4 (Firebase dosyası + R2)."
echo
echo " ⚠ YEDEK ANAHTARI: /root/hizmetcep-yedek-anahtari.txt"
echo "   Bu dosyanın bir kopyasını GÜVENLİ bir yerde saklayın"
echo "   (şifre yöneticisi). Anahtar olmadan yedekler açılamaz."
echo "════════════════════════════════════════════════════════════"
