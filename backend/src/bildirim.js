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
import { DESTEK_BILGISI } from './destek_bilgisi.js';
import { config, uretim } from './config.js';
import { simdi } from './db.js';
import { etkinEntegrasyon } from './entegrasyon.js';
import { guvenliIstek } from './ag_guvenligi.js';
import { kurumsalEposta } from './eposta_tasarimi.js';

/**
 * Şablonlar: {NEDEN}, {ILAN}, {DESTEK}, {KOD}, {AD}, {EPOSTA}, {BAGLANTI}
 * yer tutucuları. `sms` düz metindir (SMS ve e-postanın düz metin
 * sürümü). `eposta` verilmişse e-posta o yapıyla, verilmemişse `konu` +
 * `sms` metniyle aynı kurumsal kalıpta (eposta_tasarimi.js) çizilir.
 */
export const SABLONLAR = {
  OTP: { sms: 'HizmetCep doğrulama kodunuz: {KOD}. Kodu kimseyle paylaşmayın.' },
  // ── 22 Eki (KVKK takip denetimi E3): kayıtlı numarayla KAYIT kodu
  // istenince yanıt NÖTR kalır (numaranın kayıtlı olduğu sızmaz); numaranın
  // sahibine kod yerine bu bilgi gider. ──
  KAYITLI_NUMARA: { sms: 'HizmetCep: Bu numarayla kayıtlı bir hesabınız var. Uygulamada "Giriş Yap" ile girebilir ya da "Şifremi Unuttum" ile şifrenizi yenileyebilirsiniz. Bu isteği siz yapmadıysanız dikkate almayın.' },
  // ── 21 Eki: doğrulama e-postaları artık HizmetCep tasarımıyla gider
  // (önceden Firebase'in düz şablonu). Bağlantıyı Firebase üretir. ──
  EPOSTA_DOGRULAMA: {
    konu: 'E-posta adresinizi doğrulayın',
    sms: 'Merhaba {AD},\n\nHizmetCep hesabınızdaki {EPOSTA} adresini doğrulamak için bu bağlantıyı açın:\n{BAGLANTI}\n\nBu isteği siz yapmadıysanız bu e-postayı dikkate almayın.',
    eposta: {
      baslik: 'E-posta adresinizi doğrulayın',
      paragraflar: ['Merhaba {AD},', 'HizmetCep hesabınızdaki {EPOSTA} adresini doğrulamak için aşağıdaki düğmeye dokunun.'],
      buton: { metin: 'E-postamı Doğrula', adres: '{BAGLANTI}' },
      not: 'Bu isteği siz yapmadıysanız bu e-postayı dikkate almayın; hesabınızda herhangi bir değişiklik yapılmaz.',
    },
  },
  // ── 21 Eki (güvenlik Y2): adres değişince ESKİ adrese bilgilendirme ──
  EPOSTA_DEGISTI: {
    konu: 'E-posta adresiniz değiştirildi',
    sms: 'Merhaba {AD},\n\nHizmetCep hesabınızın e-posta adresi {YENI} olarak değiştirildi.\n\nBu değişikliği siz yapmadıysanız uygulamada "Şifremi Unuttum" ile telefon numaranızla şifrenizi hemen yenileyin ve {DESTEK} adresinden bize ulaşın.',
    eposta: {
      baslik: 'E-posta adresiniz değiştirildi',
      paragraflar: ['Merhaba {AD},', 'HizmetCep hesabınızın e-posta adresi {YENI} olarak değiştirildi. Bu adrese artık hesabınızla ilgili e-posta gönderilmeyecek.'],
      not: 'Bu değişikliği siz yapmadıysanız uygulamada "Şifremi Unuttum" ile telefon numaranızla şifrenizi hemen yenileyin ve {DESTEK} adresinden bize ulaşın.',
    },
  },
  EPOSTA_DEGISIKLIGI: {
    konu: 'Yeni e-posta adresinizi doğrulayın',
    sms: 'Merhaba {AD},\n\nHizmetCep hesabınızın e-posta adresini {EPOSTA} olarak değiştirmek için bu bağlantıyı açın:\n{BAGLANTI}\n\nBağlantıyı açana kadar mevcut adresiniz geçerli kalır. Bu isteği siz yapmadıysanız bu e-postayı dikkate almayın.',
    eposta: {
      baslik: 'Yeni e-posta adresinizi doğrulayın',
      paragraflar: ['Merhaba {AD},', 'HizmetCep hesabınızın e-posta adresini {EPOSTA} olarak değiştirmek için aşağıdaki düğmeye dokunun. Bağlantıyı açana kadar mevcut adresiniz geçerli kalır.'],
      buton: { metin: 'Yeni Adresimi Doğrula', adres: '{BAGLANTI}' },
      not: 'Bu isteği siz yapmadıysanız bu e-postayı dikkate almayın; e-posta adresiniz değişmez.',
    },
  },
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
  // Gelen Talepler: admin yanıtı (yalnız e-posta kanalı kullanılır).
  DESTEK_YANITI: {
    sms: 'Merhaba, {NO} numaralı "{KONU}" başlıklı destek talebinize yanıtımız:\n\n{YANIT}\n\nHizmetCep Destek',
    // Konudaki talep numarası, kullanıcının bu e-postaya verdiği yanıtın
    // AYNI talebe eklenmesini sağlar (gelen_eposta.js).
    konu: 'Destek talebiniz yanıtlandı (Talep No: {NO})',
  },
  ILAN_KALDIRILDI: {
    sms: 'Merhaba, "{ILAN}" ilanınız HizmetCep yönetimi tarafından kaldırılmıştır. İşlem nedeni: {NEDEN} Detaylı bilgi için: {DESTEK}',
    konu: 'İlanınız kaldırıldı',
  },
};

