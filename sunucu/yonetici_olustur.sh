#!/usr/bin/env bash
# HizmetCep — İLK YÖNETİCİ hesabı (admin paneli girişi).
# Kullanım (root, servis en az bir kez başlatıldıktan sonra):
#   bash /opt/hizmetcep/uygulama/sunucu/yonetici_olustur.sh
# Şifre ekranda görünmez ve kabuk geçmişine düşmez. Sonunda bir kez
# gösterilen doğrulama (TOTP) sırrını Google Authenticator'a ekleyin.
set -euo pipefail
[ "$(id -u)" = "0" ] || { echo "root olarak çalıştırın" >&2; exit 1; }
read -rp "Yönetici e-postası: " EPOSTA
read -rp "Ad Soyad: " AD
read -rsp "Şifre (görünmez): " SIFRE; echo
read -rsp "Şifre tekrar: " SIFRE2; echo
[ "$SIFRE" = "$SIFRE2" ] || { echo "Şifreler aynı değil." >&2; exit 1; }
cd /opt/hizmetcep/uygulama/backend
export HC_ADMIN_PASSWORD="$SIFRE"   # süreç listesinde görünmesin diye argüman değil, ortam
sudo -u hizmetcep --preserve-env=HC_ADMIN_PASSWORD bash -c \
  'set -a; . /etc/hizmetcep/backend.env; set +a; exec node --no-warnings scripts/create_admin.js "$0" "$1"' \
  "$EPOSTA" "$AD"
