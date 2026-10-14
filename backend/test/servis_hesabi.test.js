// Firebase servis hesabı okuyucu (servis_hesabi.js) — ortam değeri ve
// Secret File. ⚠ Anahtarlar test içinde ÜRETİLEN geçici RSA anahtarlarıdır;
// gerçek bir Google hesabına ait değildir, ağ çağrısı yapılmaz.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPairSync } from 'node:crypto';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { servisHesabiOku, servisHesabiCoz } from '../src/servis_hesabi.js';

const PEM = generateKeyPairSync('rsa', { modulusLength: 1024 }).privateKey.export({ type: 'pkcs8', format: 'pem' });
const HESAP = { type: 'service_account', project_id: 'hizmetcep-fe036', client_email: 'x@hizmetcep-fe036.iam.gserviceaccount.com', private_key: PEM };
const JSONU = JSON.stringify(HESAP);
const klasor = mkdtempSync(join(tmpdir(), 'hc-sh-'));
const dosya = (ad, icerik) => { const y = join(klasor, ad); writeFileSync(y, icerik); return y; };

test.after(() => rmSync(klasor, { recursive: true, force: true }));

test('tanımsız → null', () => {
  assert.equal(servisHesabiOku({}), null);
  assert.equal(servisHesabiOku({ HC_FCM_SERVICE_ACCOUNT: '  ', HC_FCM_SERVICE_ACCOUNT_FILE: '' }), null);
});

test('ortam: düz JSON ve base64 JSON okunur', () => {
  assert.equal(servisHesabiOku({ HC_FCM_SERVICE_ACCOUNT: JSONU }).hesap.client_email, HESAP.client_email);
  const b = servisHesabiOku({ HC_FCM_SERVICE_ACCOUNT: Buffer.from(JSONU).toString('base64') });
  assert.equal(b.kaynak, 'ortam');
  assert.equal(b.hesap.project_id, 'hizmetcep-fe036');
});

test('Secret File: dosya yolundan okunur (düz ve base64 içerik, BOM)', () => {
  const r = servisHesabiOku({ HC_FCM_SERVICE_ACCOUNT_FILE: dosya('sa.json', JSONU + '\n') });
  assert.equal(r.kaynak, 'dosya');
  assert.equal(r.hesap.private_key, PEM);
  assert.equal(servisHesabiOku({ HC_FCM_SERVICE_ACCOUNT_FILE: dosya('sa.b64', Buffer.from(JSONU).toString('base64')) }).hesap.project_id, 'hizmetcep-fe036');
  assert.equal(servisHesabiOku({ HC_FCM_SERVICE_ACCOUNT_FILE: dosya('bom.json', '﻿' + JSONU) }).hesap.project_id, 'hizmetcep-fe036');
});

test('ikisi birden verilirse reddedilir (belirsizlik yok)', () => {
  assert.throws(() => servisHesabiOku({ HC_FCM_SERVICE_ACCOUNT: JSONU, HC_FCM_SERVICE_ACCOUNT_FILE: dosya('iki.json', JSONU) }), /birlikte tanımlanamaz/);
});

test('dosya yok / boş → yol ve hata kodu yazılır, içerik yazılmaz', () => {
  assert.throws(() => servisHesabiOku({ HC_FCM_SERVICE_ACCOUNT_FILE: join(klasor, 'yok.json') }), /okunamadı \(.*yok\.json\): ENOENT/);
  assert.throws(() => servisHesabiOku({ HC_FCM_SERVICE_ACCOUNT_FILE: dosya('bos.json', '  \n') }), /boş/);
});

test('içerik değişkenine dosya yolu yazılmışsa açık yönlendirme', () => {
  for (const y of ['/etc/secrets/firebase.json', './sa.json', 'firebase-adminsdk.json']) {
    assert.throws(() => servisHesabiOku({ HC_FCM_SERVICE_ACCOUNT: y }), /dosya yolu gibi görünüyor.*HC_FCM_SERVICE_ACCOUNT_FILE/, y);
  }
});

test('biçim denetimi: bozuk JSON, dizi, yanlış tür, eksik alan, PEM olmayan anahtar', () => {
  assert.throws(() => servisHesabiCoz('{bozuk', 'X'), /geçerli bir servis hesabı JSON/);
  assert.throws(() => servisHesabiCoz('[]', 'X'), /geçerli bir servis hesabı JSON/);
  assert.throws(() => servisHesabiCoz(JSON.stringify({ ...HESAP, type: 'authorized_user' }), 'X'), /type=service_account/);
  for (const k of ['project_id', 'client_email', 'private_key']) {
    const { [k]: _, ...eksik } = HESAP;
    assert.throws(() => servisHesabiCoz(JSON.stringify(eksik), 'X'), new RegExp(`${k} eksik`));
  }
  assert.throws(() => servisHesabiCoz(JSON.stringify({ ...HESAP, private_key: 'abc' }), 'X'), /PEM/);
  // google-services.json (istemci dosyası) yanlışlıkla verilirse de reddedilir.
  assert.throws(() => servisHesabiCoz(JSON.stringify({ project_info: { project_id: 'p' }, client: [] }), 'X'), /eksik/);
});

test('hiçbir hata mesajı anahtar içeriği taşımaz', () => {
  const durumlar = [
    () => servisHesabiCoz(JSON.stringify({ ...HESAP, client_email: '' }), 'X'),
    () => servisHesabiCoz(JSON.stringify({ ...HESAP, type: 'baska' }), 'X'),
    () => servisHesabiOku({ HC_FCM_SERVICE_ACCOUNT: JSONU, HC_FCM_SERVICE_ACCOUNT_FILE: '/x' }),
  ];
  for (const f of durumlar) {
    try { f(); assert.fail('hata bekleniyordu'); } catch (e) {
      assert.doesNotMatch(e.message, /PRIVATE KEY|MII/);
    }
  }
});
