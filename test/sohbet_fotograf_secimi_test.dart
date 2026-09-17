// SOHBET FOTOĞRAFI — ÇOKLU SEÇİM, ÖNİZLEME YOK (KİLİT)
//
// ⚠ KULLANICI KARARI (16 Eyl): "Önizleme olmasın, çoklu seçim yapılıp
// yüklensin; zaten gönderilen mesajlar tıklandığında büyük ekran
// oluyor."
//
// ── ⚠ BULGUNUN ASLI ──
//
// Kullanıcı "hizmet veren galeriden tek tek seçemiyor, seçtiği
// görüntü tam ekran büyüyor" diye bildirdi. Kodda ROL AYRIMI YOKTU:
// `chat_screen` ve `teklif_talebi_sohbet_screen` aynı fonksiyonu
// çağırıyor, iki taraf da aynı ekranı görüyordu. Gerçek fark
// MESAJLAŞMA ile İLAN OLUŞTURMA arasındaydı: ilan seçicisi
// `pickMultiImage` ile çoklu seçim yapıyor, sohbet ise `pickImage`
// ile tek fotoğraf alıp tam ekran önizleme açıyordu.
//
// ⚠ BU TEST ROL AYRIMININ GERİ GELMEMESİNİ DE KİLİTLER: akışa
// `benSaglayiciMi` benzeri bir dallanma girerse iki taraf yeniden
// ayrışır.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _kod(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  final akis = _kod('lib/screens/widgets/sohbet_fotograf_akisi.dart');
  final ilan = _kod('lib/screens/chat_screen.dart');
  final bul = _kod('lib/screens/teklif_talebi_sohbet_screen.dart');

  group('1 — ⚠ GALERİDE ÇOKLU SEÇİM', () {
    test('galeri `pickMultiImage` kullanır', () {
      expect(akis.contains('pickMultiImage('), isTrue);
    });

    test('⚠ KAMERA TEK KARE KALIR', () {
      // `pickMultiImage` yalnız galeri içindir; kamera zaten tek kare
      // çeker.
      expect(akis.contains('source: ImageSource.camera'), isTrue);
    });

    test('⚠ VAZGEÇİLİRSE BOŞ LİSTE — `null` DEĞİL', () {
      // Çağıran taraf her hâlükârda listenin üzerinde döner; `null`
      // kontrolü fazladan bir dal olurdu.
      expect(akis.contains('Future<List<String>> sohbetFotograflariSec'),
          isTrue);
      expect(akis.contains('return const [];'), isTrue);
    });
  });

  group('2 — ⚠ ÖNİZLEME EKRANI KALDIRILDI', () {
    test('önizleme sınıfı yok', () {
      expect(akis.contains('_FotografOnizleEkrani'), isFalse,
          reason: 'tam ekran önizleme geri gelmiş');
      expect(akis.contains('Navigator.of(context).push'), isFalse);
    });

    test('⚠ AÇIKLAMA ALANI DA GİTTİ', () {
      // Önizlemeyle birlikte kalktı; kullanıcı açıklamayı sohbetin
      // kendi metin kutusuna yazar ve fotoğrafla aynı mesajda gider.
      expect(akis.contains('aciklama'), isFalse);
    });
  });

  group('3 — ⚠ İKİ SOHBET EKRANI AYNI AKIŞI KULLANIR', () {
    test('ikisi de ortak fonksiyonu çağırır', () {
      for (final e in {'ilan': ilan, 'bul': bul}.entries) {
        expect(e.value.contains('sohbetFotograflariSec(context)'), isTrue,
            reason: e.key);
      }
    });

    test('⚠ ROL AYRIMI YOK', () {
      // Akış dosyasında rolü sorgulayan tek bir satır bile olmamalı;
      // kullanıcının bildirdiği "iki taraf farklı davranıyor" algısı
      // buradan doğsaydı gerçek bir hata olurdu.
      expect(akis.contains('benSaglayiciMi'), isFalse);
      expect(akis.contains('Role.'), isFalse);
    });

    test('⚠ KAYNAK PANELİ ORTAK BİLEŞENDEN', () {
      // "Fotoğraf Çek / Galeriden Seç" paneli ilan oluşturma
      // ekranlarındakiyle aynı bileşendir.
      expect(akis.contains('fotografKaynagiSec(context)'), isTrue);
    });
  });

  group('4 — ⚠ GÖNDERİM SIRAYLA', () {
    test('her fotoğraf ayrı mesaj olarak sırayla gider', () {
      // Sohbet modeli mesaj başına TEK görsel taşır. Paralel gönderim
      // mesaj sırasını bozar; sohbette sıra anlamın parçasıdır.
      for (final e in {'ilan': ilan, 'bul': bul}.entries) {
        expect(e.value.contains('for (final yol in yollar)'), isTrue,
            reason: e.key);
      }
      expect(ilan.contains('await _send(imagePath: yol)'), isTrue);
      expect(bul.contains('await _gonder(fotografYolu: yol)'), isTrue);
    });

    test('⚠ DÖNGÜ İÇİNDE `mounted` DENETİMİ', () {
      // Çok fotoğrafta gönderim uzun sürer; kullanıcı bu arada
      // ekrandan çıkabilir. Denetim olmadan `context` çöker.
      for (final e in {'ilan': ilan, 'bul': bul}.entries) {
        expect(e.value.contains('if (!mounted)'), isTrue, reason: e.key);
      }
    });
  });
}
