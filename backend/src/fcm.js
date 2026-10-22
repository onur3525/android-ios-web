// ═══════════════════════════════════════════════════════════════
// FCM SUNUCU GÖNDERİMİ (HTTP v1) — mevcut push_tokens + notifications
//
// Kimlik: Firebase SERVİS HESABI yalnız sunucu ortamından okunur (biri):
//   HC_FCM_SERVICE_ACCOUNT       — servis hesabı JSON'u (düz ya da base64)
//   HC_FCM_SERVICE_ACCOUNT_FILE  — JSON dosya yolu (Render Secret File)
// Koda, Git'e ve Flutter'a GİRMEZ. Tanımlı değilse gönderim kapalıdır;
// uygulama içi bildirimler aynen çalışır.
//
// Akış: uygulamaIciBildir → notifications satırı (push_status NULL) →
// `push_gonderimi` işi (mevcut kilitli iş altyapısı; ayrıca kayıttan hemen
// sonra tetiklenir) → satır SENDING olarak SAHİPLENİR (tek örnek gönderir)
// → kullanıcının bütün cihazlarına gönderilir.
//   · UNREGISTERED / geçersiz jeton  → jeton KALICI silinir
//     (INVALID_ARGUMENT yalnız `message.token` alan ihlaliyse)
//   · 401 / 429 / 5xx / ağ hatası    → jeton KORUNUR, sonra yeniden denenir
//   · Hesap ACTIVE değilse (askı/ban/silinmiş) push gönderilmez (SKIPPED)
//   · Push hatası ana işlemi ASLA başarısız etmez (bildirim zaten yazıldı).
//   · Günlüğe jeton, servis hesabı ya da erişim anahtarı YAZILMAZ.
// Veri biçimi Flutter `push_kapisi.dart` ile aynı: data = {type, hedef, id}.
// ═══════════════════════════════════════════════════════════════
import { config } from './config.js';
import { simdi } from './db.js';
import { googleErisimJetonu, googleErisimJetonunuAt, ortamServisHesabi } from './servis_hesabi.js';

const KAPSAM = 'https://www.googleapis.com/auth/firebase.messaging';
const AZAMI_DENEME = 5;
const SAHIPLIK_ZAMAN_ASIMI = 5 * 60 * 1000;
const GERI_DENEME_ARALIGI = 60 * 1000;
const TUR_BOYU = 500;
const ESZAMANLI = 10; // tek turda aynı anda işlenen bildirim (FCM HTTP çağrıları paralel)

// Okuma/doğrulama config.js ile AYNI kaynaktan (servis_hesabi.js); ortam
// değeri ya da Secret File. Dosya her çağrıda yeniden okunmasın diye
// kaynak anahtarına göre önbelleğe alınır (değişken değişirse yenilenir).
// Servis hesabı ve erişim anahtarı ortak (servis_hesabi.js): FCM ve Firebase
// kimlik yönetimi aynı hesabı kullanır.
const servisHesabi = ortamServisHesabi;
const erisimJetonu = (sh) => googleErisimJetonu(sh, KAPSAM);

/** Tek jetona gönderir → 'ok' | 'gecersiz' | 'gecici'. */
export async function fcmGonder(sh, jeton, mesaj) {
  let r;
  try {
    r = await fetch(`https://fcm.googleapis.com/v1/projects/${sh.project_id}/messages:send`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${await erisimJetonu(sh)}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: { token: jeton, ...mesaj } }),
      signal: AbortSignal.timeout(10000),
    });
  } catch {
    return 'gecici';
  }
  if (r.ok) return 'ok';
  let j = null;
  try { j = await r.json(); } catch { /* yok */ }
  return fcmHataSinifi(r.status, j);
}

/**
 * FCM HTTP v1 hata yanıtı → 'gecersiz' (jeton kalıcı silinir) | 'gecici'.
 *
 * ⚠ INVALID_ARGUMENT TEK BAŞINA jetonun bozuk olduğunu GÖSTERMEZ: mesaj
 * gövdesindeki bir hata da aynı kodu verir. Böyle bir durumda jetonu
 * silmek, kullanıcının BÜTÜN cihaz kayıtlarını yok ederdi. Bu yüzden
 * INVALID_ARGUMENT yalnız alan ihlali `message.token` ise geçersiz sayılır.
 * 401 (erişim anahtarı reddedildi) jetonla ilgili değildir → geçici; ayrıca
 * önbellekteki erişim anahtarı atılır.
 */
