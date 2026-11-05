#!/usr/bin/env bash
# HizmetCep — GÜNCELLEME (GitHub'daki main dalının son hâlini yayınlar).
# Kullanım (root):  bash /opt/hizmetcep/uygulama/sunucu/guncelle.sh [--zorla]
#
# Otomatik yayında GitHub bu betiği kısıtlı SSH anahtarıyla çağırır
# (sunucu/yayin_anahtari_kur.sh). Elle de çalıştırılabilir.
#
# Sıra: kodu getir → değişiklik yoksa dur → yedek → kodu uygula →
# bağımlılıklar → yeniden başlat → sağlık denetimi. Sağlık denetimi
# geçmezse önceki sürüme KENDİLİĞİNDEN geri dönülür.
# Şema göçleri uygulama açılırken kendiliğinden çalışır.
set -euo pipefail
[ "$(id -u)" = "0" ] || { echo "root olarak çalıştırın" >&2; exit 1; }
# Root'un ev klasöründe (otomatik yayında SSH oraya düşer) uygulama
# kullanıcısı çalışamaz; her adım kök klasörden başlar.
cd /
UYG=/opt/hizmetcep/uygulama
ZORLA=false
[ "${1:-}" = "--zorla" ] && ZORLA=true
# Otomatik yayın, testleri geçen sürümün kimliğini gönderir. main o arada
# daha yeni bir sürüme geçtiyse (testleri henüz bitmemiş) burada yayın
# yapılmaz; o sürüm kendi testleri geçince yayınlanır.
BEKLENEN=""
if [[ "${SSH_ORIGINAL_COMMAND:-}" =~ ^[0-9a-f]{40}$ ]]; then
  BEKLENEN="$SSH_ORIGINAL_COMMAND"
fi

# Aynı anda iki güncelleme çalışmaz (art arda iki birleştirme gibi).
exec 9>/var/lock/hizmetcep-guncelle.lock
if ! flock -w 600 9; then
  echo "✘ Başka bir güncelleme 10 dakikadır sürüyor; vazgeçildi." >&2; exit 1
fi

git_() { sudo -u hizmetcep git -C "$UYG" "$@"; }

hazir_mi() {
  for _ in $(seq 1 30); do
    curl -fsS http://127.0.0.1:8080/readyz >/dev/null 2>&1 && return 0
    sleep 2
  done
  return 1
}

uygula() {
  (cd "$UYG/backend" && sudo -u hizmetcep npm ci --omit=dev --no-audit --no-fund)
  install -m 0644 "$UYG/sunucu/hizmetcep.service" /etc/systemd/system/hizmetcep.service
  systemctl daemon-reload
  systemctl restart hizmetcep
}

echo "▶ Kod getiriliyor"
ESKI=$(git_ rev-parse HEAD)
git_ fetch --depth 1 origin main
HEDEF=$(git_ rev-parse origin/main)
echo "  ${ESKI:0:7} → ${HEDEF:0:7}"

if [ -n "$BEKLENEN" ] && [ "$BEKLENEN" != "$HEDEF" ]; then
  echo "✔ main daha yeni bir sürüme geçmiş (${HEDEF:0:7}); testleri bitince o yayınlanacak."
  exit 0
fi

if [ "$ESKI" = "$HEDEF" ] && [ "$ZORLA" = false ] && systemctl is-active --quiet hizmetcep; then
  echo "✔ Sunucu zaten güncel (${ESKI:0:7}); bir şey yapılmadı."
  exit 0
fi

echo "▶ Güncelleme öncesi yedek"
sudo -u hizmetcep "$UYG/sunucu/yedek_gunluk.sh"

echo "▶ Yeni sürüm uygulanıyor"
git_ reset --hard "$HEDEF"
uygula

if hazir_mi; then
  echo "✔ Hazır (${HEDEF:0:7})"; exit 0
fi

echo "✘ Yeni sürüm 60 sn içinde hazır olmadı. Son günlük satırları:" >&2
journalctl -u hizmetcep -n 40 --no-pager >&2 || true

if [ "$ESKI" != "$HEDEF" ]; then
  echo "↩ Önceki sürüme (${ESKI:0:7}) geri dönülüyor" >&2
  git_ fetch --depth 1 origin "$ESKI" || true
  if git_ reset --hard "$ESKI"; then
    uygula
    if hazir_mi; then
      echo "↩ Önceki sürüm yeniden çalışıyor (${ESKI:0:7}). Yeni sürüm YAYINLANMADI." >&2
    else
      echo "✘ Önceki sürüm de açılmadı; günlüğe bakın: journalctl -u hizmetcep -n 100" >&2
    fi
  fi
fi
exit 1
