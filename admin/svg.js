// ═══════════════════════════════════════════════════════════════
// SVG YARDIMCILARI — Özet ve Sistem Durumu ekranları ORTAK (23 Eki)
// CSP: satır içi stil yok; renk ve boyut SVG öznitelikleri / CSS sınıfları.
// ═══════════════════════════════════════════════════════════════
const SVG_NS = 'http://www.w3.org/2000/svg';

export function svg(etiket, nit = {}, ...cocuk) {
  const e = document.createElementNS(SVG_NS, etiket);
  for (const [k, v] of Object.entries(nit)) e.setAttribute(k, String(v));
  for (const c of cocuk) if (c) e.append(c);
  return e;
}

/** Basit ikon kümesi (çizgi; currentColor). */
const IKON = {
  kisi: 'M16 19v-1a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v1M10 10a3 3 0 1 0 0-6 3 3 0 0 0 0 6M20 19v-1a3 3 0 0 0-2-2.8M15 4.2a3 3 0 0 1 0 5.6',
  ilan: 'M7 3h10a1 1 0 0 1 1 1v16a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1M9 8h6M9 12h6M9 16h4',
  teklif: 'M6 3h9l3 3v15H6zM9 11h6M9 15h6',
  talep: 'M4 5h16v10H8l-4 4zM8 9h8M8 12h5',
  askida: 'M9 6v12M15 6v12',
  ban: 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18M6 6l12 12',
  tik: 'M5 12l4 4 10-10',
  silme: 'M5 7h14M10 11v6M14 11v6M7 7l1 13h8l1-13M9 7V4h6v3',
  zil: 'M6 16V11a6 6 0 1 1 12 0v5l2 2H4zM10 20a2 2 0 0 0 4 0',
  sunucu: 'M4 5h16v6H4zM4 13h16v6H4zM8 8h.01M8 16h.01',
  db: 'M12 3c4.4 0 8 1.3 8 3s-3.6 3-8 3-8-1.3-8-3 3.6-3 8-3M4 6v12c0 1.7 3.6 3 8 3s8-1.3 8-3V6M4 12c0 1.7 3.6 3 8 3s8-1.3 8-3',
  sms: 'M4 5h16v11H8l-4 4zM8 10h.01M12 10h.01M16 10h.01',
  posta: 'M3 6h18v12H3zM3 7l9 6 9-6',
  depo: 'M4 7l8-4 8 4-8 4zM4 7v10l8 4 8-4V7M12 11v10',
  takvim: 'M4 5h16v15H4zM4 9h16M8 3v4M16 3v4',
  // 23 Eki — Sistem Durumu ekranı
  islemci: 'M7 7h10v10H7zM10 10h4v4h-4zM9 3v4M15 3v4M9 17v4M15 17v4M3 9h4M3 15h4M17 9h4M17 15h4',
  yedek: 'M12 3a9 9 0 1 1-8.5 6M3 4v5h5M12 8v4l3 2',
  bulut: 'M7 18h10a4 4 0 0 0 .5-8A6 6 0 0 0 6 9.5 4.3 4.3 0 0 0 7 18M12 11v5M10 14l2 2 2-2',
  kalkan: 'M12 3l7 3v6c0 4.5-3 7.5-7 9-4-1.5-7-4.5-7-9V6zM9 12l2 2 4-4',
  nabiz: 'M3 12h4l2-6 4 12 2-6h6',
};
export function ikon(ad, boyut = 20) {
  return svg('svg', { viewBox: '0 0 24 24', width: boyut, height: boyut, fill: 'none', stroke: 'currentColor', 'stroke-width': 1.8, 'stroke-linecap': 'round', 'stroke-linejoin': 'round', 'aria-hidden': 'true' },
    svg('path', { d: IKON[ad] }));
}
