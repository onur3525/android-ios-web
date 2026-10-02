// ═══════════════════════════════════════════════════════════════
// BİLDİRİM (SMS / E-POSTA) — sağlayıcıdan bağımsız, kayıtlı gönderim
//
// Her gönderim önce `outbound_messages`'a PENDING olarak yazılır, sonra
// sağlayıcıya iletilir ve sonuç (SENT / FAILED + sağlayıcı yanıtı)
// aynı kayda işlenir. Admin paneli bu kayıtları gösterir.
//
// ⚠ Gönderim YALNIZ doğrulanmış kanala yapılır (telefon doğrulanmış /
// e-posta doğrulanmış). Doğrulanmamış kanal için kayıt FAILED +
// "doğrulanmış kanal yok" olarak düşülür; sessizce atlanmaz.
// ⚠ OTP kodu kayda ASLA düz yazılmaz (gövde maskelenir).
// ⚠ Sağlayıcı anahtarları yalnız sunucuda (ortam/şifreli kasa).
// ═══════════════════════════════════════════════════════════════
import { randomUUID } from 'node:crypto';
import { config, uretim } from './config.js';
import { simdi } from './db.js';
import { etkinEntegrasyon } from './entegrasyon.js';

/** Şablonlar: {NEDEN}, {ILAN}, {DESTEK}, {KOD} yer tutucuları. */
export const SABLONLAR = {
  OTP: { sms: 'HizmetCep doğrulama kodunuz: {KOD}. Kodu kimseyle paylaşmayın.' },
  HESAP_ASKIYA_ALINDI: {
    sms: 'Merhaba, hesabınız HizmetCep yönetimi tarafından askıya alınmıştır. İşlem nedeni: {NEDEN} Detaylı bilgi için: {DESTEK}',
    konu: 'Hesabınız askıya alındı',
  },
  HESAP_ASKI_KALDIRILDI: {
    sms: 'Merhaba, HizmetCep hesabınızın askıya alınması kaldırılmıştır. Detaylı bilgi için: {DESTEK}',
    konu: 'Hesabınız yeniden etkin',
  },
  HESAP_BANLANDI: {
    sms: 'Merhaba, hesabınız HizmetCep yönetimi tarafından kalıcı olarak kapatılmıştır. İşlem nedeni: {NEDEN} Detaylı bilgi için: {DESTEK}',
    konu: 'Hesabınız kapatıldı',
  },
  HESAP_BAN_KALDIRILDI: {
    sms: 'Merhaba, HizmetCep hesabınız üzerindeki kapatma işlemi kaldırılmıştır. Detaylı bilgi için: {DESTEK}',
    konu: 'Hesabınız yeniden açıldı',
  },
  ILAN_KALDIRILDI: {
    sms: 'Merhaba, "{ILAN}" ilanınız HizmetCep yönetimi tarafından kaldırılmıştır. İşlem nedeni: {NEDEN} Detaylı bilgi için: {DESTEK}',
    konu: 'İlanınız kaldırıldı',
  },
};

function doldur(metin, degerler) {
  return metin.replace(/\{(\w+)\}/g, (_, k) => (degerler[k] ?? ''));
}

async function saglayiciyaGonder(db, kanal, hedef, konu, govde) {
  // Admin panelinden etkinleştirilmiş entegrasyon ÖNCELİKLİ; yoksa ortam.
  const e = await etkinEntegrasyon(db, kanal === 'SMS' ? 'SMS' : 'EMAIL');
  const s = e ? { ad: 'webhook', url: e.config.url, anahtar: e.secret.token } : (kanal === 'SMS' ? config.sms : config.eposta);
  if (s.ad === 'log') {
    if (uretim) throw new Error('Üretimde log sağlayıcısı kullanılamaz');
    if (!process.env.HC_SESSIZ) console.log(`[BİLDİRİM:${kanal}] → ${hedef}: ${govde}`);
    return { saglayici: 'log', yanit: 'yerel kayıt (gönderim yapılmadı)' };
  }
  const r = await fetch(s.url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${s.anahtar}` },
    body: JSON.stringify({ channel: kanal, to: hedef, subject: konu, text: govde }),
    signal: AbortSignal.timeout(10_000),
    redirect: 'error',
  });
  const metin = (await r.text()).slice(0, 500);
  if (!r.ok) throw new Error(`sağlayıcı ${r.status}: ${metin}`);
  return { saglayici: 'webhook', yanit: metin };
}

/**
 * Tek kanala gönderir ve kaydeder. Hiçbir zaman fırlatmaz; sonucu döner.
 * @returns {Promise<{id:string,status:'SENT'|'FAILED'}>}
 */
export async function gonder(db, { kullaniciId, kanal, hedef, sablon, degerler = {}, denetimRef, gizliGovde }) {
  const s = SABLONLAR[sablon];
  const govde = doldur(s.sms, degerler);
  const kayitGovdesi = gizliGovde ? doldur(s.sms, { ...degerler, KOD: '••••••' }) : govde;
  const id = randomUUID();
  await db.prepare(
    `INSERT INTO outbound_messages (id, user_id, channel, target, template, subject, body, status, attempts, audit_ref, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, 'PENDING', 0, ?, ?)`,
  ).run(id, kullaniciId ?? null, kanal, hedef || '-', sablon, s.konu ?? null, kayitGovdesi, denetimRef ?? null, simdi());
  if (!hedef) {
    await db.prepare(`UPDATE outbound_messages SET status = 'FAILED', provider_response = ? WHERE id = ?`)
      .run('doğrulanmış kanal yok', id);
    return { id, status: 'FAILED' };
  }
  const kanalAyar = kanal === 'SMS' ? config.sms : config.eposta;
  if (!kanalAyar || !kanalAyar.ad) {
    await db.prepare(`UPDATE outbound_messages SET status = 'FAILED', provider_response = ?, attempts = 1 WHERE id = ?`)
      .run('kanal sağlayıcısı yapılandırılmamış', id);
    return { id, status: 'FAILED' };
  }
  try {
    const r = await saglayiciyaGonder(db, kanal, hedef, s.konu, govde);
    await db.prepare(`UPDATE outbound_messages SET status = 'SENT', provider = ?, provider_response = ?, attempts = 1, sent_at = ? WHERE id = ?`)
      .run(r.saglayici, r.yanit, simdi(), id);
    return { id, status: 'SENT' };
  } catch (e) {
    await db.prepare(`UPDATE outbound_messages SET status = 'FAILED', provider_response = ?, attempts = 1 WHERE id = ?`)
      .run(String(e.message).slice(0, 500), id);
    return { id, status: 'FAILED' };
  }
}

/** Kullanıcının DOĞRULANMIŞ kanallarına (SMS ve/veya e-posta) gönderir. */
export async function kullaniciyaBildir(db, kullanici, sablon, degerler, denetimRef) {
  const destek = await db.prepare('SELECT email FROM support_info WHERE id = 1').get();
  const tam = { DESTEK: destek?.email ?? '', ...degerler };
  const sonuc = [];
  sonuc.push(await gonder(db, {
    kullaniciId: kullanici.id, kanal: 'SMS', sablon, degerler: tam, denetimRef,
    hedef: kullanici.phone_verified === 1 ? `+90${kullanici.phone}` : null,
  }));
  sonuc.push(await gonder(db, {
    kullaniciId: kullanici.id, kanal: 'EMAIL', sablon, degerler: tam, denetimRef,
    hedef: kullanici.email_verified === 1 && kullanici.email ? kullanici.email : null,
  }));
  return sonuc;
}