export function fcmHataSinifi(durum, j) {
  const detaylar = Array.isArray(j?.error?.details) ? j.error.details : [];
  const kod = detaylar.map((d) => d?.errorCode).find(Boolean) ?? j?.error?.status ?? '';
  const jetonAlani = detaylar.some((d) => Array.isArray(d?.fieldViolations)
    && d.fieldViolations.some((v) => v?.field === 'message.token'));
  if (durum === 401) { googleErisimJetonunuAt(KAPSAM); return 'gecici'; }
  if (durum === 404 || kod === 'UNREGISTERED') return 'gecersiz';
  if (kod === 'SENDER_ID_MISMATCH' && (durum === 400 || durum === 403)) return 'gecersiz';
  if (durum === 400 && kod === 'INVALID_ARGUMENT' && jetonAlani) return 'gecersiz';
  return 'gecici';
}

/** FCM mesaj gövdesi (jeton hariç). Flutter `pushRotasi` biçimiyle aynı. */
export function mesajGovdesi(n) {
  const data = { type: String(n.type), bildirimId: String(n.id) };
  if (n.push_target && n.ref_id) { data.hedef = n.push_target; data.id = String(n.ref_id); }
  return {
    notification: { title: n.title, body: n.body },
    data,
    // 16 Eki: durum çubuğunda ve bildirim başlığında beyaz kare yerine
    // HizmetCep logosu (tek renk, `res/drawable-*/ic_stat_hizmetcep.png`;
    // manifestte de varsayılan). Renk marka mavisi (`hc_blue`).
    android: { priority: 'HIGH', notification: { icon: 'ic_stat_hizmetcep', color: '#1D6BE3' } },
    apns: { payload: { aps: { sound: 'default' } } },
  };
}

let testGondericisi = null;
/** Yalnız testler: sahte gönderici ({ gonder(jeton, mesaj) → 'ok'|'gecersiz'|'gecici' }). */
export function fcmTestGondericisi(g) { testGondericisi = g; }

export function fcmEtkin() {
  if (testGondericisi) return true;
  try { return !!servisHesabi(); } catch { return false; }
}

/** Arka plan işi: bekleyen bildirimleri gönderir. Çok örnekte güvenli (satır sahiplenme). */
/**
 * Kullanıcının bildirim tercihi bu türde push'a izin veriyor mu?
 * Hesap Ayarları'ndaki üç anahtarla eşleşir: "Yeni teklifler" (teklif ve
 * seçim), "Mesajlar" (mesaj ve iletişim açılması), "Duyurular". Bu üçüne
 * girmeyen hizmet bildirimleri (ör. ilan süresinin dolması) her zaman gider.
 */
export function pushIzniVar(u, tur) {
  // TALEP_* = Bul akışı (Doğrudan Teklif İste); aynı üç anahtara bağlıdır.
  // NEW_LISTING: hizmet verene yeni iş ilanı (15 Eki) — "Yeni teklifler" anahtarı.
  // TALEP_DECLINED (22 Eki): hizmet veren talebi reddetti — hizmet alana.
  if (['NEW_OFFER', 'OFFER_SELECTED', 'TALEP_REQUEST', 'TALEP_OFFER', 'TALEP_ACCEPTED', 'TALEP_DECLINED', 'NEW_LISTING'].includes(tur)) return u.notif_offer !== 0;
  if (['NEW_MESSAGE', 'CONTACT_OPENED', 'TALEP_MESSAGE'].includes(tur)) return u.notif_message !== 0;
  if (tur === 'ANNOUNCEMENT') return u.notif_announcement !== 0;
  return true;
}

/**
 * ── ÇOK İŞÇİ (yatay ölçek) ──
 * Bildirim sahiplenmesi koşullu UPDATE ile yapıldığı için aynı kuyruğu
 * birden çok işçi GÜVENLE tüketir (aynı bildirim iki kez gönderilmez —
 * test/fcm.test.js "çok işçi"). Eşzamanlı çalıştırıcı sayısını belirleyen
 * TEK şey danışma kilitleridir: HC_PUSH_PARALEL=N (varsayılan 1) ile N
 * ayrı kilit yuvası açılır; her örnek boş yuvayı alır. Her yuva adayları
 * farklı noktadan işlemeye başlar (aynı satırlar için boşuna yarışmaz).
 * Bir tur dolu geldiyse (kuyrukta iş var) süre bütçesi içinde sürer;
 * önceden dakikada en çok 1 tur (500 bildirim) işleniyordu.
 */
