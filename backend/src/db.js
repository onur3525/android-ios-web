// ═══════════════════════════════════════════════════════════════
// VERİTABANI KATMANI — sürücüden bağımsız, ASENKRON
//
//   CANLI:           PostgreSQL (`HC_DB_DRIVER=postgres`, `HC_DATABASE_URL`)
//                    — resmî `pg` sürücüsü, bağlantı havuzu, TLS doğrulamalı.
//   GELİŞTİRME/TEST: SQLite (node:sqlite) — kurulum gerektirmez.
//
// Uygulama kodu tek bir arayüz görür:
//   await db.prepare(sql).get(...p) / .all(...p) / .run(...p)
//   await db.tx(async () => { ... })   // içindeki her sorgu AYNI işlemde
// SQL `?` yer tutucusuyla yazılır; PostgreSQL için `$1..$n`e çevrilir.
//
// ⚠ TAŞINABİLİRLİK KURALLARI (iki şema da bunlara uyar):
//   · Kimlik: uygulama UUID üretir (PG: UUID, SQLite: TEXT).
//   · Zaman: ISO-8601 UTC metni yazılır/okunur (PG: TIMESTAMPTZ).
//   · Bayrak: uygulama 1/0 kullanır (PG: BOOLEAN; sürücü true/false'u
//     okurken 1/0'a çevirir; yazarken 1/0 PG'de boolean'a dönüşür).
//   · Göçler `migrations/<sürücü>/NNN_ad.sql`; iki klasörde AYNI
//     numara ve AYNI mantıksal şema. Uygulananlar `schema_migrations`.
// ═══════════════════════════════════════════════════════════════
import { AsyncLocalStorage } from 'node:async_hooks';
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const GOC_KOKU = join(dirname(fileURLToPath(import.meta.url)), '..', 'migrations');

export const simdi = () => new Date().toISOString();

export function gocDosyalari(surucu) {
  const klasor = join(GOC_KOKU, surucu);
  return readdirSync(klasor)
    .filter((f) => /^\d{3}_.+\.sql$/.test(f))
    .sort()
    .map((f) => ({ id: f.replace(/\.sql$/, ''), sql: readFileSync(join(klasor, f), 'utf8') }));
}

// ── SQLite (geliştirme/test) ─────────────────────────────────
class SqliteDb {
  constructor(DatabaseSync, yol) {
    this.surucu = 'sqlite';
    this.ham = new DatabaseSync(yol);
    this.ham.exec('PRAGMA foreign_keys = ON; PRAGMA journal_mode = WAL;');
    this.als = new AsyncLocalStorage();
    this.kuyruk = Promise.resolve(); // açık işlem varken dış sorgular bekler
  }
  async _bekle() {
    if (!this.als.getStore()) await this.kuyruk;
  }
  // SQLite yerleşik sürücüsü JS boolean kabul etmez: 1/0'a çevrilir.
  static _p(p) {
    return p.map((v) => (v === true ? 1 : v === false ? 0 : v));
  }
  prepare(sql) {
    const db = this;
    return {
      async get(...p) { await db._bekle(); return db.ham.prepare(sql).get(...SqliteDb._p(p)); },
      async all(...p) { await db._bekle(); return db.ham.prepare(sql).all(...SqliteDb._p(p)); },
      async run(...p) { await db._bekle(); return db.ham.prepare(sql).run(...SqliteDb._p(p)); },
    };
  }
  async tx(f) {
    if (this.als.getStore()) return f(); // iç içe: dıştaki işleme katıl
    let birak;
    const onceki = this.kuyruk;
    this.kuyruk = new Promise((ok) => (birak = ok));
    await onceki;
    const baglam = { __hcSonra: [] };
    try {
      const r = await this.als.run(baglam, async () => {
        this.ham.exec('BEGIN');
        try {
          const x = await f();
          this.ham.exec('COMMIT');
          return x;
        } catch (e) {
          this.ham.exec('ROLLBACK');
          throw e;
        }
      });
      sonraCalistir(this.als, baglam.__hcSonra);
      return r;
    } finally {
      birak();
    }
  }
  commitSonrasi(fn) { commitSonrasiEkle(this.als, fn); }
  async exec(sql) { this.ham.exec(sql); }
  async close() { this.ham.close(); }
  async isKilidi(_ad, f) { return this.als.exit(() => f()); } // tek süreç; çağıranın işleminin DIŞINDA
}

