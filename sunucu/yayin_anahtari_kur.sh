#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# HizmetCep — OTOMATİK YAYIN ANAHTARI (sunucuda, root olarak, BİR KEZ)
#
#   bash /opt/hizmetcep/uygulama/sunucu/yayin_anahtari_kur.sh
#
# GitHub'ın sunucuya bağlanıp YALNIZ güncelleme betiğini çalıştırabilmesi
# için kısıtlı bir SSH anahtarı üretir:
#   • Anahtar root'un authorized_keys dosyasına "command=" kısıtıyla
#     eklenir: bu anahtarla bağlanan kim olursa olsun SADECE
#     sunucu/guncelle.sh çalışır; kabuk, dosya okuma, port yönlendirme yok.
#   • Özel anahtar ekrana TEK SATIR olarak yazılır ve sunucudan SİLİNİR.
#     Onu GitHub › Settings › Secrets and variables › Actions bölümüne
#     yapıştırırsınız; kimseyle (sohbet dahil) paylaşmayın.
#   • Sunucunun kimlik satırı da yazılır (GitHub'ın sahte sunucuya
#     bağlanmasını önler).
# Tekrar çalıştırılırsa eski yayın anahtarı kaldırılıp yenisi üretilir.
# ═══════════════════════════════════════════════════════════════════
set -euo pipefail
[ "$(id -u)" = "0" ] || { echo "root olarak çalıştırın" >&2; exit 1; }
ALAN="${1:-api.hizmetcep.com}"
GUNCELLE=/opt/hizmetcep/uygulama/sunucu/guncelle.sh
ETIKET="hizmetcep-github-yayin"
[ -x "$GUNCELLE" ] || chmod +x "$GUNCELLE"

install -d -m 0700 /root/.ssh
touch /root/.ssh/authorized_keys
chmod 0600 /root/.ssh/authorized_keys
# Eski yayın anahtarı varsa kaldırılır (diğer anahtarlara dokunulmaz).
sed -i "/ $ETIKET\$/d" /root/.ssh/authorized_keys

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
ssh-keygen -q -t ed25519 -N '' -C "$ETIKET" -f "$T/anahtar"
echo "command=\"$GUNCELLE\",no-port-forwarding,no-agent-forwarding,no-X11-forwarding,no-pty $(cat "$T/anahtar.pub")" >> /root/.ssh/authorized_keys

ANAHTAR=$(base64 -w0 "$T/anahtar")
KIMLIK="$ALAN $(cut -d' ' -f1,2 /etc/ssh/ssh_host_ed25519_key.pub)"

echo
echo "════════════════════════════════════════════════════════════"
echo " GitHub › Settings › Secrets and variables › Actions › New repository secret"
echo
echo " 1) Ad:  HC_SUNUCU_SSH_ANAHTARI"
echo "    Değer (tek satır, tamamını kopyalayın):"
echo
echo "$ANAHTAR"
echo
echo " 2) Ad:  HC_SUNUCU_KIMLIGI"
echo "    Değer:"
echo
echo "$KIMLIK"
echo
echo " Özel anahtar sunucudan silindi; yalnız GitHub'da duracak."
echo " Bu ekranın görüntüsünü kimseyle paylaşmayın."
echo "════════════════════════════════════════════════════════════"
