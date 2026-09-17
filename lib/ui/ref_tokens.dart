import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════
/// REFERANS TASARIM TOKENLERİ
///
/// Kaynak: `hizmetcep-uygulama-son-kod.html` (onaylı referans)
/// Tüm değerler referans CSS'inden BİREBİR alınmıştır.
///
/// ⚠ Bu dosyada tahmin, yuvarlama veya Material varsayılanı YOKTUR.
/// Değer değişikliği yalnız referans değişirse yapılır.
///
/// CSS istatistiği: 695 kural · 76 renk · 33 font boyutu ·
/// 23 köşe yarıçapı · 23 gölge · 4 gradyan · 10 keyframes
/// ═══════════════════════════════════════════════════════════════

// ── RENKLER ────────────────────────────────────────────────────
// Kullanım sayısı referans CSS'indeki geçiş sayısıdır.

abstract final class RC {
  /// Ana metin / koyu lacivert · ×94
  static const Color text = Color(0xFF16233D);

  /// Marka mavisi · ×69
  static const Color blue = Color(0xFF1D6BE3);

  /// İkincil metin · ×39
  static const Color textSoft = Color(0xFF5B6472);

  /// Standart kenarlık · ×23
  static const Color border = Color(0xFFECEEF1);

  /// Soluk metin / ikon · ×15
  static const Color textMuted = Color(0xFF9AA4B5);

  /// Koyu gri metin · ×14
  static const Color textDark = Color(0xFF3A4658);

  /// Yüzey gri · ×14
  static const Color surface = Color(0xFFF2F4F7);

  /// Gri metin · ×13
  static const Color grey = Color(0xFF8A94A6);

  /// Açık gri metin · ×12
  static const Color greyLight = Color(0xFF98A2B3);

  /// Açık kenarlık · ×10
  static const Color borderLight = Color(0xFFE7EAEF);

  /// Başarı yeşili · ×10
  static const Color success = Color(0xFF16A34A);

  /// Kenarlık varyantı · ×9
  static const Color borderAlt = Color(0xFFE1E5EC);

  /// Yumuşak mavi zemin · ×8
  static const Color blueSoft = Color(0xFFEAF1FB);

  /// Yumuşak yeşil zemin · ×8
  static const Color successSoft = Color(0xFFE9F9EF);

  /// Zemin varyantı · ×8
  static const Color surfaceAlt = Color(0xFFEEF0F3);

  /// Hata kırmızısı · ×6
  static const Color danger = Color(0xFFE5452C);

  /// `.rg-star{color:#FF4D4F}` — ZORUNLU ALAN yıldızı.
  ///
  /// Tüm formlarda TEK kaynak budur; gri/soluk/opacity varyantı
  /// kullanılmaz.
  static const Color requiredStar = Color(0xFFFF4D4F);

  /// Zemin varyantı · ×5
  static const Color surface2 = Color(0xFFF0F2F5);

  /// Açık zemin · ×5
  static const Color surface3 = Color(0xFFF5F7FA);

  /// Beyaz · ×4
  static const Color white = Color(0xFFFFFFFF);

  /// Kenarlık varyantı · ×4
  static const Color border2 = Color(0xFFEFF1F4);

  /// Splash arka planı (`.splash{background:#FEFEFE}`)
  static const Color splashBg = Color(0xFFFEFEFE);

  /// Sayfa zemini (`body{background:#FFFFFF}`, `.page{background:#fff}`)
  static const Color pageBg = Color(0xFFFFFFFF);
}

// ── TİPOGRAFİ ──────────────────────────────────────────────────

abstract final class RF {
  /// `font-family:'Poppins',-apple-system,BlinkMacSystemFont,
  ///  'Segoe UI',Roboto,sans-serif`
  ///
  /// Poppins YEREL asset olarak bağlıdır (pubspec `fonts:`).
  /// Referans HTML'deki @font-face bloklarından çıkarılmıştır:
  /// 400 (Regular) · 500 (Medium) · 700 (Bold).
  /// ⚠ Referansta 600 ve 800 ağırlık dosyası YOKTUR; Flutter bunları
  /// en yakın ağırlıktan sentezler (referans tarayıcıda da öyle yapar).
  static const String family = 'Poppins';
  static const List<String> fallback = [
    '.SF UI Text', 'Segoe UI', 'Roboto', 'sans-serif',
  ];

  // Referanstaki font boyutları (kullanım sıklığına göre)
  static const double s10 = 10;
  static const double s105 = 10.5;
  static const double s11 = 11;
  static const double s115 = 11.5;
  static const double s12 = 12;
  static const double s125 = 12.5;
  static const double s128 = 12.8;
  static const double s13 = 13;
  static const double s135 = 13.5;
  static const double s14 = 14;
  static const double s145 = 14.5;
  static const double s15 = 15;
  static const double s155 = 15.5;
  static const double s16 = 16;
  static const double s17 = 17;
  static const double s18 = 18;
  static const double s19 = 19;
  static const double s20 = 20;
  static const double s22 = 22;
  static const double s24 = 24;
  static const double s25 = 25;

