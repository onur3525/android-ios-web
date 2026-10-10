// SÖZLEŞME TUTARLILIĞI: docs/openapi.yaml ⇄ gerçek /api/v1 rotaları.
// Sözleşmede olup sunucuda olmayan (ölü) ya da sunucuda olup sözleşmede
// olmayan uç kalmaz. Admin API'si (/admin/v1) bu sözleşmenin DIŞINDADIR.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

process.env.HC_SESSIZ = '1';
const { Yonlendirici } = await import('../src/http.js');
const rotalar = [];
const asil = Yonlendirici.prototype.ekle;
Yonlendirici.prototype.ekle = function ekle(y, d, f) { rotalar.push([y, d]); return asil.call(this, y, d, f); };
const { uygulamaKur } = await import('../src/server.js');
const { testDb } = await import('./destek.js');

const norm = (p) => p.replace(/:\w+/g, '{}').replace(/\{[^}]+\}/g, '{}').replace(/\/$/, '');

test('openapi.yaml ile /api/v1 rotaları birebir aynı', async () => {
  const db = await testDb();
  try {
    uygulamaKur(db);
    const sunucu = new Set(rotalar.filter(([, d]) => d.startsWith('/api/v1/')).map(([y, d]) => `${y} ${norm(d.slice('/api/v1'.length))}`));
    const sozlesme = new Set();
    let yol = null;
    for (const satir of readFileSync(new URL('../../docs/openapi.yaml', import.meta.url), 'utf8').split('\n')) {
      const p = /^ {2}(\/[^:]*):\s*$/.exec(satir);
      if (p) { yol = norm(p[1]); continue; }
      if (/^\S/.test(satir)) yol = null;
      const m = /^ {4}(get|post|put|patch|delete):\s*$/.exec(satir);
      if (m && yol) sozlesme.add(`${m[1].toUpperCase()} ${yol}`);
    }
    assert.deepEqual([...sozlesme].filter((x) => !sunucu.has(x)).sort(), [], 'sözleşmede olup sunucuda OLMAYAN');
    assert.deepEqual([...sunucu].filter((x) => !sozlesme.has(x)).sort(), [], 'sunucuda olup sözleşmede OLMAYAN');
    assert.ok(sunucu.size > 50);
  } finally {
    Yonlendirici.prototype.ekle = asil;
    await db.close();
  }
});
