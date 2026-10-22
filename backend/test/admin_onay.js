// TEST YARDIMCISI — admin değişikliklerinde şifre + kod onayı (22 Eki kuralı)
//
// Sunucu her admin değişikliğinde (GET dışı) tek kullanımlık yeniden
// doğrulama ister. Testler bunu GERÇEK uç noktayla yapar: girişte çerez
// için şifre ve TOTP sırrı kaydedilir; değişiklikten hemen önce
// /admin/v1/auth/reauth çağrılır. Sunucu kuralı atlanmaz, gevşetilmez.
// ⚠ auth.js TEMBEL yüklenir: statik içe aktarma, test dosyalarının ortam
// değişkenlerini ayarlamasından ÖNCE config'i yükletirdi.

const kimlikler = new Map();

/** Girişten sonra: bu çerezle yapılacak değişikliklerde kullanılacak şifre + sır. */
export function onayKimligi(cerez, sifre, sir) {
  if (cerez) kimlikler.set(cerez, { sifre, sir });
}

/** Değişiklik isteğinden önce çağrılır; GET, kimlik ve tanınmayan çerezde hiçbir şey yapmaz. */
export async function degisiklikOnayi(taban, yol, yontem, cerez, basliklar = {}) {
  if (!cerez || yontem === 'GET' || !yol.startsWith('/admin/v1/') || yol.startsWith('/admin/v1/auth/')) return;
  const k = kimlikler.get(cerez);
  if (!k) return;
  const { totpUret } = await import('../src/auth.js');
  const r = await fetch(`${taban}/admin/v1/auth/reauth`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-HC-Admin': '1', Cookie: cerez, ...basliklar },
    body: JSON.stringify({ password: k.sifre, code: totpUret(k.sir) }),
  });
  if (r.status !== 200) throw new Error(`yeniden doğrulama başarısız: ${r.status} ${await r.text()}`);
}
