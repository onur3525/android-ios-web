// ═══════════════════════════════════════════════════════════════
// TÜRKİYE İL / İLÇE LİSTESİ — HAZIR KAYNAK (22 Eki, kullanıcı kararı)
//
// Admin il ve ilçeleri tek tek yazmaz: liste GitHub'daki
// muratgozel/turkey-neighbourhoods deposundan (PTT posta kodu verisi, MIT)
// SABİT bir sürümle alınıp veri/il_ilce.json olarak koda gömüldü.
// 81 il, 973 ilçe — sayılar aktarımda doğrulandı. Çalışma anında dış
// ağa gidilmez; liste güncellenecekse dosya aynı yolla yenilenir.
// ═══════════════════════════════════════════════════════════════
import { readFileSync } from 'node:fs';

const veri = JSON.parse(readFileSync(new URL('../veri/il_ilce.json', import.meta.url), 'utf8'));

export const IL_ILCE_KAYNAK = Object.freeze({ ...veri.kaynak });
export const ILLER = Object.freeze(veri.iller.map((i) => Object.freeze({ kod: i.kod, ad: i.ad, ilceler: Object.freeze([...i.ilceler]) })));

export const ilBul = (kod) => ILLER.find((i) => i.kod === String(kod)) ?? null;
export const ilAdiylaBul = (ad) => ILLER.find((i) => i.ad === ad) ?? null;
