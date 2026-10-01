// ═══════════════════════════════════════════════════════════════
// DOSYA DEPOLAMA (/api/v1/storage) + ADMİN ENTEGRASYONLARI
//
// Dosyalar sunucu diskine YAZILMAZ: istemci, sunucunun ürettiği kısa
// ömürlü İMZALI adrese doğrudan nesne depolamaya (S3/R2/MinIO) yükler.
// Bu, backend örneklerini durumsuz tutar (yatay ölçekleme).
// ═══════════════════════════════════════════════════════════════
import { randomUUID } from 'node:crypto';
import { sirSifrele, yenidenDogrulamaIste, yetkiIste } from '../auth.js';
import { denetimYaz } from '../audit.js';
import { depolamaAyari, s3ImzaliAdres } from '../entegrasyon.js';
import { olaylar } from '../olaylar.js';
import { simdi } from '../db.js';
import { ApiHatasi, hata } from '../http.js';
import { kullaniciCoz } from './kullanici.js';

const TURLER = { 'listing-photo': 10 * 1024 * 1024 }; // Flutter'daki tek tür; 10 MB (istemci sınırıyla aynı)
const ICERIK = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp', 'image/heic': 'heic' };

/** Kullanıcının bu dosyayı görmeye yetkisi var mı? */
async function goruntuleyebilir(db, ref, u) {
  const o = await db.prepare('SELECT owner_id, status FROM storage_objects WHERE ref = ?').get(ref);
  if (!o || o.status === 'DISCARDED') return false;
  if (o.owner_id === u.id) return true;
  const kalip = `%"${ref}"%`;
  // İlan fotoğrafı: hizmet verenler açık ilanları ve teklif verdikleri ilanları görür.
  if (u.roles.split(',').includes('PROVIDER') && await db.prepare(
    `SELECT 1 FROM listings l WHERE l.photo_refs_json LIKE ?
       AND ((l.status = 'ACTIVE' AND l.selected_offer_id IS NULL)
            OR EXISTS (SELECT 1 FROM offers o WHERE o.listing_id = l.id AND o.provider_id = ?))`,
  ).get(kalip, u.id)) return true;
  // Sohbet görseli: yalnız sohbetin iki tarafı.
  if (await db.prepare(
    `SELECT 1 FROM messages m JOIN offers o ON o.id = m.offer_id JOIN listings l ON l.id = o.listing_id
      WHERE m.storage_ref = ? AND (o.provider_id = ? OR l.owner_id = ?)`,
  ).get(ref, u.id, u.id)) return true;
  // Teklif talebi fotoğrafı/mesajı: yalnız iki taraf.
  return !!(await db.prepare(
    `SELECT 1 FROM teklif_talepleri t WHERE (t.hizmet_alan_id = ? OR t.saglayici_id = ?)
       AND (t.fotograflar_json LIKE ? OR EXISTS (SELECT 1 FROM teklif_mesajlari m WHERE m.talep_id = t.id AND m.fotograf_ref = ?))`,
  ).get(u.id, u.id, kalip, ref));
}

/** İlan/mesaj oluşturulurken kullanılan dosyalar kullanıcıya ait ve bekleyen olmalı. */
export async function dosyalariBagla(db, refler, kullaniciId) {
  for (const ref of refler) {
    const o = await db.prepare('SELECT * FROM storage_objects WHERE ref = ?').get(ref);
    if (!o || o.owner_id !== kullaniciId || o.status === 'DISCARDED') throw hata.dogrulama('Geçersiz fotoğraf');
    if (o.status === 'PENDING') await db.prepare(`UPDATE storage_objects SET status = 'ATTACHED', attached_at = ? WHERE ref = ?`).run(simdi(), ref);
  }
}

const GIZLI_ALANLAR = { SMS: ['token'], EMAIL: ['token'], STORAGE: ['accessKeyId', 'secretAccessKey'], PUSH: ['serverKey'] };
const SAGLAYICILAR = { SMS: ['webhook'], EMAIL: ['webhook'], STORAGE: ['s3'], PUSH: ['fcm'] };