export async function pushKuyrugunuIsle(db, { sureMs = 45_000 } = {}) {
  const n = Math.max(1, Math.min(32, config.pushParalel ?? 1));
  const bas = Math.floor(Math.random() * n);
  for (let i = 0; i < n; i++) {
    const yuva = (bas + i) % n;
    const ad = n === 1 ? 'is:push_gonderimi' : `is:push_gonderimi:${yuva}`;
    const r = await db.isKilidi(ad, async () => {
      const bitis = Date.now() + sureMs;
      let toplam = 0;
      for (;;) {
        const t = await pushTuru(db, { yuva, yuvaSayisi: n });
        toplam += t.gonderilen;
        if (t.aday < TUR_BOYU || Date.now() > bitis) return toplam;
      }
    });
    if (r !== null) return r;
  }
  return null; // bütün yuvalar başka örneklerde meşgul
}

// ── KAYIT ANINDA TETİKLENEN PUSH İŞLERİ ──
// Bildirim kaydı (uygulamaIciBildir) commit'ten sonra kuyruğu bekletmeden
// işletir; ana işlem sonucu beklemez. İşler burada izlenir ki testler
// "biraz bekle" (sabit süre) yerine işin GERÇEKTEN bittiğini bekleyebilsin:
// PostgreSQL'de iş 50 ms'yi aşınca testin kendi turuyla yarışıp
// kararsız sonuç veriyordu (CI'da ara sıra kırmızı).
const tetiklenenIsler = new Set();

/** Kuyruğu arka planda işletir (hatası ana işlemi etkilemez). */
export function pushTetikle(db) {
  const is = pushKuyrugunuIsle(db, { sureMs: 5_000 }).catch(() => {}).finally(() => tetiklenenIsler.delete(is));
  tetiklenenIsler.add(is);
}

/**
 * Yalnız testler: commit sonrası sıraya alınmış ve çalışan bütün tetik
 * işleri bitene dek bekler (sabit süre beklemenin yerine).
 */
export async function tetiklenenPushIsleriniBekle() {
  // commitSonrasi işi setImmediate ile başlatır: önce o sıranın boşalması.
  await new Promise((ok) => setImmediate(ok));
  while (tetiklenenIsler.size) {
    await Promise.all([...tetiklenenIsler]);
    await new Promise((ok) => setImmediate(ok));
  }
}

/** Tek tur — gönderilen sayısı (testler ve eski çağrılar için). */
export async function pushGonderiminiIsle(db) {
  return (await pushTuru(db)).gonderilen;
}

async function pushTuru(db, { yuva = 0, yuvaSayisi = 1 } = {}) {
  let gonder;
  if (testGondericisi) {
    gonder = (t, m) => testGondericisi.gonder(t, m);
  } else {
    let sh = null;
    try { sh = servisHesabi(); } catch (e) { console.error('fcm: servis hesabı okunamadı:', e.message); }
    if (!sh) {
      // Push yapılandırılmamış: bekleyenler gönderilmeyecek olarak kapanır.
      await db.prepare(`UPDATE notifications SET push_status = 'SKIPPED' WHERE push_status IS NULL`).run();
      return { aday: 0, gonderilen: 0 };
    }
    gonder = (t, m) => fcmGonder(sh, t, m);
  }
  const sinir = new Date(Date.now() - SAHIPLIK_ZAMAN_ASIMI).toISOString();
  // Geçici hatadan sonra bekleme: satır push_status NULL'a döner ama
  // push_claimed_at "son deneme" zamanını tutar; GERI_DENEME_ARALIGI dolmadan
  // yeniden alınmaz. FCM kısa süre kesildiğinde 5 deneme saniyeler içinde
  // tükenip bildirim kalıcı FAILED olmasın diye.
  const geriDeneme = new Date(Date.now() - GERI_DENEME_ARALIGI).toISOString();
  const adaylar = await db.prepare(
    `SELECT * FROM notifications
      WHERE (push_status IS NULL AND (push_claimed_at IS NULL OR push_claimed_at < ?))
         OR (push_status = 'SENDING' AND push_claimed_at < ?)
      ORDER BY created_at LIMIT ${TUR_BOYU}`,
  ).all(geriDeneme, sinir);
  let gonderilen = 0;
  // Sınırlı EŞZAMANLILIK: her bildirim kendi satırını koşullu UPDATE ile
  // SAHİPLENİR, bu yüzden paralel işlemek (ya da birden çok işçi) aynı
  // bildirimi iki kez göndermez. Önceden tamamen sıralıydı.
  // Çok yuvada her yuva listeye farklı noktadan başlar.
  const kaydir = adaylar.length ? Math.floor((yuva * adaylar.length) / yuvaSayisi) : 0;
  const sirali = adaylar.slice(kaydir).concat(adaylar.slice(0, kaydir));
  let sira = 0;
  const isci = async () => {
    while (sira < sirali.length) {
      const n = sirali[sira++];
      try {
        // ⚠ `x += await f()` x'i await'ten ÖNCE okur: eşzamanlı işçilerde
        // artışlar kaybolurdu. Önce sonuç alınır, sonra eklenir.
        const r = await birBildirimiIsle(db, n, gonder, sinir, geriDeneme);
        gonderilen += r;
      } catch (e) {
        console.error('fcm: bildirim işlenemedi', n.id, e?.message);
      }
    }
  };
  await Promise.all(Array.from({ length: Math.min(ESZAMANLI, adaylar.length) }, isci));
  return { aday: adaylar.length, gonderilen };
}

