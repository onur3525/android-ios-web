#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# YÜK TESTİ KARARI (28 Eki) — iş akışının son adımı.
# Aşağıdakilerden biri bile varsa çıkış kodu 1 (iş BAŞARISIZ):
#   1) k6 çıkış kodu sıfır değil (eşik aşımı, erken durdurma, betik hatası)
#   2) sonuc.json yok / bozuk (test başlamadı ya da yarıda öldü)
#   3) sonuc.json'da aşılmış (true) eşik var
#   4) test planlanan süreyi tamamlamadı (eksik test)
# Planlanan süre kademeli.js ile AYNI kuraldan hesaplanır:
#   kademe başına 1 dk tırmanış + 2 dk sabit, sonda 30 sn iniş.
# Kullanım: HEDEF_RPS=500 bash yuk-testi/karar.sh   (çalışma dizininde
#   k6_cikis.txt, k6_sure.txt, sonuc.json beklenir)
# ═══════════════════════════════════════════════════════════════
set -u
sorun=()

hedef=${HEDEF_RPS:-500}
[[ "$hedef" =~ ^[0-9]+$ ]] || hedef=500
(( hedef < 10 )) && hedef=10
(( hedef > 500 )) && hedef=500
kademe=0; son=0
for k in 50 100 250 500; do (( k <= hedef )) && { kademe=$((kademe + 1)); son=$k; }; done
(( son != hedef )) && kademe=$((kademe + 1))
plan=$(( kademe * 180 + 30 ))
pay=20 # k6 başlangıç/kapanış payı (sn)

cikis=$(cat k6_cikis.txt 2>/dev/null || echo yok)
sure=$(cat k6_sure.txt 2>/dev/null || echo 0)

if [[ "$cikis" != "0" ]]; then
  sorun+=("k6 çıkış kodu: $cikis (eşik aşımı/erken durdurma/hata)")
fi

if ! jq -e '.metrics' sonuc.json >/dev/null 2>&1; then
  sorun+=("sonuc.json yok ya da okunamıyor")
else
  asilan=$(jq -r '.metrics | to_entries[] | select(.value.thresholds != null)
    | .key as $m | .value.thresholds | to_entries[] | select(.value == true) | "\($m): \(.key)"' sonuc.json)
  if [[ -n "$asilan" ]]; then
    while IFS= read -r s; do sorun+=("eşik aşıldı → $s"); done <<< "$asilan"
  fi
fi

if [[ "$sure" =~ ^[0-9]+$ ]] && (( sure + pay < plan )); then
  sorun+=("eksik test: ${sure} sn sürdü, plan ${plan} sn")
fi

{
  echo "## Karar"
  if (( ${#sorun[@]} )); then
    echo "**BAŞARISIZ** — hedef ${hedef} istek/sn, süre ${sure}/${plan} sn"
    for s in "${sorun[@]}"; do echo "- $s"; done
  else
    echo "**BAŞARILI** — hedef ${hedef} istek/sn, süre ${sure}/${plan} sn, eşikler aşılmadı"
  fi
} | tee -a "${GITHUB_STEP_SUMMARY:-/dev/null}"

if (( ${#sorun[@]} )); then
  for s in "${sorun[@]}"; do echo "::error title=Yük testi::$s"; done
  exit 1
fi
