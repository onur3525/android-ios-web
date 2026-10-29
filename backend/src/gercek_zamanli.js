// ═══════════════════════════════════════════════════════════════
// GERÇEK ZAMANLI KATMAN — Socket.IO v4 (Engine.IO 4) uyumlu, yalnız
// WebSocket taşıyıcısı, harici bağımlılık YOK.
//
// Flutter `ws_client.dart`: socket_io_client, transports ['websocket'],
// adres `<api>/ws` → yol /socket.io/, isim alanı '/ws',
// el sıkışma auth = {token}. Olaylar (`ws_auth.dart`):
//   istemci → conversation.join / conversation.leave  {offerId}
//   sunucu  → message.new / message.delivered / message.read
//
// Güvenlik: token her bağlantıda doğrulanır (hesap durumu dahil);
// odaya YALNIZ sohbetin iki tarafı ve YALNIZ iletişim açıkken katılır.
// Kullanıcının oturumları iptal edilince (askı/ban/şifre) açık soketleri
// de kapatılır. Çerçeve boyutu sınırlı (maxPayload).
//
// ⚠ YENİDEN DOĞRULAMA (KVKK takip denetimi E4, 22 Eki): erişim jetonu
// yalnız bağlantı kurulurken doğrulanıyordu; soket, jetonun süresi
// dolduktan ve oturumun kendisi (yenileme süresi) bittikten sonra da açık
// kalabiliyordu, bakım modu soketleri hiç kapsamıyordu. Artık bağlantıda
// ve her YENIDEN_DOGRULAMA_MS'de bir, bütün soketler TOPLU (tek sorgu /
// 200 oturum) denetlenir; şu durumlarda soket kapanır:
//   · oturum iptal edilmiş ya da oturum süresi (`user_sessions.expires_at`)
//     dolmuş — kısa ömürlü erişim jetonu süresi değil: istemci jetonu
//     REST'te yeniler ve yeniden bağlanmada tazesini gönderir;
//   · hesap silinmiş, dondurulmuş, askıda ya da kapatılmış;
//   · bakım açık ve hesap bakım test listesinde değil.
// Veritabanı geçici olarak okunamazsa soketler KAPATILMAZ (bağlantıda
// zaten doğrulandılar; iptal olayları ayrıca anında kapatır).
// ═══════════════════════════════════════════════════════════════
import { gorselAdresleriEkle } from './gorsel_adresleri.js';
import { createHash, randomBytes } from 'node:crypto';
import { olaylar } from './olaylar.js';
import { ANLIK_HABER_KANALI } from './anlik_haber.js';
import { ilanMesajlariIletildi, mesajDurumu } from './mesaj_durumu.js';
import { kullaniciCoz } from './routes/kullanici.js';
import { bakimDurumu } from './bakim_modu.js';
import { simdi } from './db.js';
import { istemciIp, kokenDogrulandi } from './http.js';
import { config, uretim } from './config.js';
import { isIP } from 'node:net';

const GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';
const NSP = '/ws';
const PING_ARALIK = 25_000;
const PING_ZAMAN_ASIMI = 20_000;
const AZAMI_YUK = 64 * 1024;

function cerceve(metin, opkod = 0x1) {
  const veri = Buffer.from(metin);
  const n = veri.length;
  let bas;
  if (n < 126) bas = Buffer.from([0x80 | opkod, n]);
  else if (n < 65536) { bas = Buffer.alloc(4); bas[0] = 0x80 | opkod; bas[1] = 126; bas.writeUInt16BE(n, 2); }
  else { bas = Buffer.alloc(10); bas[0] = 0x80 | opkod; bas[1] = 127; bas.writeBigUInt64BE(BigInt(n), 2); }
  return Buffer.concat([bas, veri]);
}

