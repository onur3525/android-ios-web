// ═══════════════════════════════════════════════════════════════
// DESTEK BİLGİSİ — KODA GÖMÜLÜ, TEK KAYNAK (22 Eki, kullanıcı kararı)
//
// Admin panelindeki "Destek Bilgisi" düzenlemesi kaldırıldı. Uygulamanın
// Destek Merkezi (GET /api/v1/legal/support), e-posta alt bilgisi ve
// destek yanıtlarının Reply-To adresi YALNIZ bu sabiti kullanır.
// (Uygulamadaki yedek metin: lib/data/models/support_info.dart — aynı.)
// support_info tablosu artık okunmaz.
// ═══════════════════════════════════════════════════════════════
export const DESTEK_BILGISI = Object.freeze({
  description: 'Soru, öneri ve teknik destek talepleriniz için destek ekibimize yazın.',
  email: 'destek@hizmetcep.com',
});
