#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# GRADLE WRAPPER HAZIRLIĞI — TEK KAYNAK
#
# codemagic.yaml'daki BÜTÜN iş akışları bu betiği çağırır; eskiden
# her iş akışı kendi `curl` satırını taşıyordu (yedi kopya, ikisi
# farklı sürüm, biri hatalı adres).
#
# Güvenlik turu 2 (M-06) düzeltmeleri:
#   1. SÜRÜM/ETİKET HATASI: sürüm `distributionUrl` satırından okunur.
#      Etiket üç bileşenliyse aynen (9.5.0 → v9.5.0), iki bileşenliyse
#      `.0` eklenir (8.14 → v8.14.0). Eski kod her zaman `.0`
#      ekliyordu (9.5.0 → v9.5.0.0 — böyle bir etiket YOK).
#   2. SESSİZ BAŞARISIZLIK YOK: `set -euo pipefail` + `curl -f`.
#      Eskiden `curl -sL` 404 sayfasını jar diye kaydediyordu.
#      İndirme geçici dosyaya yapılır; yarım dosya jar olmaz.
#   3. JAR BÜTÜNLÜĞÜ: dosyanın gerçek bir wrapper jar olduğu (zip ve
#      içinde `GradleWrapperMain.class`) denetlenir.
#   4. DAĞITIM SAĞLAMASI: `distributionSha256Sum` yoksa, Gradle'ın
#      RESMÎ sunucusundaki `<dağıtım>.zip.sha256` dosyasından alınır
#      ve özelliklere yazılır; Gradle indirdiği dağıtımı bu değerle
#      doğrular. Değer UYDURULMAZ — yalnız resmî kaynaktan okunur ve
#      biçimi (64 onaltılık karakter) denetlenir.
#
# ⚠ BİLİNEN SINIR — WRAPPER JAR'IN KENDİ SAĞLAMASI YOK:
#   GitHub etiketindeki jar, o sürümün yayımladığı wrapper jar ile
#   birebir aynı olmak zorunda değil (depo kendi derlemesi için bir
#   önceki sürümün wrapper'ını taşıyabilir). Bu yüzden tek bir resmî
#   sağlama ile karşılaştırılamıyor. Kalıcı çözüm: jar'ı yerelde
#   `gradle wrapper` ile üretip depoya işlemek ve CI'da resmî
#   `gradle/actions/wrapper-validation` denetimini çalıştırmak.
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

cd "$(dirname "$0")"   # → android/

PROPS=gradle/wrapper/gradle-wrapper.properties
JAR=gradle/wrapper/gradle-wrapper.jar

DAGITIM=$(grep -E '^distributionUrl=' "$PROPS" \
          | grep -oE 'gradle-[0-9]+(\.[0-9]+)+-(all|bin)\.zip' | head -1 || true)
if [ -z "$DAGITIM" ]; then
  echo "HATA: $PROPS içinde distributionUrl okunamadı."
  exit 1
fi
SURUM=$(echo "$DAGITIM" | sed -E 's/^gradle-([0-9.]+)-(all|bin)\.zip$/\1/')

case "$SURUM" in
  *.*.*) ETIKET="v$SURUM" ;;
  *)     ETIKET="v$SURUM.0" ;;
esac

mkdir -p gradle/wrapper

if [ ! -s "$JAR" ]; then
  echo "Gradle $SURUM wrapper jar indiriliyor ($ETIKET)"
  curl -fsSL --retry 3 --proto '=https' --tlsv1.2 -o "$JAR.tmp" \
    "https://raw.githubusercontent.com/gradle/gradle/$ETIKET/gradle/wrapper/gradle-wrapper.jar"
  mv "$JAR.tmp" "$JAR"
fi

if ! unzip -l "$JAR" 2>/dev/null | grep -q 'org/gradle/wrapper/GradleWrapperMain.class'; then
  echo "HATA: $JAR geçerli bir Gradle wrapper jar değil."
  exit 1
fi

if ! grep -q '^distributionSha256Sum=' "$PROPS"; then
  TOPLAM=$(curl -fsSL --retry 3 --proto '=https' --tlsv1.2 \
    "https://services.gradle.org/distributions/${DAGITIM}.sha256" | tr -d '[:space:]')
  if ! echo "$TOPLAM" | grep -qE '^[0-9a-f]{64}$'; then
    echo "HATA: resmî dağıtım sağlaması okunamadı ya da biçimi geçersiz."
    exit 1
  fi
  printf '\ndistributionSha256Sum=%s\n' "$TOPLAM" >> "$PROPS"
  echo "distributionSha256Sum eklendi (kaynak: services.gradle.org)."
fi

ls -la gradle/wrapper/
