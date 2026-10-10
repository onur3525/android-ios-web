#!/usr/bin/env bash
# HizmetCep PostgreSQL YEDEĞİ (pg_dump, özel biçim, sıkıştırılmış).
# Kullanım:  HC_DATABASE_URL=postgres://... ./scripts/yedek_al.sh [hedef_klasör]
# ⚠ Yedek kişisel veri içerir: şifreli ve erişimi kısıtlı bir yerde saklayın.
# ⚠ Bağlantı adresi (parola dahil) ekrana/günlüğe YAZDIRILMAZ.
set -euo pipefail
: "${HC_DATABASE_URL:?HC_DATABASE_URL tanımlı değil}"
HEDEF="${1:-./yedekler}"
mkdir -p "$HEDEF"; chmod 700 "$HEDEF"
DOSYA="$HEDEF/hizmetcep-$(date -u +%Y%m%dT%H%M%SZ).dump"
umask 077
pg_dump --format=custom --no-owner --no-privileges --dbname="$HC_DATABASE_URL" --file="$DOSYA"
# Doğrulama: arşivin içeriği okunabiliyor mu ve göç tablosu içinde mi?
pg_restore --list "$DOSYA" > "$DOSYA.icerik"
grep -q "schema_migrations" "$DOSYA.icerik" || { echo "HATA: yedekte schema_migrations yok" >&2; exit 1; }
sha256sum "$DOSYA" > "$DOSYA.sha256"
echo "Yedek hazır: $DOSYA ($(du -h "$DOSYA" | cut -f1)); özet: $DOSYA.sha256"