function doldur(metin, degerler) {
  return metin.replace(/\{(\w+)\}/g, (_, k) => (degerler[k] ?? ''));
}

/** Şablonun e-posta içeriği (HTML + düz metin), kurumsal kalıpta. */
export function epostaIcerigi(sablon, degerler = {}) {
  const s = SABLONLAR[sablon];
  const e = s.eposta;
  return kurumsalEposta({
    konu: doldur(s.konu ?? 'HizmetCep', degerler),
    baslik: doldur(e?.baslik ?? s.konu ?? 'HizmetCep', degerler),
    paragraflar: e
      ? e.paragraflar.map((p) => doldur(p, degerler))
      : doldur(s.sms, degerler).split(/\n{2,}/).map((p) => p.trim()).filter(Boolean),
    buton: e?.buton ? { metin: e.buton.metin, adres: doldur(e.buton.adres, degerler) } : undefined,
    not: e?.not ? doldur(e.not, degerler) : undefined,
    destek: degerler.DESTEK || undefined,
  });
}

// Resend (https://resend.com) e-posta API'si — admin panelinden "resend"
// sağlayıcısı seçildiğinde kullanılır. Adres SABİTTİR (panelden girilmez).
export const RESEND_ADRESI = 'https://api.resend.com/emails';

/**
 * Kanalın bir gönderim yolu var mı? (admin entegrasyonu etkin YA DA ortam
 * sağlayıcısı tanımlı). Numaradan bağımsızdır; yanıt kayıt bilgisi sızdırmaz.
 */
export async function kanalHazir(db, kanal) {
  if (await etkinEntegrasyon(db, kanal === 'SMS' ? 'SMS' : 'EMAIL')) return true;
  return (kanal === 'SMS' ? config.sms : config.eposta).ad !== 'yok';
}

async function saglayiciyaGonder(db, kanal, hedef, konu, govde, html, yanitAdresi) {
  // Admin panelinden etkinleştirilmiş entegrasyon ÖNCELİKLİ; yoksa ortam.
  const e = await etkinEntegrasyon(db, kanal === 'SMS' ? 'SMS' : 'EMAIL');
  if (e && kanal === 'EMAIL' && e.provider === 'resend') {
    // ⚠ Gönderen adres Resend'de doğrulanmış alan adından olmalıdır
    // (ör. "HizmetCep <bildirim@hizmetcep.com>").
    const r = await guvenliIstek(RESEND_ADRESI, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${e.secret.token}` },
      body: JSON.stringify({ from: e.config.from, to: [hedef], subject: konu, html, text: govde, ...(yanitAdresi ? { reply_to: yanitAdresi } : {}) }),
      timeoutMs: 10_000,
    });
    if (r.status < 200 || r.status > 299) throw new Error(`resend ${r.status}: ${r.text.slice(0, 400)}`);
    return { saglayici: 'resend', yanit: r.text.slice(0, 500) };
  }
  const s = e ? { ad: 'webhook', url: e.config.url, anahtar: e.secret.token } : (kanal === 'SMS' ? config.sms : config.eposta);
  if (s.ad === 'yok') {
    // Üretimde ortam sağlayıcısı tanımsız ve admin entegrasyonu etkin değil.
    throw new Error(`${kanal === 'SMS' ? 'SMS' : 'E-posta'} sağlayıcısı yapılandırılmamış (HC_${kanal === 'SMS' ? 'SMS' : 'EMAIL'}_PROVIDER ya da admin entegrasyonu)`);
  }
  if (s.ad === 'log') {
    if (uretim) throw new Error('Üretimde log sağlayıcısı kullanılamaz');
    if (!process.env.HC_SESSIZ) console.log(`[BİLDİRİM:${kanal}] → ${hedef}: ${govde}`);
    return { saglayici: 'log', yanit: 'yerel kayıt (gönderim yapılmadı)' };
  }
  const istek = {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${s.anahtar}` },
    // `html` yalnız e-postada; köprü desteklemiyorsa `text`i kullanır.
    body: JSON.stringify({ channel: kanal, to: hedef, subject: konu, text: govde, ...(html ? { html } : {}) }),
  };
  let durum; let metin;
  if (e) {
    // Admin panelinden girilen adres: SSRF korumalı istek (iç ağa çözülürse
    // bağlanılmaz, yönlendirme izlenmez).
    const r = await guvenliIstek(s.url, { ...istek, timeoutMs: 10_000 });
    durum = r.status; metin = r.text.slice(0, 500);
  } else {
    // Ortam değişkeninden gelen adres (işletme yapılandırması) — mevcut davranış.
    const r = await fetch(s.url, { ...istek, signal: AbortSignal.timeout(10_000), redirect: 'error' });
    durum = r.status; metin = (await r.text()).slice(0, 500);
  }
  if (durum < 200 || durum > 299) throw new Error(`sağlayıcı ${durum}: ${metin}`);
  return { saglayici: 'webhook', yanit: metin };
}

