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
    try {
      return await this.als.run(true, async () => {
        this.ham.exec('BEGIN');
        try {
          const r = await f();
          this.ham.exec('COMMIT');
          return r;
        } catch (e) {
          this.ham.exec('ROLLBACK');
          throw e;
        }
      });
    } finally {
      birak();
    }
  }
  async exec(sql) { this.ham.exec(sql); }
  async close() { this.ham.close(); }
  async isKilidi(_ad, f) { return f(); } // tek süreç
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
      max: ayar.havuz,
      idleTimeoutMillis: 30_000,
      connectionTimeoutMillis: 10_000,
      statement_timeout: 15_000,
      ssl: ayar.ssl ? { rejectUnauthorized: true, ...(ayar.ca ? { ca: ayar.ca } : {}) } : false,
    });
    this.als = new AsyncLocalStorage();
  }
  _istemci() { return this.als.getStore() || this.havuz; }
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
    const istemci = await this.havuz.connect();
    try {
      await istemci.query('BEGIN');
      const r = await this.als.run(istemci, f);
      await istemci.query('COMMIT');
      return r;
    } catch (e) {
      await istemci.query('ROLLBACK').catch(() => {});
      throw e;
    } finally {
      istemci.release();
    }
  }
  async exec(sql) { await this._istemci().query(sql); }
  async close() { await this.havuz.end(); }
  /** LISTEN için havuzdan ayrılmış kalıcı bağlantı (olay yolu). */
  async dinleyiciAc() { return this.havuz.connect(); }
  /**
   * Arka plan işini YALNIZ BİR örnek çalıştırır (danışma kilidi, işlem
   * süresince). Kilidi alamayan örnek işi atlar — çift iş/çift bildirim yok.
   */
  async isKilidi(ad, f) {
    return this.tx(async () => {
      const k = await this.prepare('SELECT pg_try_advisory_xact_lock(hashtext(?)) AS ok').get(ad);
      if (k.ok !== 1) return null;
      return f();
    });
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
    db = new PostgresDb(pg, ayar.url, { ssl: ayar.ssl !== false, ca: ayar.ca, havuz: ayar.havuz || 10 });
  } else {
    const { DatabaseSync } = await import('node:sqlite');
    db = new SqliteDb(DatabaseSync, ayar.yol || ':memory:');
  }
  await gocUygula(db);
  return db;
}
