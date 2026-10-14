// Üretim yapılandırma denetimi: eksik/yanlış değer açılışta açıkça reddedilir.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { generateKeyPairSync } from 'node:crypto';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const FCM_PEM = generateKeyPairSync('rsa', { modulusLength: 1024 }).privateKey.export({ type: 'pkcs8', format: 'pem' });
const FCM_HESAP = (proje = 'hizmetcep-fe036') => JSON.stringify({ project_id: proje, client_email: `x@${proje}.iam.gserviceaccount.com`, private_key: FCM_PEM });
const URETIM = {
  HC_FCM_SERVICE_ACCOUNT: FCM_HESAP(),
  NODE_ENV: 'production', HC_DB_DRIVER: 'postgres', HC_DATABASE_URL: 'postgres://k:p@db.example/hc?sslmode=require',
  HC_JWT_SECRET: 'x'.repeat(40), HC_MASTER_KEY: Buffer.alloc(32, 7).toString('base64'),
  HC_SMS_PROVIDER: 'webhook', HC_SMS_WEBHOOK_URL: 'https://sms.example/x', HC_SMS_WEBHOOK_TOKEN: 't',
  HC_EMAIL_PROVIDER: 'webhook', HC_EMAIL_WEBHOOK_URL: 'https://mail.example/x', HC_EMAIL_WEBHOOK_TOKEN: 't',
};
function ac(ek) {
  const r = spawnSync(process.execPath, ['--input-type=module', '-e', "await import('./src/config.js'); console.log('ACILDI')"],
    { cwd: new URL('..', import.meta.url).pathname, env: { PATH: process.env.PATH, ...URETIM, ...ek }, encoding: 'utf8' });
  return (r.stdout + r.stderr);
}

test('tam üretim yapılandırması açılır', () => { assert.match(ac({}), /ACILDI/); });

test('kritik eksikler açıkça reddedilir', () => {
  assert.match(ac({ HC_DATABASE_URL: '' }), /HC_DATABASE_URL zorunludur/);
  assert.match(ac({ HC_JWT_SECRET: '' }), /HC_JWT_SECRET zorunludur/);
  assert.match(ac({ HC_JWT_SECRET: 'kisa' }), /en az 32/);
  assert.match(ac({ HC_MASTER_KEY: '' }), /HC_MASTER_KEY zorunludur/);
  assert.match(ac({ HC_DB_DRIVER: 'sqlite' }), /yalnız PostgreSQL/);
  assert.match(ac({ HC_SMS_PROVIDER: 'log' }), /log kullanılamaz/);
  assert.match(ac({ HC_TEST_OTP_KANCASI: '1' }), /HC_TEST_OTP_KANCASI/);
});

test('CORS: joker, yol ve http üretimde reddedilir', () => {
  assert.match(ac({ HC_CORS_ORIGINS: '*' }), /joker/);
  assert.match(ac({ HC_CORS_ORIGINS: 'https://hizmetcep.com/' }), /yalnız köken/);
  assert.match(ac({ HC_CORS_ORIGINS: 'http://hizmetcep.com' }), /https olmalı/);
});

test('depolama: yarım ya da http yapılandırma reddedilir', () => {
  assert.match(ac({ HC_S3_ENDPOINT: 'https://s3.example', HC_S3_BUCKET: 'b' }), /yarım: HC_S3_ACCESS_KEY_ID, HC_S3_SECRET_ACCESS_KEY eksik/);
  assert.match(ac({ HC_S3_ENDPOINT: 'http://s3.example', HC_S3_BUCKET: 'b', HC_S3_ACCESS_KEY_ID: 'a', HC_S3_SECRET_ACCESS_KEY: 's' }), /https olmalıdır/);
  assert.match(ac({ HC_S3_PATH_STYLE: 'evet' }), /true ya da false/);
  assert.match(ac({ HC_S3_ENDPOINT: 'https://s3.example', HC_S3_BUCKET: 'b', HC_S3_ACCESS_KEY_ID: 'a', HC_S3_SECRET_ACCESS_KEY: 's' }), /ACILDI/);
});