// ── ⚠ KÖTÜ NİYETLİ İSTEMCİYE KARŞI SINIRLAR (29 Eki, güvenlik incelemesi) ──
// · Parçalı mesaj (FIN=0 çerçeveler) TOPLAMDA en çok AZAMI_YUK: sınır
//   çerçeve BAŞLIĞI okunur okunmaz denetlenir (gövde beklenmeden); aşımda
//   biriken parçalar bırakılır, bağlantı kapanır. Önceden yalnız tek
//   çerçeve sınırlıydı; kimliksiz bir bağlantı FIN'siz çerçevelerle saniyede
//   onlarca MB biriktirebiliyordu.
// · Denetim çerçeveleri (ping/pong/close) en çok 125 bayt ve bölünmez
//   (RFC 6455 §5.5); yarım parça varken yeni veri mesajı ya da başlangıçsız
//   devam çerçevesi protokol ihlalidir → kapanır.
// · Bağlantı başına mesaj hızı: MESAJ_PENCERESI_MS içinde en çok
//   AZAMI_MESAJ paket ya da ping (normal kullanım: 25 sn'de bir pong +
//   sohbet aç/kapa).
// · Paketler SIRAYLA işlenir (eşzamanlı veritabanı sorgusu yağmuru yok).
// · Yazma tamponu YAZMA_TAMPONU_SINIRI'nı aşarsa (okumayan istemci; ping
//   yankısı/olaylar birikir) bağlantı kapanır.
// · Kimliksiz (henüz `40` göndermemiş) bağlantı: IP başına en çok
//   IP_BASINA_KIMLIKSIZ (IPv6'da /64 ağı başına; bkz. `ipAnahtari`); kimlik
//   süresi (10 sn) aynen.
// · Kapanışta tampon ve parçalar bırakılır; karşı taraf kapanışa yanıt
//   vermezse soket KAPANIS_BEKLEME_MS sonra zorla kapatılır.
const AZAMI_DENETIM_YUKU = 125;
const AZAMI_MESAJ = 60;
const MESAJ_PENCERESI_MS = 10_000;
const YAZMA_TAMPONU_SINIRI = 1024 * 1024;
const IP_BASINA_KIMLIKSIZ = 20;
const KAPANIS_BEKLEME_MS = 5_000;
export const WS_SINIRLARI = { AZAMI_YUK, AZAMI_DENETIM_YUKU, AZAMI_MESAJ, MESAJ_PENCERESI_MS, YAZMA_TAMPONU_SINIRI, IP_BASINA_KIMLIKSIZ };

/**
 * IP sınırının anahtarı (29 Eki): IPv4 olduğu gibi; IPv6 /64 ağına indirgenir.
 * Tek bir IPv6 abonesi genelde bütün bir /64 ağına sahiptir; adres başına
 * sayılsaydı saldırgan her bağlantıda başka adres kullanıp sınırı aşardı.
 */
export function ipAnahtari(ip) {
  const yalin = String(ip ?? '').split('%')[0];
  if (isIP(yalin) !== 6) return yalin;
  const yari = yalin.split('::');
  const parca = (x) => (x ? x.split(':') : []);
  const say = (a) => a.reduce((n, g) => n + (g.includes('.') ? 2 : 1), 0);
  const sol = parca(yari[0]);
  const sag = yari.length > 1 ? parca(yari[1]) : [];
  const sifirlar = yari.length > 1 ? Array(Math.max(0, 8 - say(sol) - say(sag))).fill('0') : [];
  const gruplar = [...sol, ...sifirlar, ...sag];
  return `${gruplar.slice(0, 4).map((g) => parseInt(g, 16).toString(16)).join(':')}::/64`;
}

/**
 * IP başına kimliksiz bağlantı sınırı uygulanabilir mi? (29 Eki)
 *
 * Üretimde sunucu bir proxy (Render) arkasındadır. `HC_TRUST_PROXY_HOPS`
 * tanımsızsa (0) bütün kullanıcılar proxy'nin TEK adresinden geliyor
 * görünür; sınır o zaman bütün site için 20'ye iner ve bir saldırgan
 * herkesin anlık bağlantısını engelleyebilirdi. Bu durumda sınır
 * UYGULANMAZ (açılışta uyarı yazılır); bağlantı başına bellek sınırları ve
 * 10 sn kimlik süresi aynen geçerlidir. Değer ölçülüp girilince sınır
 * kendiliğinden devreye girer. Geliştirme/test (proxy yok): sınır açık.
 */
