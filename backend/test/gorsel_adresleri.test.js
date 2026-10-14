// İlan/talep/sohbet yanıtlarında dosya referansı → imzalı görüntüleme adresi.
// ⚠ Depolama uç noktası SAHTE bir adrestir (s3.example); imza yerel HMAC
// hesabıdır, ağ çağrısı yapılmaz. Gerçek kovanın adresi açtığını KANITLAMAZ.
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';

process.env.HC_TEST_OTP_KANCASI = '1';
process.env.HC_SESSIZ = '1';
const S3 = {
  HC_S3_ENDPOINT: 'https://s3.example', HC_S3_BUCKET: 'kova',
  HC_S3_ACCESS_KEY_ID: 'yalniz-test', HC_S3_SECRET_ACCESS_KEY: 'yalniz-test-gizli', HC_S3_PATH_STYLE: 'true',
};
Object.assign(process.env, S3);

const { simdi } = await import('../src/db.js');
const { testDb } = await import('./destek.js');
const { uygulamaKur } = await import('../src/server.js');
const { tohumla } = await import('../scripts/seed_from_flutter.js');
const { gorselAdresleriEkle } = await import('../src/gorsel_adresleri.js');

let db, sunucu, taban, token, kullaniciId;
const TEL = '5357770001';

async function istek(yol, { yontem = 'GET', govde } = {}) {
  const r = await fetch(taban + yol, {
    method: yontem,
    headers: { ...(govde ? { 'Content-Type': 'application/json' } : {}), ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: govde ? JSON.stringify(govde) : undefined,
  });
  const m = await r.text();
  return { durum: r.status, json: m ? JSON.parse(m) : null };
}
const nesne = (ref, durum = 'ATTACHED') => db.prepare(
  `INSERT INTO storage_objects (ref, owner_id, kind, content_type, size_bytes, status, created_at) VALUES (?, ?, 'listing-photo', 'image/jpeg', 100, ?, ?)`,
).run(ref, kullaniciId, durum, simdi());

before(async () => {
  db = await testDb();
  await tohumla(db);
  sunucu = createServer(uygulamaKur(db));
  await new Promise((ok) => sunucu.listen(0, ok));
  taban = `http://127.0.0.1:${sunucu.address().port}`;
  assert.equal((await istek('/api/v1/auth/otp/request', { yontem: 'POST', govde: { phone: TEL, purpose: 'REGISTER' } })).durum, 204);
  const k = await istek('/api/v1/auth/register', { yontem: 'POST', govde: { phone: TEL, password: 'sifre1234', name: 'Foto Deneme', email: 'foto@ornek.com', role: 'CUSTOMER', otpCode: globalThis.__sonOtp } });
  assert.equal(k.durum, 200, JSON.stringify(k.json));
  token = k.json.accessToken;
  kullaniciId = (await istek('/api/v1/users/me')).json.id;
});
after(async () => {
  sunucu?.close();
  await db?.close();
});

test('ilan yanıtı: referanslar AYNEN kalır, yanına aynı sırada imzalı adres eklenir', async () => {
  const gecerli = `u/${kullaniciId}/${randomUUID()}.jpg`;
  const atilmis = `u/${kullaniciId}/${randomUUID()}.jpg`;
  const bilinmeyen = `u/${kullaniciId}/${randomUUID()}.jpg`;
  await nesne(gecerli);
  await nesne(atilmis, 'DISCARDED');
  await db.prepare(`INSERT INTO listings (id, ilan_no, owner_id, title, location, description, photo_refs_json, status, created_at, expires_at, updated_at)
    VALUES (?, ?, ?, 'Boya', 'Bornova', 'deneme ilan açıklaması', ?, 'ACTIVE', ?, ?, ?)`)
    .run(randomUUID(), '8800001', kullaniciId, JSON.stringify([gecerli, atilmis, bilinmeyen]), simdi(), new Date(Date.now() + 86_400_000).toISOString(), simdi());
  const r = await istek('/api/v1/listings/my');
  assert.equal(r.durum, 200);
  const l = r.json.find((x) => x.ilanNo === '8800001');
  assert.deepEqual(l.photoPaths, [gecerli, atilmis, bilinmeyen], 'referans sözleşmesi değişmemeli');
  assert.equal(l.photoUrls.length, 3);
  assert.match(l.photoUrls[0], /^https:\/\/s3\.example\/kova\/u\/.+X-Amz-Signature=/);
  assert.equal(l.photoUrls[1], null, 'atılmış dosya imzalanmaz');
  assert.equal(l.photoUrls[2], null, 'kayıtsız referans imzalanmaz');
  assert.doesNotMatch(JSON.stringify(r.json), /yalniz-test-gizli/, 'gizli anahtar yanıta sızmaz');
});

test('talep ve mesaj nesneleri: fotograflar → fotografAdresleri, fotografRef → fotografUrl, storageRef → storageUrl', async () => {
  const a = `u/${kullaniciId}/${randomUUID()}.png`;
  const b = `u/${kullaniciId}/${randomUUID()}.webp`;
  await nesne(a); await nesne(b);
  const y = await gorselAdresleriEkle(db, {
    talep: { fotograflar: [a], mesajlar: [{ fotografRef: b }, { fotografRef: null }] },
    sohbet: [{ senderId: 'x', storageRef: b }, { senderId: 'y', storageRef: null }],
    yukleme: { storageRef: a }, // mesaj değil (senderId yok) → dokunulmaz
  });
  assert.match(y.talep.fotografAdresleri[0], /X-Amz-Signature=/);
  assert.match(y.talep.mesajlar[0].fotografUrl, /X-Amz-Signature=/);
  assert.equal('fotografUrl' in y.talep.mesajlar[1], false);
  assert.match(y.sohbet[0].storageUrl, /X-Amz-Signature=/);
  assert.equal('storageUrl' in y.sohbet[1], false);
  assert.equal('storageUrl' in y.yukleme, false);
});

test('depolama yapılandırılmamışsa adres null (sahte adres yok), yanıt bozulmaz', async () => {
  const a = `u/${kullaniciId}/${randomUUID()}.jpg`;
  await nesne(a);
  const eski = {};
  for (const k of Object.keys(S3)) { eski[k] = process.env[k]; delete process.env[k]; }
  try {
    const y = await gorselAdresleriEkle(db, { photoPaths: [a] });
    assert.deepEqual(y, { photoPaths: [a], photoUrls: [null] });
  } finally {
    Object.assign(process.env, eski);
  }
});

test('referans olmayan yanıtlar aynen döner', async () => {
  const x = { id: 1, ad: 'a', liste: [1, 2] };
  assert.deepEqual(await gorselAdresleriEkle(db, x), { id: 1, ad: 'a', liste: [1, 2] });
  assert.equal(await gorselAdresleriEkle(db, 'metin'), 'metin');
});