/** Tek bildirim: sahiplen → izin/jeton denetimi → gönder → durum yaz. Gönderilen sayısı (0/1). */
async function birBildirimiIsle(db, n, gonder, sinir, geriDeneme) {
  {
    const al = await db.prepare(
      `UPDATE notifications SET push_status = 'SENDING', push_claimed_at = ?
        WHERE id = ? AND ((push_status IS NULL AND (push_claimed_at IS NULL OR push_claimed_at < ?))
                       OR (push_status = 'SENDING' AND push_claimed_at < ?))`,
    ).run(simdi(), n.id, geriDeneme, sinir);
    if (al.changes !== 1) return 0; // başka örnek/işçi sahiplendi
    // Hesap silinmiş, askıya alınmış ya da banlıysa cihaza push GİTMEZ
    // (uygulama içi kayıt aynen durur).
    const sahip = await db.prepare('SELECT status, deleted_at, frozen_at, notif_offer, notif_message, notif_announcement FROM users WHERE id = ?').get(n.user_id);
    if (!sahip || sahip.deleted_at || sahip.frozen_at || sahip.status !== 'ACTIVE' || !pushIzniVar(sahip, n.type)) {
      await db.prepare(`UPDATE notifications SET push_status = 'SKIPPED' WHERE id = ?`).run(n.id);
      return 0;
    }
    // Yalnız bildirimin SAHİBİNE ait jetonlar.
    const jetonlar = await db.prepare('SELECT token FROM push_tokens WHERE user_id = ?').all(n.user_id);
    if (!jetonlar.length) {
      await db.prepare(`UPDATE notifications SET push_status = 'NO_TOKEN' WHERE id = ?`).run(n.id);
      return 0;
    }
    const mesaj = mesajGovdesi(n);
    let basarili = 0; let gecici = 0;
    for (const { token } of jetonlar) {
      let s = 'gecici';
      try { s = await gonder(token, mesaj); } catch { s = 'gecici'; }
      if (s === 'ok') basarili++;
      else if (s === 'gecersiz') await db.prepare('DELETE FROM push_tokens WHERE token = ? AND user_id = ?').run(token, n.user_id);
      else gecici++;
    }
    if (basarili > 0 || gecici === 0) {
      await db.prepare(`UPDATE notifications SET push_status = ? WHERE id = ?`).run(basarili > 0 ? 'SENT' : 'NO_TOKEN', n.id);
      return basarili > 0 ? 1 : 0;
    }
    const deneme = (n.push_attempts ?? 0) + 1;
    // push_claimed_at = şimdi → GERI_DENEME_ARALIGI dolmadan yeniden alınmaz.
    await db.prepare(`UPDATE notifications SET push_status = ?, push_attempts = ?, push_claimed_at = ? WHERE id = ?`)
      .run(deneme >= AZAMI_DENEME ? 'FAILED' : null, deneme, simdi(), n.id);
    if (deneme >= AZAMI_DENEME) console.error(`fcm: bildirim ${n.id} ${deneme} denemede gönderilemedi`);
    return 0;
  }
}
