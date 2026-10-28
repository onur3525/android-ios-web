// Çok örnekli geçersiz kılma (28 Eki): bir örnekte yapılan temizlik olay
// yoluyla (PostgreSQL LISTEN/NOTIFY) DİĞER örneklerin önbelleğini de temizler.
// Ayrı süreçler gerçek ayrı sunucu örneklerini temsil eder.
// Yalnız HC_TEST_DB=postgres (CI'daki PostgreSQL adımı); SQLite tek örneklidir.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { randomUUID } from 'node:crypto';

const pg = process.env.HC_TEST_DB === 'postgres';
const KOK = fileURLToPath(new URL('..', import.meta.url));

// Alt süreç: olay yoluna bağlanır, önbelleği doldurur, komut bekler.
const ALT = `
import { veritabaniAc } from './src/db.js';
import { olaylar } from './src/olaylar.js';
import * as oc from './src/genel_onbellek.js';
const db = await veritabaniAc({ surucu: 'postgres', url: process.env.HC_DATABASE_URL, ssl: false, sema: process.env.SEMA });
await olaylar.kur(db);
await new Promise((r) => setTimeout(r, 300));
let n = 0;
const oku = () => oc.onbellekten('ortak', async () => ({ n: ++n }));
process.stdin.setEncoding('utf8');
process.stdin.on('data', async (s) => {
  for (const k of s.trim().split('\\n')) {
    if (k === 'oku') process.stdout.write(JSON.stringify(await oku()) + '\\n');
    if (k === 'temizle') { oc.onbellegiHerYerdeTemizle(); process.stdout.write('{"ok":1}\\n'); }
    if (k === 'cik') { await olaylar.kapat(); await db.close(); process.exit(0); }
  }
});
process.stdout.write('{"hazir":1}\\n');
`;

function ornek(sema) {
  const p = spawn(process.execPath, ['--no-warnings', '--input-type=module', '-e', ALT], {
    cwd: KOK, env: { ...process.env, SEMA: sema, HC_SESSIZ: '1' }, stdio: ['pipe', 'pipe', 'inherit'],
  });
  const kuyruk = []; let tampon = '';
  p.stdout.on('data', (d) => {
    tampon += d;
    let i;
    while ((i = tampon.indexOf('\n')) >= 0) { const s = tampon.slice(0, i); tampon = tampon.slice(i + 1); kuyruk.shift()?.(JSON.parse(s)); }
  });
  const bekle = () => new Promise((r) => kuyruk.push(r));
  // Kapanış: önce düzgün çıkış istenir; 3 sn'de çıkmazsa zorla sonlandırılır
  // (test süreci asılı kalmaz).
  const cik = () => new Promise((r) => {
    if (p.exitCode !== null) return r();
    const t = setTimeout(() => p.kill('SIGKILL'), 3000);
    p.once('exit', () => { clearTimeout(t); r(); });
    p.stdin.write('cik\n');
  });
  return { hazir: bekle(), komut: (k) => { const s = bekle(); p.stdin.write(`${k}\n`); return s; }, cik };
}

test('çok örnek: A\'daki admin temizliği B\'nin önbelleğini de temizler', { skip: !pg && 'yalnız HC_TEST_DB=postgres', timeout: 60_000 }, async () => {
  const sema = `t_${randomUUID().replace(/-/g, '').slice(0, 20)}`;
  const A = ornek(sema); const B = ornek(sema);
  await A.hazir; await B.hazir;
  try {
    assert.equal((await B.komut('oku')).n, 1);
    assert.equal((await B.komut('oku')).n, 1, 'B önbellekten okuyor');
    await A.komut('temizle');
    let n = 1;
    for (let i = 0; i < 40 && n === 1; i++) { await new Promise((r) => setTimeout(r, 50)); n = (await B.komut('oku')).n; }
    assert.equal(n, 2, 'B, A\'nın temizliğini olay yoluyla aldı ve yeniden yükledi');
  } finally { await Promise.all([A.cik(), B.cik()]); }
});
