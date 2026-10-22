// GÜVENLİ HATA GÜNLÜĞÜ (KVKK takip denetimi B11, 22 Eki): beklenmeyen
// hatada telefon, e-posta, jeton, OTP ve SQL değerleri günlüğe girmez;
// istek kimliği ve hata kodu korunur.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';

process.env.HC_SESSIZ = '1';
const { hataOzeti, maskele } = await import('../src/guvenli_gunluk.js');
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');

test('maskele: telefon, e-posta, jeton, OTP ve SQL değeri', () => {
  const m = maskele('tel +90 532 000 11 22 / 5320001122, mail ayse@ornek.com, Bearer abc.def.ghi, eyJhbGciOi.eyJzdWIiOi.imza, kod 123456, Key (phone)=(5320001122) already exists');
  for (const gizli of ['532', 'ayse@', 'abc.def', 'eyJhbGciOi', '123456']) assert.equal(m.includes(gizli), false, gizli);
  assert.match(m, /Key \(phone\)=\(\[(değer|sayı)\]\)/);
  assert.equal(maskele('ilan 42 bulunamadı'), 'ilan 42 bulunamadı', 'kısa sayılar ve düz metin kalır');
});

test('hataOzeti: PostgreSQL ayrıntı alanları yazılmaz; kod ve yığın kalır', () => {
  const e = Object.assign(new Error('duplicate key value violates unique constraint "users_phone_key" 5320001122'), {
    code: '23505', detail: 'Key (phone)=(5320001122) already exists.', parameters: ['5320001122', 'ayse@ornek.com'], where: 'x',
  });
  const o = hataOzeti(e);
  const s = JSON.stringify(o);
  assert.equal(o.kod, '23505');
  assert.equal(o.ad, 'Error');
  assert.equal(s.includes('5320001122'), false);
  assert.equal(s.includes('ayse@'), false);
  assert.equal('detail' in o || 'parameters' in o, false);
  assert.ok(Array.isArray(o.yigin) && o.yigin.length > 0);
});

test('beklenmeyen hata: istek kimliği yanıtta ve günlükte aynı; günlükte kişisel değer yok', async () => {
  const db = await testDb();
  const asil = db.prepare.bind(db);
  // Herkese açık yasal belge listesinde kişisel değer taşıyan bir veritabanı hatası taklit edilir.
  db.prepare = (sql) => {
    if (/legal_documents/.test(sql)) {
      const at = async () => { throw Object.assign(new Error('bağlantı hatası ayse@ornek.com 5320001122'), { code: 'XX000', detail: 'Key (phone)=(5320001122)' }); };
      return { get: at, all: at, run: at };
    }
    return asil(sql);
  };
  const yazilan = [];
  const eski = console.error;
  console.error = (...a) => yazilan.push(a.map(String).join(' '));
  const sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  try {
    const r = await fetch(`http://127.0.0.1:${sunucu.address().port}/api/v1/legal`);
    const j = await r.json();
    const gunluk = yazilan.join('\n');
    assert.equal(r.status, 500);
    assert.equal(j.error.code, 'INTERNAL_ERROR');
    assert.ok(j.requestId);
    assert.ok(gunluk.includes(`[${j.requestId}]`), 'korelasyon kimliği günlükte');
    assert.ok(gunluk.includes('XX000'), 'hata kodu günlükte');
    for (const gizli of ['ayse@ornek.com', '5320001122']) assert.equal(gunluk.includes(gizli), false, gizli);
    assert.equal(JSON.stringify(j).includes('5320001122'), false, 'yanıtta da yok');
  } finally {
    console.error = eski;
    sunucu.close();
    db.prepare = asil;
    await db.close();
  }
});
