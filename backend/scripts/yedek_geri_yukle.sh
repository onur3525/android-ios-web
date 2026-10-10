#!/usr/bin/env bash
# HizmetCep PostgreSQL GERİ YÜKLEME — BOŞ bir veritabanına.
# Kullanım:  HC_RESTORE_URL=postgres://.../hizmetcep_geri ./scripts/yedek_geri_yukle.sh <dosya.dump>
# ⚠ Canlı veritabanının ÜZERİNE yazmaz: hedefte tablo varsa durur. Önce
#   boş bir veritabanına geri yükleyin, doğrulayın, sonra uygulamayı oraya
#   yönlendirin (HC_DATABASE_URL). Eski veritabanı geri dönüş için kalır.
set -euo pipefail
: "${HC_RESTORE_URL:?HC_RESTORE_URL (boş hedef veritabanı) tanımlı değil}"
DOSYA="${1:?yedek dosyası verilmedi}"
[ -f "$DOSYA.sha256" ] && sha256sum -c "$DOSYA.sha256"
VAR=$(psql "$HC_RESTORE_URL" -tAc "SELECT count(*) FROM information_schema.tables WHERE table_schema='public'")
[ "$VAR" = "0" ] || { echo "HATA: hedef veritabanı boş değil ($VAR tablo). Durduruldu." >&2; exit 1; }
pg_restore --no-owner --no-privileges --exit-on-error --dbname="$HC_RESTORE_URL" "$DOSYA"
echo "Geri yüklendi. Doğrulama:"
psql "$HC_RESTORE_URL" -tAc "SELECT 'son göç: ' || max(id) FROM schema_migrations"
psql "$HC_RESTORE_URL" -tAc "SELECT 'kullanıcı: ' || count(*) FROM users"
psql "$HC_RESTORE_URL" -tAc "SELECT 'kategori: ' || count(*) FROM categories WHERE deleted_at IS NULL"