  // Referanstaki font ağırlıkları
  static const FontWeight w400 = FontWeight.w400;   // ×6
  static const FontWeight w500 = FontWeight.w500;   // ×15
  static const FontWeight w600 = FontWeight.w600;   // ×32
  static const FontWeight w700 = FontWeight.w700;   // ×90
  static const FontWeight w800 = FontWeight.w800;   // ×14

  // line-height değerleri (CSS oransal → Flutter `height`)
  static const double lh100 = 1.0;
  static const double lh115 = 1.15;
  static const double lh120 = 1.2;
  static const double lh125 = 1.25;
  static const double lh130 = 1.3;
  static const double lh135 = 1.35;
  static const double lh140 = 1.4;
  static const double lh145 = 1.45;
  static const double lh150 = 1.5;
  static const double lh155 = 1.55;

  // letter-spacing değerleri (CSS px → Flutter aynı birim)
  static const double ls0 = 0;
  static const double lsM01 = -0.1;
  static const double lsM015 = -0.15;
  static const double lsM02 = -0.2;
  static const double lsM025 = -0.25;
  static const double lsM03 = -0.3;
  static const double lsM04 = -0.4;
  static const double lsM05 = -0.5;
  static const double lsM1 = -1;
  static const double lsP05 = 0.5;
  static const double lsP06 = 0.6;
}

// ── KÖŞE YARIÇAPI ──────────────────────────────────────────────

abstract final class RR {
  static const double r2 = 2;
  static const double r4 = 4;
  static const double r6 = 6;
  static const double r7 = 7;
  static const double r8 = 8;
  static const double r9 = 9;     // ×7
  static const double r10 = 10;
  static const double r11 = 11;
  static const double r12 = 12;   // ×15
  static const double r13 = 13;   // ×19 — en sık
  static const double r14 = 14;
  static const double r15 = 15;
  static const double r16 = 16;
  static const double r18 = 18;
  static const double r22 = 22;   // sheet üst köşeleri

  /// `border-radius:50%` · ×32
  static const double circle = 999;
}

// ── GÖLGELER ───────────────────────────────────────────────────
// CSS `box-shadow: X Y BLUR COLOR` → Flutter `BoxShadow`
// CSS'te spread verilmemişse 0'dır.

abstract final class RS {
  /// `0 1px 3px rgba(16,24,40,.05)` — hafif kart
  static const List<BoxShadow> card = [
    BoxShadow(
      offset: Offset(0, 1), blurRadius: 3,
      color: Color(0x0D101828),
    ),
  ];

  /// `0 1px 5px rgba(20,40,80,.04)` — çok hafif
  static const List<BoxShadow> soft = [
    BoxShadow(
      offset: Offset(0, 1), blurRadius: 5,
      color: Color(0x0A142850),
    ),
  ];

  /// `0 1px 6px rgba(20,40,80,.04)`
  static const List<BoxShadow> soft6 = [
    BoxShadow(
      offset: Offset(0, 1), blurRadius: 6,
      color: Color(0x0A142850),
    ),
  ];

  /// `0 2px 10px rgba(20,40,80,.04)`
  static const List<BoxShadow> soft10 = [
    BoxShadow(
      offset: Offset(0, 2), blurRadius: 10,
      color: Color(0x0A142850),
    ),
  ];

  /// `0 3px 9px rgba(16,24,40,.10)`
  static const List<BoxShadow> raised = [
    BoxShadow(
      offset: Offset(0, 3), blurRadius: 9,
      color: Color(0x1A101828),
    ),
  ];

  /// `0 9px 20px rgba(26,79,196,.3)` — mavi CTA · ×3
  static const List<BoxShadow> blueCta = [
    BoxShadow(
      offset: Offset(0, 9), blurRadius: 20,
      color: Color(0x4D1A4FC4),
    ),
  ];

  /// `0 5px 12px rgba(29,107,227,.35)` — mavi buton
  static const List<BoxShadow> blueButton = [
    BoxShadow(
      offset: Offset(0, 5), blurRadius: 12,
      color: Color(0x591D6BE3),
    ),
  ];

  /// `0 3px 8px rgba(21,74,196,.26)` — mavi kare ikon
  static const List<BoxShadow> blueSquare = [
    BoxShadow(
      offset: Offset(0, 3), blurRadius: 8,
      color: Color(0x42154AC4),
    ),
  ];

  /// `0 3px 8px rgba(238,114,8,.24)` — turuncu kare ikon
  static const List<BoxShadow> orangeSquare = [
    BoxShadow(
      offset: Offset(0, 3), blurRadius: 8,
      color: Color(0x3DEE7208),
    ),
  ];

  /// `0 8px 24px rgba(0,0,0,.22)` — modal
  static const List<BoxShadow> modal = [
    BoxShadow(
      offset: Offset(0, 8), blurRadius: 24,
      color: Color(0x38000000),
    ),
  ];

