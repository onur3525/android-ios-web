#!/usr/bin/env bash
# HizmetCep — GÜNCELLEME (GitHub'daki main dalının son hâlini yayınlar).
# Kullanım (root):  bash /opt/hizmetcep/uygulama/sunucu/guncelle.sh
#
# Sıra: önce yedek → kodu çek → bağımlılıklar → yeniden başlat → sağlık
# denetimi. Şema göçleri uygulama açılırken kendiliğinden çalışır.
set -euo pipefail
[ "$(id -u)" = "0" ] || { echo "root olarak çalıştırın" >&2; exit 1; }
UYG=/opt/hizmetcep/uygulama

echo "▶ Güncelleme öncesi yedek"
sudo -u hizmetcep "$UYG/sunucu/yedek_gunluk.sh"

echo "▶ Kod güncelleniyor"
ESKI=$(sudo -u hizmetcep git -C "$UYG" rev-parse --short HEAD)
sudo -u hizmetcep git -C "$UYG" fetch --depth 1 origin main
sudo -u hizmetcep git -C "$UYG" reset --hard origin/main
YENI=$(sudo -u hizmetcep git -C "$UYG" rev-parse --short HEAD)
echo "  $ESKI → $YENI"

echo "▶ Bağımlılıklar"
(cd "$UYG/backend" && sudo -u hizmetcep npm ci --omit=dev --no-audit --no-fund)
install -m 0644 "$UYG/sunucu/hizmetcep.service" /etc/systemd/system/hizmetcep.service
systemctl daemon-reload

echo "▶ Yeniden başlatılıyor"
systemctl restart hizmetcep
for _ in $(seq 1 30); do
  if curl -fsS http://127.0.0.1:8080/readyz >/dev/null 2>&1; then
    echo "✔ Hazır ($YENI)"; exit 0
  fi
  sleep 2
done
echo "✘ Uygulama 60 sn içinde hazır olmadı. Son günlük satırları:" >&2
journalctl -u hizmetcep -n 40 --no-pager >&2
echo "Geri dönmek için: git -C $UYG reset --hard $ESKI && systemctl restart hizmetcep" >&2
exit 1