test('FCM servis hesabı: bozuk değer reddedilir, geçerli değer kabul edilir, içerik yazdırılmaz', () => {
  assert.match(ac({ HC_FCM_SERVICE_ACCOUNT: '{bozuk' }), /servis hesabı JSON/);
  assert.match(ac({ HC_FCM_SERVICE_ACCOUNT: JSON.stringify({ project_id: 'p' }) }), /client_email eksik/);
  const cikti = ac({ HC_FCM_SERVICE_ACCOUNT: Buffer.from(FCM_HESAP()).toString('base64') });
  assert.match(cikti, /ACILDI/);
  assert.doesNotMatch(cikti, /PRIVATE KEY/);
});

test('FCM servis hesabı üretimde ZORUNLU ve Firebase projesiyle aynı olmalı', () => {
  assert.match(ac({ HC_FCM_SERVICE_ACCOUNT: '' }), /HC_FCM_SERVICE_ACCOUNT zorunludur/);
  const yanlis = ac({ HC_FCM_SERVICE_ACCOUNT: FCM_HESAP('baska-proje') });
  assert.match(yanlis, /Firebase projesiyle/);
  assert.doesNotMatch(yanlis, /PRIVATE KEY/);
  assert.match(ac({ HC_FCM_SERVICE_ACCOUNT: FCM_HESAP('ozel-proje'), HC_FIREBASE_PROJECT_ID: 'ozel-proje' }), /ACILDI/);
});

test('proxy hop sayısı: varsayılan yok, 0–5 kabul, geçersiz değer ve eski HC_TRUST_PROXY reddedilir', () => {
  const hop = (ek) => {
    const r = spawnSync(process.execPath, ['--input-type=module', '-e', "const { config } = await import('./src/config.js'); console.log('HOP=' + config.guvenilirProxySayisi)"],
      { cwd: new URL('..', import.meta.url).pathname, env: { PATH: process.env.PATH, ...URETIM, ...ek }, encoding: 'utf8' });
    return r.stdout + r.stderr;
  };
  // Üretimde değer verilmemişse proxy'ye GÜVENİLMEZ (tahmini varsayılan yok).
  assert.match(hop({}), /HOP=0/);
  for (const d of ['0', '1', '2', '5']) assert.match(hop({ HC_TRUST_PROXY_HOPS: d }), new RegExp(`HOP=${d}`));
  for (const d of ['6', '-1', 'abc', '1.5', '01x']) assert.match(hop({ HC_TRUST_PROXY_HOPS: d }), /HC_TRUST_PROXY_HOPS 0 ile 5/, d);
  // Eski ayar EN SOLDAKİ (sahte olabilen) değeri alıyordu: sessizce yorumlanmaz.
  for (const d of ['true', 'false', '']) assert.match(hop({ HC_TRUST_PROXY: d }), /HC_TRUST_PROXY artık kullanılmıyor.*HC_TRUST_PROXY_HOPS/, d);
  // Geliştirmede de aynı kural (ortamdan bağımsız).
  assert.match(hop({ NODE_ENV: 'development', HC_DB_DRIVER: 'sqlite', HC_TRUST_PROXY: 'true' }), /HC_TRUST_PROXY artık kullanılmıyor/);
});

test('SSRF korumasını kapatan geliştirme anahtarı üretimde reddedilir', () => {
  assert.match(ac({ HC_INTEGRATION_ALLOW_PRIVATE: 'true' }), /HC_INTEGRATION_ALLOW_PRIVATE/);
});