export const ipSiniriEtkinMi = ({ uretimde = uretim, hop = config.guvenilirProxySayisi } = {}) => !(uretimde && hop === 0);

const KIMLIK_ZAMAN_ASIMI = 10_000;
const KULLANICI_BASINA_AZAMI_BAGLANTI = 10;
export const YENIDEN_DOGRULAMA_MS = 60_000;
const DOGRULAMA_PARCASI = 200;

class Baglanti {
  constructor(soket, hub, ip) {
    this.soket = soket;
    this.hub = hub;
    this.ip = ip;
    this.tampon = Buffer.alloc(0);
    this.parcalar = [];
    this.parcaBoyu = 0;
    this.pencereBasi = Date.now();
    this.penceredekiMesaj = 0;
    this.kuyruk = Promise.resolve();
    this.kullanici = null;
    this.odalar = new Set();
    this.sid = randomBytes(12).toString('base64url');
    this.pongBekleniyor = false;
    soket.on('data', (d) => this._veri(d));
    soket.on('close', () => this.kapat());
    // Karşı taraf bağlantıyı kapattı (FIN): HTTP sunucusu soketleri yarı açık
    // tutar; dinlenmezse kapanış ancak ping zaman aşımında (~50 sn) olurdu.
    soket.on('end', () => this.kapat());
    soket.on('error', () => this.kapat());
    this._gonderHam(`0${JSON.stringify({ sid: this.sid, upgrades: [], pingInterval: PING_ARALIK, pingTimeout: PING_ZAMAN_ASIMI, maxPayload: AZAMI_YUK })}`);
    this.ping = setInterval(() => {
      if (this.pongBekleniyor) return this.kapat();
      this.pongBekleniyor = true;
      this._gonderHam('2');
    }, PING_ARALIK);
    this.ping.unref?.();
    // Kimliksiz bağlantı tutulmaz: belirli sürede `40` (kimlik) paketi
    // gelmezse kapanır. Aksi hâlde ping'e yanıt veren kimliksiz soketler
    // sınırsız sayıda açık kalıp belleği tüketebilirdi.
    this.kimlikZamani = setTimeout(() => { if (!this.kullanici) this.kapat(); }, KIMLIK_ZAMAN_ASIMI);
    this.kimlikZamani.unref?.();
  }
  _gonderHam(metin) {
    if (this.soket.destroyed) return;
    // Okumayan istemci: yazılanlar bellekte birikir → bağlantı kapanır.
    if (this.soket.writableLength > YAZMA_TAMPONU_SINIRI) { this.kapat(); return; }
    this.soket.write(cerceve(metin));
  }
  olay(ad, veri) {
    this._gonderHam(`42${NSP},${JSON.stringify([ad, veri])}`);
  }
  kapat() {
    if (this.kapandi) return;
    this.kapandi = true;
    clearInterval(this.ping);
    clearTimeout(this.kimlikZamani);
    // Biriken veri hemen bırakılır.
    this.tampon = Buffer.alloc(0);
    this.parcalar = [];
    this.parcaBoyu = 0;
    this.hub.kimliksizCikar(this);
    for (const o of this.odalar) this.hub.odadanCik(o, this);
    this.hub.baglantiCikar(this);
    if (!this.soket.destroyed) {
      try { this.soket.end(cerceve('', 0x8)); } catch { /* yoksay */ }
      const zorla = setTimeout(() => this.soket.destroy(), KAPANIS_BEKLEME_MS);
      zorla.unref?.();
      this.soket.once('close', () => clearTimeout(zorla));
    }
  }
  _veri(d) {
    if (this.kapandi) return;
    this.tampon = Buffer.concat([this.tampon, d]);
    if (this.tampon.length > AZAMI_YUK * 2) return this.kapat();
    for (;;) {
      if (this.tampon.length < 2) return;
      const b0 = this.tampon[0];
      const b1 = this.tampon[1];
      const fin = (b0 & 0x80) !== 0;
      const opkod = b0 & 0x0f;
      const maskeli = (b1 & 0x80) !== 0;
      let n = b1 & 0x7f;
      let o = 2;
      if (n === 126) { if (this.tampon.length < 4) return; n = this.tampon.readUInt16BE(2); o = 4; }
      else if (n === 127) { if (this.tampon.length < 10) return; n = Number(this.tampon.readBigUInt64BE(2)); o = 10; }
      if (!maskeli || n > AZAMI_YUK) return this.kapat(); // istemci çerçeveleri maskeli olmak ZORUNDA
      // ⚠ SINIR BAŞLIKTA (gövde beklenmeden) denetlenir; bkz. dosya başı.
      const denetim = opkod >= 0x8;
      if (denetim) {
        if (!fin || n > AZAMI_DENETIM_YUKU) return this.kapat();
      } else {
        if (opkod !== 0x0 && opkod !== 0x1 && opkod !== 0x2) return this.kapat(); // tanımsız opkod
        if (opkod === 0x0 && !this.parcalar.length) return this.kapat(); // başlangıçsız devam
        if (opkod !== 0x0 && this.parcalar.length) return this.kapat(); // yarım mesaj varken yeni mesaj
        if (this.parcaBoyu + n > AZAMI_YUK) return this.kapat();
      }
      if (this.tampon.length < o + 4 + n) return;
      const maske = this.tampon.subarray(o, o + 4);
      const yuk = Buffer.from(this.tampon.subarray(o + 4, o + 4 + n));
      for (let i = 0; i < n; i++) yuk[i] ^= maske[i & 3];
      this.tampon = this.tampon.subarray(o + 4 + n);
      if (opkod === 0x8) return this.kapat();
      if (opkod === 0x9) {
        if (this._hizAsildi()) return this.kapat(); // ping yağmuru da sayılır
        if (this.soket.writableLength > YAZMA_TAMPONU_SINIRI) return this.kapat();
        this.soket.write(cerceve(yuk.toString(), 0xa));
        continue;
      }
      if (opkod === 0xa) continue;
      this.parcalar.push(yuk);
      this.parcaBoyu += n;
      if (!fin) continue;
      const metin = Buffer.concat(this.parcalar).toString('utf8');
      this.parcalar = [];
      this.parcaBoyu = 0;
      if (this._hizAsildi()) return this.kapat(); // bağlantı başına mesaj hızı
      // Sırayla işlenir: eşzamanlı sorgu yağmuru olmaz; hız sınırı kuyruğu da sınırlar.
      this.kuyruk = this.kuyruk.then(() => (this.kapandi ? undefined : this._paket(metin))).catch(() => this.kapat());
      if (this.kapandi) return;
    }
  }
  /** Bu pencerede bir mesaj daha sayılır; sınır aşıldıysa true. */
  _hizAsildi() {
    const simdiMs = Date.now();
    if (simdiMs - this.pencereBasi >= MESAJ_PENCERESI_MS) { this.pencereBasi = simdiMs; this.penceredekiMesaj = 0; }
    return ++this.penceredekiMesaj > AZAMI_MESAJ;
  }
  async _paket(p) {
    if (p === '3') { this.pongBekleniyor = false; return; }
    if (p === '1') return this.kapat();
    if (!p.startsWith('4')) return;
    const sio = p.slice(1);
    // Socket.IO paketi: <tür>[/nsp,][ackId][json]
    const tur = sio[0];
    let geri = sio.slice(1);
    let nsp = '/';
    if (geri.startsWith('/')) {
      const v = geri.indexOf(',');
      nsp = v < 0 ? geri : geri.slice(0, v);
      geri = v < 0 ? '' : geri.slice(v + 1);
    }
    if (nsp !== NSP) return this._gonderHam(`44${nsp},${JSON.stringify({ message: 'Invalid namespace' })}`);
    if (tur === '0') {
      if (this.kullanici) return; // kimlik bir kez doğrulanır (tekrar = sorgu yağmuru)
      let auth = {};
      try { auth = geri ? JSON.parse(geri) : {}; } catch { /* boş */ }
      try {
        const { u, oturum } = await kullaniciCoz(this.hub.db, { headers: { authorization: `Bearer ${auth.token ?? ''}` } });
        // Bakım modu REST kapısından geçmeyen soketlere de uygulanır.
        if (!(await this.hub.oturumlarGecerli([{ oturumId: oturum.id, kullaniciId: u.id }])).has(oturum.id)) throw new Error('gecersiz');
        if (this.kapandi) return;
        this.kullanici = u;
        this.oturumId = oturum.id;
        this.hub.kimliksizCikar(this);
        this.hub.baglantiEkle(this);
        this._gonderHam(`40${NSP},${JSON.stringify({ sid: this.sid })}`);
      } catch {
        this._gonderHam(`44${NSP},${JSON.stringify({ message: 'unauthorized' })}`);
        this.kapat();
      }
      return;
    }
    if (tur === '1') return this.kapat();
    if (tur !== '2' || !this.kullanici) return;
    const m = /^(\d*)(\[.*\])$/s.exec(geri);
    if (!m) return;
    const [ad, veri] = JSON.parse(m[2]);
    const offerId = String(veri?.offerId ?? '');
    if (ad === 'conversation.join') {
      const izinli = await this.hub.katilabilir(this.kullanici.id, offerId);
      // ⚠ 29 Eki: yetki sorgusu sürerken bağlantı kapandıysa odaya EKLENMEZ
      // (kapalı bağlantı odada kalır, bellekte birikirdi).
      if (izinli && !this.kapandi) {
        this.odalar.add(offerId);
        this.hub.odayaKat(offerId, this);
      }
    } else if (ad === 'conversation.leave') {
      this.odalar.delete(offerId);
      this.hub.odadanCik(offerId, this);
    }
    if (m[1]) this._gonderHam(`43${NSP},${m[1]}[]`); // ack
  }
}