/**
 * Tek kanala gönderir ve kaydeder. Hiçbir zaman fırlatmaz; sonucu döner.
 * @returns {Promise<{id:string,status:'SENT'|'FAILED'}>}
 */
export async function gonder(db, { kullaniciId, kanal, hedef, sablon, degerler = {}, denetimRef, gizliGovde, yanitAdresi }) {
  const s = SABLONLAR[sablon];
  const konu = s.konu ? doldur(s.konu, degerler) : null;
  let govde = doldur(s.sms, degerler);
  let html;
  if (kanal === 'EMAIL') {
    // Alt bilgideki destek adresi: çağıran vermediyse kayıtlı olan.
    if (!degerler.DESTEK) {
      degerler = { ...degerler, DESTEK: DESTEK_BILGISI.email };
    }
    ({ html, text: govde } = epostaIcerigi(sablon, degerler));
  }
  // ⚠ Kod ve doğrulama bağlantısı kayda ASLA düz yazılmaz.
  const kayitGovdesi = gizliGovde ? doldur(s.sms, { ...degerler, KOD: '••••••', BAGLANTI: '••••••' }) : govde;
  const id = randomUUID();
  await db.prepare(
    `INSERT INTO outbound_messages (id, user_id, channel, target, template, subject, body, status, attempts, audit_ref, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, 'PENDING', 0, ?, ?)`,
  ).run(id, kullaniciId ?? null, kanal, hedef || '-', sablon, konu, kayitGovdesi, denetimRef ?? null, simdi());
  if (!hedef) {
    await db.prepare(`UPDATE outbound_messages SET status = 'FAILED', provider_response = ? WHERE id = ?`)
      .run('doğrulanmış kanal yok', id);
    return { id, status: 'FAILED' };
  }
  try {
    const r = await saglayiciyaGonder(db, kanal, hedef, konu, govde, html, yanitAdresi);
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
//
// ⚠ 23 Eki (işletmeci kararı "A"): SUNUCU SMS'İ YALNIZ YAPILANDIRILMIŞSA.
// Doğrulama kodlarını Firebase gönderir (firebase_kimlik.dart); sunucunun
// SMS'i yalnız yönetici bildirimlerinde kullanılıyordu ve sağlayıcı yokken
// her bildirim "başarısız SMS" kaydı üretiyordu. SMS sağlayıcısı (panel ya
// da sunucu ayarı) yoksa SMS hiç DENENMEZ; bildirim e-postayla gider.
// İleride sağlayıcı tanımlanırsa SMS kendiliğinden yeniden devreye girer.
export async function kullaniciyaBildir(db, kullanici, sablon, degerler, denetimRef) {
  const tam = { DESTEK: DESTEK_BILGISI.email, ...degerler };
  const sonuc = [];
  if (await kanalHazir(db, 'SMS')) {
    sonuc.push({ channel: 'SMS', ...await gonder(db, {
      kullaniciId: kullanici.id, kanal: 'SMS', sablon, degerler: tam, denetimRef,
      hedef: kullanici.phone_verified === 1 ? `+90${kullanici.phone}` : null,
    }) });
  }
  sonuc.push({ channel: 'EMAIL', ...await gonder(db, {
    kullaniciId: kullanici.id, kanal: 'EMAIL', sablon, degerler: tam, denetimRef,
    hedef: kullanici.email_verified === 1 && kullanici.email ? kullanici.email : null,
  }) });
  return sonuc;
}