// ── PostgreSQL (canlı) ───────────────────────────────────────
export function yerTutucuCevir(sql) {
  let n = 0;
  let out = '';
  let tirnak = null;
  for (let i = 0; i < sql.length; i++) {
    const c = sql[i];
    if (tirnak) {
      out += c;
      if (c === tirnak) tirnak = null;
    } else if (c === "'" || c === '"') {
      tirnak = c;
      out += c;
    } else if (c === '?') {
      out += `$${++n}`;
    } else {
      out += c;
    }
  }
  return out;
}

function satirNormalle(satir) {
  if (!satir) return satir;
  for (const k of Object.keys(satir)) {
    const v = satir[k];
    if (v === true) satir[k] = 1;
    else if (v === false) satir[k] = 0;
    else if (v !== null && typeof v === 'object' && k.endsWith('_json')) {
      satir[k] = JSON.stringify(v); // JSONB → uygulamanın beklediği metin
    }
  }
  return satir;
}

class PostgresDb {
  constructor(pg, url, ayar) {
    this.surucu = 'postgres';
    // Zaman/tarih/sayı türleri SQLite davranışıyla aynı biçimde döner.
    pg.types.setTypeParser(1184, (v) => new Date(v).toISOString()); // timestamptz
    pg.types.setTypeParser(1114, (v) => new Date(`${v}Z`).toISOString()); // timestamp
    pg.types.setTypeParser(1082, (v) => v); // date → 'YYYY-MM-DD'
    pg.types.setTypeParser(20, (v) => Number(v)); // bigint (sayaç/COUNT)
    this.havuz = new pg.Pool({
      connectionString: url,
      // İsteğe bağlı yalıtılmış şema (testler; çok kiracılı kurulum değil).
      ...(ayar.sema ? { options: `-c search_path=${ayar.sema}` } : {}),
      max: ayar.havuz,
      idleTimeoutMillis: 30_000,
      connectionTimeoutMillis: 10_000,
      statement_timeout: 15_000,
      ssl: ayar.ssl ? { rejectUnauthorized: true, ...(ayar.ca ? { ca: ayar.ca } : {}) } : false,
    });
    this.als = new AsyncLocalStorage();
    // LISTEN için havuzdan ayrılıp KALICI tutulan bağlantılar (bkz. dinleyiciAc).
    this.dinleyiciler = new Set();
    this.kapandi = false;
    this._kapanis = null;
  }
  _istemci() { return this.als.getStore() || this.havuz; }
  // Bağlantı edinme zaman aşımında havuzun anlık durumunu kaydet; sırları/URL'yi yazma.
  async _baglantiAl(kaynak) {
    try {
      return await this.havuz.connect();
    } catch (e) {
      console.error('[HC_DB_POOL_ACQUIRE_FAILED]', JSON.stringify({
        kaynak,
        hata: e?.message || String(e),
        kod: e?.code || null,
        totalCount: this.havuz.totalCount,
        idleCount: this.havuz.idleCount,
        waitingCount: this.havuz.waitingCount,
        max: this.havuz.options?.max ?? null,
      }));
      throw e;
    }
  }
  // PG boolean sütunlarına 1/0 yazılabilsin diye sayılar metne çevrilir
  // ('1'/'0' PG'de geçerli boolean girdisidir; tamsayı sütunlarında da).
  static _p(p) {
    return p.map((v) => (typeof v === 'number' ? String(v) : v));
  }
  prepare(sql) {
    const db = this;
    const q = yerTutucuCevir(sql);
    return {
      async get(...p) { const r = await db._istemci().query(q, PostgresDb._p(p)); return satirNormalle(r.rows[0]); },
      async all(...p) { const r = await db._istemci().query(q, PostgresDb._p(p)); return r.rows.map(satirNormalle); },
      async run(...p) { const r = await db._istemci().query(q, PostgresDb._p(p)); return { changes: r.rowCount }; },
    };
  }
  async tx(f) {
    if (this.als.getStore()) return f();
    const istemci = await this._baglantiAl('transaction');
    const sonra = [];
    istemci.__hcSonra = sonra;
    try {
      await istemci.query('BEGIN');
      const r = await this.als.run(istemci, f);
      await istemci.query('COMMIT');
      sonraCalistir(this.als, sonra);
      return r;
    } catch (e) {
      await istemci.query('ROLLBACK').catch(() => {});
      throw e;
    } finally {
      delete istemci.__hcSonra; // istemci havuza döner; işaret sonraki işleme taşınmaz
      istemci.release();
    }
  }
  commitSonrasi(fn) { commitSonrasiEkle(this.als, fn); }
  async exec(sql) { await this._istemci().query(sql); }
  /**
   * Havuzu kapatır.
   *
   * ⚠ NİÇİN ÖNCE DİNLEYİCİLER: `pg.Pool#end()` dışarıda tutulan BÜTÜN
   * bağlantılar havuza dönene kadar TAMAMLANMAZ. LISTEN bağlantısı
   * (`dinleyiciAc`) bilerek hiç geri verilmez; `olaylar.kapat()`
   * çağrılmadan `close()` çağrılırsa kapanış SONSUZA KADAR bekliyordu
   * (CI'da PostgreSQL adımı ilk kapanışta takıldı). Bu yüzden açık
   * dinleme bağlantıları önce SONLANDIRILIR (`release(true)`: LISTEN
   * durumundaki bağlantı havuza geri konmaz), sonra havuz kapatılır.
   *
   * ⚠ İKİ KEZ ÇAĞRILABİLİR: ikinci çağrı aynı kapanışı bekler; havuz bir
   * kez kapatılır. Kapanış başladıktan sonra yeni dinleyici verilmez.
   * Normal sorgu bağlantıları (`tx`, `isKilidi`) eskisi gibi kendi
   * `release()`'leriyle döner; `end()` onları bekler.
   */
  close() {
    if (!this._kapanis) {
      this.kapandi = true;
      this._kapanis = (async () => {
        for (const istemci of [...this.dinleyiciler]) {
          try { istemci.release(true); } catch { /* zaten kapanmış */ }
        }
        await this.havuz.end();
      })();
    }
    return this._kapanis;
  }