  /// `0 -2px 12px rgba(20,40,80,.05)` — alt navigasyon (yukarı gölge)
  static const List<BoxShadow> bottomNav = [
    BoxShadow(
      offset: Offset(0, -2), blurRadius: 12,
      color: Color(0x0D142850),
    ),
  ];

  /// `0 0 0 3px rgba(29,107,227,.14)` — odak halkası
  static const List<BoxShadow> focusRing = [
    BoxShadow(
      offset: Offset(0, 0), blurRadius: 0, spreadRadius: 3,
      color: Color(0x241D6BE3),
    ),
  ];
}

// ── GRADYANLAR ─────────────────────────────────────────────────
// CSS `linear-gradient(ANGLE, ...)` → Flutter begin/end
// 180deg = yukarıdan aşağı · 160deg ve 135deg açılı

abstract final class RG {
  /// `linear-gradient(180deg,#2E6FE8,#1A4FC4)` · ×3 — mavi CTA
  static const LinearGradient blueCta = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF2E6FE8), Color(0xFF1A4FC4)],
  );

  /// `linear-gradient(160deg,#2E7BF6,#1348C9)` — mavi kare
  static const LinearGradient blueSquare = LinearGradient(
    begin: Alignment(-0.34, -1),
    end: Alignment(0.34, 1),
    colors: [Color(0xFF2E7BF6), Color(0xFF1348C9)],
  );

  /// `linear-gradient(160deg,#FF9A2E,#EE7208)` — turuncu kare
  static const LinearGradient orangeSquare = LinearGradient(
    begin: Alignment(-0.34, -1),
    end: Alignment(0.34, 1),
    colors: [Color(0xFFFF9A2E), Color(0xFFEE7208)],
  );

  /// `linear-gradient(135deg,#1E63E0,#1340BE)` — promosyon kartı
  static const LinearGradient promo = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E63E0), Color(0xFF1340BE)],
  );
}

// ── ANİMASYON ──────────────────────────────────────────────────
// CSS `cubic-bezier(a,b,c,d)` → Flutter `Cubic(a,b,c,d)`

abstract final class RA {
  /// `cubic-bezier(.2,.8,.2,1)` — logoIn, sheet açılışı
  static const Cubic easeOutSoft = Cubic(0.2, 0.8, 0.2, 1.0);

  /// `cubic-bezier(.0,.0,.2,1)` — sayfa girişi (fuPush, fuBack)
  static const Cubic easeOutStd = Cubic(0.0, 0.0, 0.2, 1.0);

  /// `cubic-bezier(.4,.0,1,1)` — sayfa çıkışı (fuPop)
  static const Cubic easeInStd = Cubic(0.4, 0.0, 1.0, 1.0);

  /// `cubic-bezier(.4,0,.2,1)` — ink ripple
  static const Cubic easeInOut = Cubic(0.4, 0.0, 0.2, 1.0);

  /// `cubic-bezier(.32,.72,0,1)` — sheet sürükleme
  static const Cubic sheetDrag = Cubic(0.32, 0.72, 0.0, 1.0);

  /// `logoIn .7s` — splash marka animasyonu
  static const Duration logoIn = Duration(milliseconds: 700);

  /// `fuPush .30s` / `fuBack .30s` — sayfa girişi
  static const Duration pageEnter = Duration(milliseconds: 300);

  /// `fuPop .26s` — sayfa çıkışı
  static const Duration pageExit = Duration(milliseconds: 260);

  /// `transform .26s` — bottom sheet
  static const Duration sheet = Duration(milliseconds: 260);

  /// `opacity .22s` — perde (overlay)
  static const Duration overlay = Duration(milliseconds: 220);

  /// `inkRipple .30s` + `inkFade .375s`
  static const Duration ripple = Duration(milliseconds: 300);
  static const Duration rippleFade = Duration(milliseconds: 375);

  /// `rgspin .8s linear infinite` — yükleme dönüşü
  static const Duration spin = Duration(milliseconds: 800);

  /// `skp 1.2s ease-in-out infinite` — iskelet parlaması
  static const Duration skeleton = Duration(milliseconds: 1200);

  /// `rgshake .38s` — hata sarsıntısı
  static const Duration shake = Duration(milliseconds: 380);
}

// ── YARDIMCILAR ────────────────────────────────────────────────

/// Referans tipografisiyle metin stili üretir.
///
/// CSS `line-height` oransaldır; Flutter `height` da öyle — doğrudan
/// aktarılır. `letter-spacing` px cinsindendir, Flutter'da da aynı.
TextStyle refText({
  required double size,
  FontWeight weight = RF.w400,
  Color color = RC.text,
  double? height,
  double letterSpacing = RF.ls0,
  TextDecoration? decoration,
}) =>
    TextStyle(
      fontFamily: RF.family,
      fontFamilyFallback: RF.fallback,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      decoration: decoration,
    );
