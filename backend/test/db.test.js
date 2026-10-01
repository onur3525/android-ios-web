// Veritabanı katmanı: yer tutucu çevirisi ve SQLite ↔ PostgreSQL şema eşdeğerliği.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { gocDosyalari, yerTutucuCevir } from '../src/db.js';

test('? → $n çevirisi tırnak içine dokunmaz', () => {
  assert.equal(
    yerTutucuCevir("SELECT * FROM t WHERE a = ? AND b = '?' AND c = ?"),
    "SELECT * FROM t WHERE a = $1 AND b = '?' AND c = $2",
  );
});

// Her iki göç klasöründe AYNI dosyalar ve her tabloda AYNI sütunlar
// olmalı: SQLite'tan PostgreSQL'e geçiş sürpriz çıkarmasın.
function tablolar(sql) {
  const out = new Map();
  const re = /CREATE TABLE (\w+) \(([\s\S]*?)\n\s*\);/g;
  let m;
  while ((m = re.exec(sql))) {
    const sutunlar = m[2]
      .split('\n')
      .map((l) => l.trim())
      .flatMap((l) => l.split(/,\s*(?=[a-z_]+ [A-Z])/))
      .map((l) => /^([a-z_]+)\s+[A-Z]/.exec(l.trim())?.[1])
      .filter((x) => x && !['UNIQUE', 'PRIMARY', 'CHECK'].includes(x));
    out.set(m[1], new Set(sutunlar));
  }
  return out;
}

test('SQLite ve PostgreSQL göçleri birebir eşdeğer', () => {
  const s = gocDosyalari('sqlite');
  const p = gocDosyalari('postgres');
  assert.deepEqual(s.map((g) => g.id), p.map((g) => g.id), 'göç numaraları aynı olmalı');
  for (let i = 0; i < s.length; i++) {
    const ts = tablolar(s[i].sql);
    const tp = tablolar(p[i].sql);
    assert.deepEqual([...ts.keys()].sort(), [...tp.keys()].sort(), `${s[i].id}: tablolar`);
    for (const [ad, sutun] of ts) {
      assert.deepEqual([...sutun].sort(), [...tp.get(ad)].sort(), `${s[i].id}: ${ad} sütunları`);
    }
  }
});