  /**
   * LISTEN için havuzdan ayrılmış kalıcı bağlantı (olay yolu).
   *
   * Bağlantı takip edilir ki `close()` onu sonlandırabilsin. `release`
   * TEK SEFERLİKTİR: ikinci çağrı (ör. `olaylar.kapat()` ardından
   * `close()`) yok sayılır — pg aynı bağlantı iki kez bırakılınca hata
   * fırlatır.
   */
  async dinleyiciAc() {
    if (this.kapandi) throw new Error('Veritabanı kapanıyor: yeni dinleyici açılamaz');
    const istemci = await this._baglantiAl('listener');
    const ozgun = istemci.release.bind(istemci);
    let birakildi = false;
    istemci.release = (hata) => {
      if (birakildi) return;
      birakildi = true;
      this.dinleyiciler.delete(istemci);
      ozgun(hata);
    };
    // Bağlantı alınırken kapanış başladıysa hemen sonlandırılır.
    if (this.kapandi) {
      istemci.release(true);
      throw new Error('Veritabanı kapanıyor: yeni dinleyici açılamaz');
    }
    this.dinleyiciler.add(istemci);
    return istemci;
  }
  /**
   * Arka plan işini YALNIZ BİR örnek çalıştırır (danışma kilidi, işlem
   * süresince). Kilidi alamayan örnek işi atlar — çift iş/çift bildirim yok.
   */
  //
  // ⚠ İŞ TEK BİR İŞLEMİN (transaction) İÇİNDE KOŞMAZ (önceden koşuyordu):
  //   · push işi FCM'e HTTP çağrıları yaparken işlem ve bağlantı dakikalarca
  //     açık kalıyordu; işin ortasındaki tek bir hata BÜTÜN işi geri alıyor,
  //     gönderilmiş bildirimlerin SENT durumu da kayboluyor → TEKRAR push.
  //   · sahiplenme (SENDING) işlem bitene dek başka bağlantılara görünmüyordu.
  // Artık kilit AYRI bir bağlantıda OTURUM düzeyinde tutulur; işin sorguları
  // havuzdan tek tek (otomatik commit) koşar. Atomik olması gereken adımlar
  // işin içinde zaten kendi `db.tx`'ini açar. İş, çağıranın işlem bağlamının
  // DIŞINDA koşar (`als.exit`).
  async isKilidi(ad, f) {
    const kilit = await this._baglantiAl('advisory-lock');
    let alindi = false;
    let bozuk = false;
    try {
      const k = await kilit.query('SELECT pg_try_advisory_lock(hashtext($1)) AS ok', [ad]);
      alindi = k.rows[0]?.ok === true;
      if (!alindi) return null;
      return await this.als.exit(() => f());
    } finally {
      if (alindi) {
        // Kilit çözülemezse bağlantı havuza geri KONMAZ (kilit takılı kalırdı).
        await kilit.query('SELECT pg_advisory_unlock(hashtext($1))', [ad]).catch(() => { bozuk = true; });
      }
      kilit.release(bozuk ? new Error('danışma kilidi çözülemedi') : undefined);
    }
  }
}

