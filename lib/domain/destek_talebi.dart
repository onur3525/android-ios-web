import 'form_mesajlari.dart';

/// ═══════════════════════════════════════════════════════════════
/// DESTEK TALEBİ — İSTEMCİ KURALLARI (Destek Merkezi › Talep Gönder)
///
/// Sınırlar backend `POST /support/tickets` doğrulamasıyla AYNIDIR
/// (`backend/src/routes/destek.js`): konu 3-120, mesaj 10-4000 karakter,
/// başındaki/sonundaki boşluklar sayılmaz. Biri değişirse öteki de
/// değişmeli (`test/destek_talebi_test.dart` iki dosyayı karşılaştırır).
///
/// ⚠ Bu denetim YALNIZ kullanıcıya erken geri bildirimdir; GÜVENLİK
/// KONTROLÜ DEĞİLDİR. Asıl doğrulamayı sunucu yapar.
/// ═══════════════════════════════════════════════════════════════
const int kDestekKonuEnAz = 3;
const int kDestekKonuEnFazla = 120;
const int kDestekMesajEnAz = 10;
const int kDestekMesajEnFazla = 4000;

/// Konu uygunsa `null`, değilse alan uyarısı.
String? destekKonuHatasi(String? deger) {
  final t = (deger ?? '').trim();
  if (t.isEmpty) {
    return FormMesaj.zorunlu;
  }
  if (t.length < kDestekKonuEnAz) {
    return FormMesaj.destekKonuKisa;
  }
  if (t.length > kDestekKonuEnFazla) {
    return FormMesaj.destekKonuUzun;
  }
  return null;
}

/// Mesaj uygunsa `null`, değilse alan uyarısı.
String? destekMesajHatasi(String? deger) {
  final t = (deger ?? '').trim();
  if (t.isEmpty) {
    return FormMesaj.zorunlu;
  }
  if (t.length < kDestekMesajEnAz) {
    return FormMesaj.destekMesajKisa;
  }
  if (t.length > kDestekMesajEnFazla) {
    return FormMesaj.destekMesajUzun;
  }
  return null;
}
