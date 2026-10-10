// ═══════════════════════════════════════════════════════════════
// ORTAK OLAY YOLU (pub/sub) — ÇOK SUNUCULU ÇALIŞMAYA HAZIR
//
// Bir örnekte olan olay (yeni mesaj, okundu, oturum iptali, ayar
// değişikliği) BÜTÜN backend örneklerine ulaşır; her örnek kendi
// WebSocket bağlantılarına iletir. Kullanıcıların farklı örneklere
// bağlı olması mesajlaşmayı bozmaz.
//
//   PostgreSQL (canlı): LISTEN/NOTIFY — ek altyapı gerektirmez; olay
//     İŞLEM (transaction) içinde yayınlanırsa yalnız COMMIT'te iletilir.
//   SQLite (geliştirme/test): süreç içi (tek örnek).
//
// ⚠ Yük KÜÇÜK tutulur (PG sınırı 8000 bayt): yalnız kimlikler taşınır;
// alıcı ayrıntıyı veritabanından okur.
// Kod tek sunucu varsaymaz: örnek sayısı artınca DEĞİŞİKLİK GEREKMEZ.
// ═══════════════════════════════════════════════════════════════
import { EventEmitter } from 'node:events';
import { randomUUID } from 'node:crypto';

const KANAL = 'hc_olaylar';

class OlayYolu extends EventEmitter {
  constructor() {
    super();
    this.setMaxListeners(0);
    this.ornekId = randomUUID();
    this.db = null;
  }

  /** Başlangıçta bir kez: PostgreSQL ise LISTEN bağlantısını kurar. */
  async kur(db) {
    this.db = db;
    if (db.surucu !== 'postgres') return;
    await this._dinle();
  }

  async _dinle() {
    try {
      const istemci = await this.db.dinleyiciAc();
      this.dinleyici = istemci;
      istemci.on('notification', (n) => {
        if (n.channel !== KANAL) return;
        try {
          const { k, v } = JSON.parse(n.payload);
          super.emit(k, v);
        } catch { /* bozuk yük yok sayılır */ }
      });
      istemci.on('error', () => this._yenidenBaglan());
      istemci.on('end', () => this._yenidenBaglan());
      await istemci.query(`LISTEN ${KANAL}`);
    } catch {
      this._yenidenBaglan();
    }
  }

  _yenidenBaglan() {
    if (this.kapaniyor || this.bekliyor) return;
    this.bekliyor = true;
    setTimeout(() => { this.bekliyor = false; this._dinle(); }, 2000).unref();
  }

  /** Olayı BÜTÜN örneklere yayınlar (kendisi dahil). */
  async yayinla(kanal, veri) {
    if (!this.db || this.db.surucu !== 'postgres') {
      super.emit(kanal, veri);
      return;
    }
    const yuk = JSON.stringify({ k: kanal, v: veri, o: this.ornekId });
    if (Buffer.byteLength(yuk) > 7900) throw new Error(`olay yükü çok büyük: ${kanal}`);
    await this.db.prepare('SELECT pg_notify(?, ?)').get(KANAL, yuk);
  }

  async kapat() {
    this.kapaniyor = true;
    try { this.dinleyici?.release(true); } catch { /* yoksay */ }
  }
}

export const olaylar = new OlayYolu();
