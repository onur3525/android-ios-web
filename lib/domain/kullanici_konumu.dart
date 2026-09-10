import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../data/controllers/auth_controller.dart';
import '../data/models/account.dart';

/// ── ⚠ KONUM METNİ — TEK KAYNAK ──
///
/// KULLANICI KURALI (9 Eyl): "Kullanıcının profilinde veya kayıt
/// olurken girdiği adres bilgileri, bağlı olduğu TÜM kartlarda aynı
/// olmalı; adres değişince buna bağlı olarak otomatikman tüm bilgiler
/// değişmeli."
///
/// ⚠ ÖLÇÜLEN İKİ AYRI SAPMA:
///
///   1. BİÇİM FARKI — bazı kartlar "Karşıyaka / İzmir", bazıları
///      "Örnekköy, Karşıyaka / İzmir" yazıyordu. Aynı kişi iki kartta
///      farklı görünüyordu, çünkü her ekran metni kendi kuruyordu.
///
///   2. DONMUŞ KOPYA — `Listing.location` ilan OLUŞTURULURKEN bir
///      metin olarak yazılıp saklanıyor. Kullanıcı sonradan adresini
///      değiştirdiğinde ilan kartı ESKİ adresi göstermeye devam
///      ediyordu; profil güncel, kart eski.
///
/// Bu dosya konumu hesabın GÜNCEL adresinden üretir. Adres
/// değiştiğinde ona bağlı kartların hepsi aynı anda değişir.
///
/// ⚠ `Listing.location` SİLİNMEDİ: sunucu sözleşmesinde duruyor ve
/// ilan gönderiminde taşınıyor. Değişen yalnız EKRANDA GÖSTERİLEN
/// değerin kaynağı.
///
/// ⚠ AÇIK KONU — İŞİN ADRESİ vs EV ADRESİ: bugün ilan formu konumu
/// kullanıcının kayıtlı adresinden dolduruyor, yani ikisi aynı.
/// İleride "başka bir adres için ilan ver" gibi bir ihtiyaç doğarsa
/// bu kural yeniden konuşulmalı; o zaman `Listing` kendi adresini
/// TAŞIMALI ve burası yalnız KİŞİ kartlarında kullanılmalı.

/// "Örnekköy, Karşıyaka / İzmir" (mahalleli) ya da
/// "Karşıyaka / İzmir" (mahallesiz).
///
/// ⚠ BOŞ ALANLAR ATLANIR: mahalle girilmemişse başta virgül,
/// il boşsa sonda eğik çizgi kalmaz.
String? konumMetni(Address? adres, {bool mahalleDahil = false}) {
  if (adres == null) {
    return null;
  }
  final ilce = adres.district.trim();
  final il = adres.city.trim();
  final mahalle = adres.neighborhood.trim();
  if (ilce.isEmpty && il.isEmpty) {
    return null;
  }
  final govde = (ilce.isEmpty || il.isEmpty) ? '$ilce$il' : '$ilce / $il';
  if (!mahalleDahil || mahalle.isEmpty) {
    return govde;
  }
  return '$mahalle, $govde';
}

/// Bir kullanıcının GÜNCEL konumu.
///
/// ⚠ `watch` DEĞİL `read`: çağıran ekranlar zaten `AuthController`ı
/// izliyor; burada ikinci bir abonelik kurmak gereksiz yeniden çizim
/// üretirdi. Adres değişikliği hesabı güncellediği için kartlar yine
/// tazelenir.
///
/// Hesap ya da adres yoksa `null` döner — satır çizilmez, yaklaşık
/// bir konum UYDURULMAZ.
String? kullaniciKonumu(
  BuildContext context,
  String? userId, {
  bool mahalleDahil = false,
}) {
  if (userId == null) {
    return null;
  }
  final hesap = context.read<AuthController>().accountById(userId);
  return konumMetni(hesap?.address, mahalleDahil: mahalleDahil);
}