// ── Render hataları (kök neden) ─────────────────────────────────
// 1) "HC_FCM_SERVICE_ACCOUNT zorunludur": Render'da servis hesabı Secret
//    File olarak eklenmişti; kod yalnız ortam DEĞERİNİ okuyordu. Artık
//    HC_FCM_SERVICE_ACCOUNT_FILE ile dosya yolu desteklenir.
test('FCM Secret File (HC_FCM_SERVICE_ACCOUNT_FILE) üretimde kabul edilir; eksik dosya açıkça reddedilir', () => {
  const k = mkdtempSync(join(tmpdir(), 'hc-yap-'));
  const yol = join(k, 'firebase-servis-hesabi.json');
  writeFileSync(yol, FCM_HESAP());
  const ok = ac({ HC_FCM_SERVICE_ACCOUNT: '', HC_FCM_SERVICE_ACCOUNT_FILE: yol });
  assert.match(ok, /ACILDI/);
  assert.doesNotMatch(ok, /PRIVATE KEY/);
  assert.match(ac({ HC_FCM_SERVICE_ACCOUNT: '', HC_FCM_SERVICE_ACCOUNT_FILE: join(k, 'yok.json') }), /HC_FCM_SERVICE_ACCOUNT_FILE okunamadı.*ENOENT/);
  assert.match(ac({ HC_FCM_SERVICE_ACCOUNT_FILE: yol }), /birlikte tanımlanamaz/);
  assert.match(ac({ HC_FCM_SERVICE_ACCOUNT: '/etc/secrets/firebase.json' }), /HC_FCM_SERVICE_ACCOUNT_FILE kullanın/);
  // İkisi de yoksa üretimde hâlâ ZORUNLU (push ürünün parçası) ve mesaj iki yolu da söyler.
  const yok = ac({ HC_FCM_SERVICE_ACCOUNT: '' });
  assert.match(yok, /HC_FCM_SERVICE_ACCOUNT zorunludur/);
  assert.match(yok, /HC_FCM_SERVICE_ACCOUNT_FILE/);
  // Proje eşleşmesi dosya yolunda da denetlenir.
  const yanlis = join(k, 'baska.json');
  writeFileSync(yanlis, FCM_HESAP('baska-proje'));
  assert.match(ac({ HC_FCM_SERVICE_ACCOUNT: '', HC_FCM_SERVICE_ACCOUNT_FILE: yanlis }), /Firebase projesiyle/);
});

// 2) "HC_SMS_PROVIDER log ya da webhook olmalıdır": üretimde değişken
//    TANIMSIZ bırakıldığında boş değer "geçersiz" sayılıyordu; oysa admin
//    panelindeki entegrasyon da gönderim yoludur (DEPLOY.md). Tanımsız artık
//    izinli (gönderimler admin entegrasyonuna gider, yoksa FAILED + OTP 503);
//    log hâlâ YASAK, geçersiz değer hâlâ REDDEDİLİR.
test('SMS/e-posta sağlayıcısı üretimde tanımsız bırakılabilir; log ve geçersiz değer reddedilir', () => {
  const r = ac({ HC_SMS_PROVIDER: '', HC_SMS_WEBHOOK_URL: '', HC_SMS_WEBHOOK_TOKEN: '', HC_EMAIL_PROVIDER: '', HC_EMAIL_WEBHOOK_URL: '', HC_EMAIL_WEBHOOK_TOKEN: '' });
  assert.match(r, /ACILDI/);
  assert.match(ac({ HC_SMS_PROVIDER: 'log' }), /log kullanılamaz/);
  assert.match(ac({ HC_EMAIL_PROVIDER: 'log' }), /log kullanılamaz/);
  assert.match(ac({ HC_SMS_PROVIDER: 'twilio' }), /HC_SMS_PROVIDER geçersiz \("twilio"\)/);
  assert.match(ac({ HC_SMS_PROVIDER: 'webhook', HC_SMS_WEBHOOK_URL: '' }), /HC_SMS_WEBHOOK_URL zorunludur/);
  assert.match(ac({ HC_SMS_PROVIDER: 'webhook', HC_SMS_WEBHOOK_URL: 'http://sms.example/x' }), /https olmalıdır/);
  assert.match(ac({ HC_SMS_PROVIDER: 'webhook', HC_SMS_WEBHOOK_TOKEN: '' }), /HC_SMS_WEBHOOK_TOKEN zorunludur/);
});
