// ═══════════════════════════════════════════════════════════════
// GÖNDERİM / DEPOLAMA KANALI DURUMU — TEK KAYNAK (23 Eki)
//
// Özet ve Sistem Durumu ekranları kanal durumunu buradan yazar. Girdi,
// sunucunun `kanalKaynaklari` sonucudur (panel entegrasyonu → sunucu
// ayarı → yok; gönderimde kullanılan sırayla aynı). Kural: kanıt yoksa
// "iyi" denmez — yapılandırılmış ama hiç test edilmemiş ve hiç gönderim
// yapmamış kanal "doğrulanmadı" (nötr) görünür.
// ═══════════════════════════════════════════════════════════════

const NE_YAPILAMAZ = { EMAIL: 'e-posta gönderilemez', STORAGE: 'fotoğraf yüklenemez' };

/** Kanalın kaynağı: "Panel · resend", "Sunucu ayarı · webhook", "—". */
export function kanalKaynagi(k) {
  if (!k || k.source === 'yok') return 'Tanımlı değil';
  return `${k.source === 'panel' ? 'Panel' : 'Sunucu ayarı'} · ${k.provider ?? '—'}`;
}

/**
 * { metin, sinif } — sinif: iyi | uyari | kotu | notr.
 * [gonderildi]: son 7 günde başarılı gönderim sayısı (bilinmiyorsa null).
 * [basarisiz24]: son 24 saatte başarısız gönderim sayısı.
 */
export function kanalDurumu(k, { gonderildi = null, basarisiz24 = 0 } = {}) {
  // 23 Eki (karar A): sunucu SMS'i bilinçli olarak kapalı — doğrulama kodlarını
  // Firebase gönderir, yönetici bildirimleri e-postayla gider.
  if (k?.type === 'SMS' && k.source === 'yok') return { metin: 'Kapalı (bilinçli) — kodları Firebase gönderir, bildirimler e-postayla', sinif: 'iyi' };
  if (!k || k.source === 'yok') return { metin: `Yapılandırılmamış — ${NE_YAPILAMAZ[k?.type] ?? 'kullanılamaz'}`, sinif: 'uyari' };
  if (k.source === 'ortam' && k.provider === 'log') return { metin: 'Geliştirme kaydı — gerçek gönderim yok', sinif: 'uyari' };
  // 23 Eki: depolamayı sunucu 15 dakikada bir kendisi kontrol eder (kanıt).
  if (k.type === 'STORAGE' && k.autoCheckOk === false) return { metin: `Otomatik kontrol başarısız${k.autoCheckMessage ? ` — ${k.autoCheckMessage}` : ''}`, sinif: 'kotu' };
  if (k.type === 'STORAGE' && k.autoCheckOk === true) return { metin: 'Çalışıyor · otomatik kontrol başarılı', sinif: 'iyi' };
  if (k.lastTestOk === false) return { metin: 'Son test başarısız', sinif: 'kotu' };
  if (basarisiz24 > 0) return { metin: `Son 24 saatte ${basarisiz24.toLocaleString('tr-TR')} başarısız gönderim`, sinif: 'uyari' };
  if (k.lastTestOk === true) return { metin: 'Çalışıyor · test başarılı', sinif: 'iyi' };
  if (gonderildi > 0) return { metin: 'Çalışıyor · son 7 günde başarılı gönderim var', sinif: 'iyi' };
  return { metin: 'Yapılandırılmış · henüz doğrulanmadı', sinif: 'notr' };
}

const KANAL_ADI = { SMS: 'SMS', EMAIL: 'E-posta' };

/** Yönetici işleminden dönen bildirim sonuçları: "E-posta: gönderildi". */
export function bildirimOzeti(liste) {
  if (!liste?.length) return 'gönderilmedi';
  return liste.map((n) => `${KANAL_ADI[n.channel] ?? n.channel ?? 'Kanal'}: ${n.status === 'SENT' ? 'gönderildi' : 'gönderilemedi'}`).join(', ');
}