export function gercekZamanliKur(sunucu, db) {
  const ipSiniri = ipSiniriEtkinMi();
  if (!ipSiniri && !process.env.HC_SESSIZ) {
    console.warn('[gercek_zamanli] HC_TRUST_PROXY_HOPS tanımsız: WebSocket IP başına kimliksiz bağlantı sınırı DEVRE DIŞI (bkz. DEPLOY.md).');
  }
  const hub = {
    db,
    odalar: new Map(),
    kullanicilar: new Map(),
    /** IP → kimliksiz bağlantı kümesi. */
    kimliksizler: new Map(),
    kimliksizEkle(b) {
      const set = this.kimliksizler.get(b.ip) ?? new Set();
      if (ipSiniri && set.size >= IP_BASINA_KIMLIKSIZ) return false;
      set.add(b);
      this.kimliksizler.set(b.ip, set);
      return true;
    },
    kimliksizCikar(b) {
      const set = this.kimliksizler.get(b.ip);
      if (!set?.delete(b)) return;
      if (set.size === 0) this.kimliksizler.delete(b.ip);
    },
    baglantiEkle(b) {
      if (!this.kullanicilar.has(b.kullanici.id)) this.kullanicilar.set(b.kullanici.id, new Set());
      const set = this.kullanicilar.get(b.kullanici.id);
      set.add(b);
      // Kullanıcı başına üst sınır: aşılırsa EN ESKİ bağlantı kapanır
      // (tek hesapla binlerce soket açıp belleği tüketme engellenir).
      while (set.size > KULLANICI_BASINA_AZAMI_BAGLANTI) set.values().next().value.kapat();
    },
    // Boşalan kümeler silinir: aksi hâlde her kullanıcı/oda için boş Set
    // kalır ve harita süreç ömrü boyunca büyür.
    baglantiCikar(b) {
      if (!b.kullanici) return;
      const set = this.kullanicilar.get(b.kullanici.id);
      set?.delete(b);
      if (set && set.size === 0) this.kullanicilar.delete(b.kullanici.id);
    },
    odayaKat(o, b) { if (!this.odalar.has(o)) this.odalar.set(o, new Set()); this.odalar.get(o).add(b); },
    odadanCik(o, b) {
      const set = this.odalar.get(o);
      set?.delete(b);
      if (set && set.size === 0) this.odalar.delete(o);
    },
    /**
     * Geçerli oturum kimlikleri (Set). [liste]: {oturumId, kullaniciId}.
     * Okuma hatası fırlatır (çağıran karar verir).
     */
    async oturumlarGecerli(liste) {
      const bk = await bakimDurumu(db);
      const gecerli = new Set();
      const benzersiz = [...new Map(liste.map((x) => [x.oturumId, x])).values()];
      for (let i = 0; i < benzersiz.length; i += DOGRULAMA_PARCASI) {
        const parca = benzersiz.slice(i, i + DOGRULAMA_PARCASI);
        const satirlar = await db.prepare(
          `SELECT s.id, s.user_id FROM user_sessions s JOIN users u ON u.id = s.user_id
            WHERE s.id IN (${parca.map(() => '?').join(', ')}) AND s.revoked_at IS NULL AND s.expires_at > ?
              AND u.deleted_at IS NULL AND u.frozen_at IS NULL AND u.status NOT IN ('SUSPENDED', 'BANNED')
              ${bk.aktif ? 'AND u.maintenance_bypass = TRUE' : ''}`,
        ).all(...parca.map((x) => x.oturumId), simdi());
        const sahip = new Map(parca.map((x) => [x.oturumId, x.kullaniciId]));
        for (const r of satirlar) if (sahip.get(r.id) === r.user_id) gecerli.add(r.id);
      }
      return gecerli;
    },
    /** Bütün açık soketleri yeniden doğrular; kapatılan sayısı. */
    async yenidenDogrula() {
      const hepsi = [...this.kullanicilar.values()].flatMap((set) => [...set]);
      if (!hepsi.length) return 0;
      let gecerli;
      try {
        gecerli = await this.oturumlarGecerli(hepsi.map((b) => ({ oturumId: b.oturumId, kullaniciId: b.kullanici.id })));
      } catch {
        return 0; // geçici okuma hatası: soketler korunur
      }
      let kapanan = 0;
      for (const b of hepsi) {
        if (!gecerli.has(b.oturumId)) { b.kapat(); kapanan++; }
      }
      return kapanan;
    },
    async katilabilir(kullaniciId, offerId) {
      const x = await db.prepare(
        `SELECT 1 FROM offers o JOIN listings l ON l.id = o.listing_id JOIN contacts c ON c.offer_id = o.id
          WHERE o.id = ? AND (o.provider_id = ? OR l.owner_id = ?)`,
      ).get(offerId, kullaniciId, kullaniciId);
      return !!x;
    },
  };

  // Olay yolu yalnız kimlik taşır (çok örnekli kurulumda PG NOTIFY
  // sınırı); mesajın kendisi veritabanından okunur ve bu örneğe bağlı
  // soketlere iletilir. Diğer örnekler aynı olayı kendi soketlerine iletir.
  olaylar.on('message.new', async ({ offerId, messageId }) => {
    const alicilar = hub.odalar.get(offerId);
    if (!alicilar?.size) return;
    const m = await db.prepare('SELECT * FROM messages WHERE id = ?').get(messageId).catch(() => null);
    if (!m) return;
    const veri = { id: m.id, offerId: m.offer_id, senderId: m.sender_id, text: m.text, storageRef: m.storage_ref, status: mesajDurumu(m), createdAt: m.created_at };
    // Fotoğraflı mesajda imzalı görüntüleme adresi (HTTP yanıtıyla aynı).
    await gorselAdresleriEkle(db, veri);
    const alicilarIletildi = new Set();
    for (const b of alicilar) {
      b.olay('message.new', veri);
      if (b.kullanici?.id && b.kullanici.id !== m.sender_id) alicilarIletildi.add(b.kullanici.id);
    }
    // 29 Eki: alıcı sohbet odasında → mesaj onun uygulamasına ULAŞTI.
    for (const alici of alicilarIletildi) await ilanMesajlariIletildi(db, [offerId], alici).catch(() => {});
  });
  // 28 Eki: uygulama içi bildirim → yalnız O KULLANICININ açık soketlerine
  // tür bilgisiyle haber (içerik taşımaz; bkz. anlik_haber.js).
  olaylar.on(ANLIK_HABER_KANALI, ({ h } = {}) => {
    if (!Array.isArray(h)) return;
    for (const [kullaniciId, tur] of h) {
      for (const b of hub.kullanicilar.get(kullaniciId) ?? []) b.olay(ANLIK_HABER_KANALI, { type: tur });
    }
  });
  olaylar.on('message.delivered', ({ offerId, aliciId }) => {
    for (const b of hub.odalar.get(offerId) ?? []) b.olay('message.delivered', { offerId, aliciId });
  });
  olaylar.on('message.read', ({ offerId, readerId }) => {
    for (const b of hub.odalar.get(offerId) ?? []) b.olay('message.read', { offerId, readerId });
  });
  // Askı/ban/şifre değişikliği/silme: kullanıcının açık soketleri kapanır.
  // `oturumId` verilirse YALNIZ o oturumun soketleri kapanır (çıkış ya da
  // kullanıcının tek oturumu sonlandırması); verilmezse `haric` dışındakiler.
  olaylar.on('user.sessions.revoked', ({ userId, haric, oturumId }) => {
    for (const b of [...(hub.kullanicilar.get(userId) ?? [])]) {
      if (oturumId ? b.oturumId === oturumId : b.oturumId !== haric) b.kapat();
    }
  });

  /** Kapanışta (ölçek küçültme/dağıtım) bütün soketler düzgün kapatılır;
   *  istemci otomatik olarak başka bir örneğe yeniden bağlanır. */
  const dogrulamaZamanlayici = setInterval(() => { hub.yenidenDogrula().catch(() => {}); }, YENIDEN_DOGRULAMA_MS);
  dogrulamaZamanlayici.unref?.();
  hub.hepsiniKapat = () => {
    clearInterval(dogrulamaZamanlayici);
    for (const set of hub.kullanicilar.values()) for (const b of [...set]) b.kapat();
    for (const set of hub.kimliksizler.values()) for (const b of [...set]) b.kapat();
  };

  sunucu.on('upgrade', (req, soket) => {
    const url = new URL(req.url, 'http://yerel');
    const anahtar = req.headers['sec-websocket-key'];
    if (url.pathname !== '/socket.io/' || url.searchParams.get('EIO') !== '4'
        || url.searchParams.get('transport') !== 'websocket' || !anahtar
        || String(req.headers.upgrade).toLowerCase() !== 'websocket') {
      soket.end('HTTP/1.1 400 Bad Request\r\n\r\n');
      return;
    }
    // 29 Eki — KÖKEN SIRRI (bkz. http.js): doğrudan bağlantı reddedilir.
    if (!kokenDogrulandi(req)) {
      soket.end('HTTP/1.1 403 Forbidden\r\n\r\n');
      return;
    }
    const kabul = createHash('sha1').update(anahtar + GUID).digest('base64');
    soket.write('HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n'
      + `Sec-WebSocket-Accept: ${kabul}\r\n\r\n`);
    soket.setNoDelay(true);
    const b = new Baglanti(soket, hub, ipAnahtari(istemciIp(req)));
    if (!hub.kimliksizEkle(b)) b.kapat(); // IP başına kimliksiz bağlantı sınırı
  });
  return hub;
}
