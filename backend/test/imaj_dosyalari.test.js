// ÜRETİM İMAJI — BAŞLANGIÇ VERİSİNİN OKUDUĞU DOSYALAR (22 Eki hatası)
//
// Çatılar (029) canlıda boş geldi: başlangıç verisi lib/screens/home_screen.dart
// dosyasını da okuyordu ama Dockerfile bu dosyayı imaja kopyalamıyordu;
// okuma hata verdi ve çatı aktarımı hiç çalışmadı. Testler depo kökünden
// koştuğu için yakalanmamıştı. Bu test seed_from_flutter.js'in okuduğu HER
// dosyanın imaja kopyalandığını denetler.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

test('başlangıç verisinin okuduğu her Flutter dosyası Dockerfile ile imaja kopyalanır', () => {
  const tohum = readFileSync(new URL('../scripts/seed_from_flutter.js', import.meta.url), 'utf8');
  const docker = readFileSync(new URL('../Dockerfile', import.meta.url), 'utf8');
  const okunan = [...tohum.matchAll(/oku\('([^']+)'\)/g)].map((m) => m[1]);
  assert.ok(okunan.length >= 8, 'okunan dosya listesi bulunamadı');
  const kopyalar = [...docker.matchAll(/^COPY\s+(.+)$/gm)].flatMap((m) => m[1].trim().split(/\s+/).slice(0, -1));
  for (const yol of okunan) {
    const kopyali = kopyalar.some((k) => yol === k || yol.startsWith(`${k.replace(/\/$/, '')}/`));
    assert.ok(kopyali, `${yol} imaja kopyalanmıyor (backend/Dockerfile)`);
  }
});
