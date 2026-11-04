#!/usr/bin/env bash
# HizmetCep — günlük ŞİFRELİ veritabanı yedeği (cron: her gece 03:30).
# Elle:  sudo -u hizmetcep /opt/hizmetcep/uygulama/sunucu/yedek_gunluk.sh
#
# • Mevcut backend/scripts/yedek_al.sh ile alınır (pg_dump + doğrulama).
# • age ile sunucudaki AÇIK anahtara şifrelenir; şifresiz kopya silinir.
#   Açmak için özel anahtar gerekir (/root/hizmetcep-yedek-anahtari.txt).
# • 14 günden eski yedekler silinir.
set -euo pipefail
YEDEK=/var/backups/hizmetcep
UYG=/opt/hizmetcep/uygulama
SAKLA_GUN="${SAKLA_GUN:-14}"

HC_DATABASE_URL=$(grep -m1 '^HC_DATABASE_URL=' /etc/hizmetcep/backend.env | cut -d= -f2-)
export HC_DATABASE_URL
[ -n "$HC_DATABASE_URL" ] || { echo "HATA: HC_DATABASE_URL okunamadı" >&2; exit 1; }

GECICI="$YEDEK/.gecici"
rm -rf "$GECICI"; install -d -m 0700 "$GECICI"
trap 'rm -rf "$GECICI"' EXIT

"$UYG/backend/scripts/yedek_al.sh" "$GECICI" >/dev/null
DOSYA=$(ls "$GECICI"/*.dump)
umask 077
age -R /etc/hizmetcep/yedek-acik-anahtar.txt -o "$YEDEK/$(basename "$DOSYA").age" "$DOSYA"
find "$YEDEK" -maxdepth 1 -name 'hizmetcep-*.dump.age' -mtime +"$SAKLA_GUN" -delete
echo "$(date '+%F %T') yedek tamam: $(basename "$DOSYA").age ($(du -h "$YEDEK/$(basename "$DOSYA").age" | cut -f1))"
