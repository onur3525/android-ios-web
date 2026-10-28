// Arka plan iş turu (28 Eki): en çok N iş aynı anda; hata ve takılma
// turu durdurmaz. Önceden 12 iş aynı anda başlıyor, havuzu kilitliyordu.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { isTuru } from '../src/is_turu.js';

const bekle = (ms) => new Promise((ok) => setTimeout(ok, ms));

test('aynı anda en çok 2 iş koşar; hepsi çalışır', async () => {
  let simdi = 0; let tepe = 0; const biten = [];
  const isler = Array.from({ length: 12 }, (_, i) => [`is${i}`, async () => {
    simdi += 1; tepe = Math.max(tepe, simdi);
    await bekle(10);
    simdi -= 1; biten.push(i);
  }]);
  await isTuru(isler, () => {});
  assert.equal(tepe, 2);
  assert.equal(biten.length, 12);
});

test('bir işin hatası diğerlerini durdurmaz', async () => {
  const hatalar = []; let calisan = 0;
  await isTuru([
    ['a', async () => { calisan += 1; }],
    ['b', async () => { throw new Error('bozuk'); }],
    ['c', () => { throw new Error('eşzamanlı hata'); }],
    ['d', async () => { calisan += 1; }],
  ], (ad, e) => hatalar.push(`${ad}:${e.message}`));
  assert.equal(calisan, 2);
  assert.deepEqual(hatalar.sort(), ['b:bozuk', 'c:eşzamanlı hata']);
});

test('takılan iş turu kilitlemez (bekleme sınırından sonra sıra ilerler)', async () => {
  const sira = [];
  const t0 = Date.now();
  // Sınır zamanlayıcısı kapanışı tutmasın diye `unref`li; canlıda süreci
  // HTTP sunucusu açık tutar, testte bu sahte zamanlayıcı tutar.
  const tut = setInterval(() => {}, 1000);
  await isTuru([
    ['takilan1', () => new Promise(() => {})],
    ['takilan2', () => new Promise(() => {})],
    ['sonraki', async () => { sira.push('sonraki'); }],
  ], () => {}, { esZamanli: 2, azamiBeklemeMs: 100 });
  clearInterval(tut);
  assert.deepEqual(sira, ['sonraki']);
  assert.ok(Date.now() - t0 < 1000);
});

test('boş liste', async () => {
  await isTuru([], () => {});
});

test('server.js: işler isTuru ile ve üst üste binmeden zamanlanır', async () => {
  const { readFile } = await import('node:fs/promises');
  const k = await readFile(new URL('../src/server.js', import.meta.url), 'utf8');
  assert.ok(k.includes('isTuru(isler.map('));
  assert.ok(k.includes('if (!turSuruyor)'));
  assert.equal(/for \(const \[ad, f\] of isler\) db\.isKilidi/.test(k), false, 'hepsi aynı anda başlatılmamalı');
});