/**
 * Göçleri uygular. ÇOK ÖRNEKLİ BAŞLANGIÇ GÜVENLİ: PostgreSQL'de bütün
 * göçler TEK işlemde ve danışma kilidi altında koşar; aynı anda açılan
 * örneklerden yalnız biri uygular, diğerleri bekleyip hazır şemayı görür.
 */
async function gocUygula(db) {
  await db.tx(async () => {
    if (db.surucu === 'postgres') await db.prepare('SELECT pg_advisory_xact_lock(727274)').get();
    await db.exec('CREATE TABLE IF NOT EXISTS schema_migrations (id TEXT PRIMARY KEY, applied_at TEXT NOT NULL)');
    const uygulanan = new Set((await db.prepare('SELECT id FROM schema_migrations').all()).map((x) => x.id));
    for (const g of gocDosyalari(db.surucu)) {
      if (uygulanan.has(g.id)) continue;
      await db.exec(g.sql);
      await db.prepare('INSERT INTO schema_migrations (id, applied_at) VALUES (?, ?)').run(g.id, simdi());
    }
  });
}

/**
 * Veritabanını açar ve göçleri uygular.
 * ayar: { surucu: 'sqlite'|'postgres', yol?, url?, ssl?, ca?, havuz? }
 */
export async function veritabaniAc(ayar) {
  let db;
  if (ayar.surucu === 'postgres') {
    // `pg` yalnız PostgreSQL seçildiğinde yüklenir (geliştirme/test
    // ortamında kurulu olması gerekmez).
    const { default: pg } = await import('pg');
    if (ayar.sema !== undefined && !/^[a-z_][a-z0-9_]{0,40}$/.test(ayar.sema)) throw new Error('Geçersiz şema adı');
    db = new PostgresDb(pg, ayar.url, { ssl: ayar.ssl !== false, ca: ayar.ca, havuz: ayar.havuz || 10, sema: ayar.sema });
    if (ayar.sema) await db.exec(`CREATE SCHEMA IF NOT EXISTS ${ayar.sema}`);
  } else {
    const { DatabaseSync } = await import('node:sqlite');
    db = new SqliteDb(DatabaseSync, ayar.yol || ':memory:');
  }
  await gocUygula(db);
  return db;
}

/** Tekil kısıt ihlali mi? (PostgreSQL 23505 · SQLite UNIQUE/PRIMARY KEY) — eşzamanlı çift istekte 500 yerine anlamlı yanıt için. */
export function tekilIhlaliMi(e) {
  return e?.code === '23505' || /UNIQUE constraint failed|PRIMARY KEY constraint failed/.test(String(e?.message ?? ''));
}

// ── İŞLEM SONRASI GÖREVLER ──
//
// ⚠ NİÇİN: işlem içinde `setImmediate(...)` ile başlatılan bir iş, Node'un
// AsyncLocalStorage bağlamını MİRAS ALIR. PostgreSQL'de bağlam, isteğin işlem
// bağlantısıdır: iş o bağlantıda (commit'ten önce isteğin işleminin İÇİNDE,
// commit'ten sonra ise havuza dönmüş ve BAŞKA bir isteğe verilmiş olabilecek
// bağlantıda) sorgu çalıştırıyordu. `commitSonrasi` görevi YALNIZ başarılı
// commit'ten sonra ve işlem bağlamının DIŞINDA çalıştırır; geri alınan
// işlemde görev hiç çalışmaz.
function commitSonrasiEkle(als, fn) {
  const s = als.getStore();
  if (s && Array.isArray(s.__hcSonra)) s.__hcSonra.push(fn);
  else als.exit(() => setImmediate(fn));
}
function sonraCalistir(als, liste) {
  for (const fn of liste.splice(0)) als.exit(() => setImmediate(fn));
}

/** Yalnız testler: sürücü katmanını sahte havuzla sınamak için. */
export { PostgresDb as PostgresDbSinif };