function entegrasyonGorunumu(x) {
  return {
    id: x.id, type: x.type, provider: x.provider, active: x.active === 1, config: JSON.parse(x.config_json),
    secretSet: !!x.secret_enc, secretHint: x.secret_hint, lastTestAt: x.last_test_at,
    lastTestOk: x.last_test_ok === null ? null : x.last_test_ok === 1, lastTestMessage: x.last_test_message, updatedAt: x.updated_at,
  };
}

function ayarDogrula(tur, config) {
  if (!config || typeof config !== 'object' || Array.isArray(config)) throw hata.dogrulama('Geçersiz ayar');
  const https = (v, ad) => {
    if (typeof v !== 'string' || !v.startsWith('https://')) throw hata.dogrulama(`${ad} https ile başlamalıdır`);
    try { new URL(v); } catch { throw hata.dogrulama(`${ad} geçerli bir adres değil`); }
  };
  if (tur === 'SMS' || tur === 'EMAIL') https(config.url, 'Adres');
  if (tur === 'STORAGE') {
    https(config.endpoint, 'Uç nokta');
    if (!/^[a-z0-9][a-z0-9.-]{2,62}$/.test(String(config.bucket ?? ''))) throw hata.dogrulama('Geçersiz kova adı');
    if (!/^[a-z0-9-]{2,30}$/.test(String(config.region ?? ''))) throw hata.dogrulama('Geçersiz bölge');
  }
  return config;
}

