// HC_TRUST_PROXY_HOPS YANLIŞ VERİLİRSE NE OLUR (29 Eki, güvenlik planı 2.1)
// Bu dosya değeri BİLEREK fazla verir (2) ve gerçek altyapının yalnız bir
// değer eklediği durumu taklit eder: istemcinin kendi yazdığı (sahte) değer
// seçilir. Eksik verilmesi (0/tanımsız) ws_sinirlari.test.js'te: herkes
// soket (proxy) adresinde toplanır. Doğru değer yalnız ölçümle bulunur
// (DEPLOY.md → "İstemci IP'si ve HC_TRUST_PROXY_HOPS").
import { test } from 'node:test';
import assert from 'node:assert/strict';

process.env.HC_SESSIZ = '1';
process.env.HC_TRUST_PROXY_HOPS = '2';
const { istemciIp } = await import('../src/http.js');
const istek = (xff) => ({ socket: { remoteAddress: '10.0.0.1' }, headers: { 'x-forwarded-for': xff } });

test('değer FAZLA verilirse istemcinin yazdığı sahte adres seçilir (sahtecilik geri gelir)', () => {
  // Saldırgan "198.51.100.200" yazar; proxy gerçek adresi (203.0.113.7) sona ekler.
  assert.equal(istemciIp(istek('198.51.100.200, 203.0.113.7')), '198.51.100.200');
});

test('başlıkta yeterli değer yoksa soket adresi kullanılır', () => {
  assert.equal(istemciIp(istek('203.0.113.7')), '10.0.0.1');
});