export function depolamaEntegrasyonRotalar(r, db) {
  const korumali = (f) => async (ctx) => {
    const { u } = await kullaniciCoz(db, ctx.req);
    ctx.kullanici = u;
    return f(ctx);
  };

  r.post('/api/v1/storage/upload-ref', korumali(async (ctx) => {
    const tur = String(ctx.body.kind ?? '');
    const icerik = String(ctx.body.contentType ?? '');
    const boyut = ctx.body.sizeBytes;
    if (!TURLER[tur]) throw hata.dogrulama('Geçersiz dosya türü');
    if (!ICERIK[icerik]) throw hata.dogrulama('Yalnız JPEG, PNG, WEBP ya da HEIC yüklenebilir');
    if (!Number.isInteger(boyut) || boyut < 1 || boyut > TURLER[tur]) throw hata.dogrulama('Dosya en fazla 10 MB olabilir');
    // Kullanıcı başına bekleyen dosya sınırı (kötüye kullanım).
    const bekleyen = (await db.prepare(`SELECT COUNT(*) n FROM storage_objects WHERE owner_id = ? AND status = 'PENDING' AND created_at > ?`)
      .get(ctx.kullanici.id, new Date(Date.now() - 86_400_000).toISOString())).n;
    if (bekleyen >= 100) throw hata.hiz('Çok fazla bekleyen yükleme');
    const ayar = await depolamaAyari(db);
    if (!ayar) throw new ApiHatasi(503, 'EXTERNAL_SERVICE_ERROR', 'Dosya yükleme şu anda kullanılamıyor');
    const ref = `u/${ctx.kullanici.id}/${randomUUID()}.${ICERIK[icerik]}`;
    await db.prepare(`INSERT INTO storage_objects (ref, owner_id, kind, content_type, size_bytes, status, created_at) VALUES (?, ?, ?, ?, ?, 'PENDING', ?)`)
      .run(ref, ctx.kullanici.id, tur, icerik, boyut, simdi());
    return { storageRef: ref, uploadUrl: s3ImzaliAdres(ayar, { yontem: 'PUT', anahtar: ref, sureSn: 600, icerikTuru: icerik }) };
  }));

  r.get('/api/v1/storage/resolve', korumali(async (ctx) => {
    const ref = String(ctx.query.get('ref') ?? '');
    if (!(await goruntuleyebilir(db, ref, ctx.kullanici))) throw hata.bulunamadi('Dosya bulunamadı');
    const ayar = await depolamaAyari(db);
    if (!ayar) throw new ApiHatasi(503, 'EXTERNAL_SERVICE_ERROR', 'Dosya şu anda gösterilemiyor');
    return { url: s3ImzaliAdres(ayar, { yontem: 'GET', anahtar: ref, sureSn: 600 }), expiresInSeconds: 600 };
  }));

  r.delete('/api/v1/storage/uploads/pending', korumali(async (ctx) => {
    const ref = String(ctx.body.storageRef ?? '');
    // Nesnenin kendisi kovadaki yaşam döngüsü kuralıyla temizlenir
    // (bekleyen/atılmış önek); burada kayıt atılmış işaretlenir.
    const n = await db.prepare(`UPDATE storage_objects SET status = 'DISCARDED' WHERE ref = ? AND owner_id = ? AND status = 'PENDING'`).run(ref, ctx.kullanici.id);
    return { ok: n.changes === 1, retryScheduled: false };
  }));

  // ═════ ADMİN · ENTEGRASYONLAR ═════
  r.get('/admin/v1/integrations', async (ctx) => {
    yetkiIste(ctx.admin, 'integrations.read');
    return (await db.prepare('SELECT * FROM integrations WHERE deleted_at IS NULL ORDER BY type, created_at').all()).map(entegrasyonGorunumu);
  });

  r.post('/admin/v1/integrations', async (ctx) => {
    yetkiIste(ctx.admin, 'integrations.write');
    const tur = ctx.body.type;
    const saglayici = ctx.body.provider;
    if (!SAGLAYICILAR[tur]?.includes(saglayici)) throw hata.dogrulama('Geçersiz tür ya da sağlayıcı');
    const ayar = ayarDogrula(tur, ctx.body.config);
    const id = randomUUID();
    const z = simdi();
    await db.tx(async () => {
      await db.prepare(`INSERT INTO integrations (id, type, provider, active, config_json, created_at, updated_at) VALUES (?, ?, ?, FALSE, ?, ?, ?)`)
        .run(id, tur, saglayici, JSON.stringify(ayar), z, z);
      await denetimYaz(db, { adminId: ctx.admin.id, ip: ctx.ip, islem: 'integration.create', hedefTur: 'integration', hedefId: id, sonra: { type: tur, provider: saglayici, config: ayar } });
    });
    return entegrasyonGorunumu(await db.prepare('SELECT * FROM integrations WHERE id = ?').get(id));
  });

  const getir = async (id) => {
    const x = await db.prepare('SELECT * FROM integrations WHERE id = ? AND deleted_at IS NULL').get(id);
    if (!x) throw hata.bulunamadi('Entegrasyon bulunamadı');
    return x;
  };

  r.patch('/admin/v1/integrations/:id', async (ctx) => {
    yetkiIste(ctx.admin, 'integrations.write');
    const x = await getir(ctx.params.id);
    const d = {};
    if (ctx.body.config !== undefined) d.config_json = JSON.stringify(ayarDogrula(x.type, ctx.body.config));
    if (ctx.body.active !== undefined) {
      if (typeof ctx.body.active !== 'boolean') throw hata.dogrulama('active true/false olmalıdır');
      if (ctx.body.active && !x.secret_enc) throw hata.durum('Etkinleştirmeden önce gizli anahtarı girin');
      yenidenDogrulamaIste(ctx.oturum);
      d.active = ctx.body.active ? 1 : 0;
    }
    if (!Object.keys(d).length) throw hata.dogrulama('Değişiklik yok');
    await db.tx(async () => {
      // Aynı türde başka etkin varsa önce pasife alınır (tek etkin kuralı).
      if (d.active === 1) await db.prepare('UPDATE integrations SET active = FALSE, updated_at = ? WHERE type = ? AND id <> ? AND active = TRUE').run(simdi(), x.type, x.id);
      const a = Object.keys(d);
      await db.prepare(`UPDATE integrations SET ${a.map((k) => `${k} = ?`).join(', ')}, updated_at = ? WHERE id = ?`).run(...a.map((k) => d[k]), simdi(), x.id);
      await denetimYaz(db, { adminId: ctx.admin.id, ip: ctx.ip, islem: 'integration.update', hedefTur: 'integration', hedefId: x.id, once: { active: x.active === 1, config: JSON.parse(x.config_json) }, sonra: { active: d.active === undefined ? undefined : d.active === 1, config: d.config_json ? JSON.parse(d.config_json) : undefined } });
    });
    await olaylar.yayinla('integrations.changed', {}); // BÜTÜN örneklerde önbellek temizlenir
    return entegrasyonGorunumu(await getir(x.id));
  });

  // Sır yalnız YAZILIR; hiçbir uç düz değeri geri döndürmez.
  r.put('/admin/v1/integrations/:id/secret', async (ctx) => {
    yetkiIste(ctx.admin, 'integrations.secret');
    yenidenDogrulamaIste(ctx.oturum);
    const x = await getir(ctx.params.id);
    const sir = {};
    for (const alan of GIZLI_ALANLAR[x.type]) {
      const v = ctx.body[alan];
      if (typeof v !== 'string' || v.length < 8 || v.length > 4096) throw hata.dogrulama(`${alan} zorunludur (en az 8 karakter)`);
      sir[alan] = v;
    }
    const son = String(sir[GIZLI_ALANLAR[x.type].at(-1)]).slice(-4);
    await db.tx(async () => {
      await db.prepare('UPDATE integrations SET secret_enc = ?, secret_hint = ?, updated_at = ? WHERE id = ?').run(sirSifrele(JSON.stringify(sir)), `••••${son}`, simdi(), x.id);
      await denetimYaz(db, { adminId: ctx.admin.id, ip: ctx.ip, islem: 'integration.secret.set', hedefTur: 'integration', hedefId: x.id, sonra: { hint: `••••${son}` } });
    });
    await olaylar.yayinla('integrations.changed', {}); // BÜTÜN örneklerde önbellek temizlenir
    return entegrasyonGorunumu(await getir(x.id));
  });

  r.post('/admin/v1/integrations/:id/test', async (ctx) => {
    yetkiIste(ctx.admin, 'integrations.write');
    const x = await getir(ctx.params.id);
    let ok = false;
    let mesaj = '';
    try {
      if (!x.secret_enc) throw new Error('Gizli anahtar girilmemiş');
      const cfg = JSON.parse(x.config_json);
      const hedef = x.type === 'STORAGE' ? cfg.endpoint : cfg.url;
      // Bağlantı testi: yalnız TLS + ulaşılabilirlik (HEAD). Gerçek gönderim yapılmaz.
      const r2 = await fetch(hedef, { method: 'HEAD', signal: AbortSignal.timeout(8000), redirect: 'manual' });
      ok = r2.status < 500;
      mesaj = `HTTP ${r2.status}`;
    } catch (e) {
      mesaj = String(e.message).slice(0, 300);
    }
    await db.prepare('UPDATE integrations SET last_test_at = ?, last_test_ok = ?, last_test_message = ? WHERE id = ?').run(simdi(), ok ? 1 : 0, mesaj, x.id);
    await denetimYaz(db, { adminId: ctx.admin.id, ip: ctx.ip, islem: 'integration.test', hedefTur: 'integration', hedefId: x.id, sonra: { ok, mesaj } });
    return { ok, message: mesaj };
  });

  r.delete('/admin/v1/integrations/:id', async (ctx) => {
    yetkiIste(ctx.admin, 'integrations.write');
    yenidenDogrulamaIste(ctx.oturum);
    const x = await getir(ctx.params.id);
    await db.tx(async () => {
      await db.prepare('UPDATE integrations SET active = FALSE, deleted_at = ?, secret_enc = NULL, updated_at = ? WHERE id = ?').run(simdi(), simdi(), x.id);
      await denetimYaz(db, { adminId: ctx.admin.id, ip: ctx.ip, islem: 'integration.delete', hedefTur: 'integration', hedefId: x.id, once: { type: x.type, provider: x.provider }, gerekce: ctx.body.reason });
    });
    await olaylar.yayinla('integrations.changed', {}); // BÜTÜN örneklerde önbellek temizlenir
    return undefined;
  });
}
