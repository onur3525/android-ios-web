// KAZANILAN İŞ KARTI — HİZMET ALAN BİLGİLERİ (KİLİT)
//
// ⚠ KULLANICI İSTEĞİ (9 Eyl): "İlan Kazandığım ekranına taşındığında
// hizmet alan kart yapısı buraya olduğu gibi taşınmalı — hizmet
// alanın bilgileri vb."
//
// ⚠ ÖLÇÜLEN EKSİK: kartta hizmet adı, "Doğrudan Teklif İsteği",
// tutar ve "Seçildi"den başka bir şey yoktu. Hizmet veren, kazandığı
// işin KİME ait olduğunu ancak detaya girerek görebiliyordu. Ad,
// konum, tamamlanan iş ve üyelik bilgisi YALNIZ detay ekranında ve
// o dosyanın PRIVATE fonksiyonlarında hesaplanıyordu.
//
// ⚠ İKİNCİ BULGU (aynı ekran): listede bir kart dururken üstte
// "0 ilan bulundu" yazıyordu — sayaç `TeklifTalebi` bölümünü hiç
// saymıyordu.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/domain/hizmet_alan_ozeti.dart';

String _kodu(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  final jobs = _kodu('lib/screens/jobs_screen.dart');
  final detay = _kodu('lib/screens/teklif_talebi_detay_screen.dart');
  final satir = _kodu('lib/screens/widgets/hizmet_alan_ozet_satiri.dart');

  group('1 — KART HİZMET ALANI GÖSTERİR', () {
    test('⚠ HER İKİ KART TÜRÜ DE HİZMET ALANI GÖSTERİR', () {
      // Kullanıcı isteği (9 Eyl): "İlan oluşturma yolu ile gelen
      // kartlar da doğrudan teklif kartları gibi olsun."
      //
      // Önceden yalnız "Bul" akışından kazanılan kart bu bilgiyi
      // taşıyordu; ilan tabanlı kart yalnız başlık, adres, tutar ve
      // durum gösteriyordu.
      expect(RegExp(r'HizmetAlanOzetSatiri\(').allMatches(jobs).length, 2,
          reason: 'iki kart türünden biri hizmet alanı göstermiyor');
      expect(RegExp(r'hizmetAlanOzeti\(').allMatches(jobs).length, 2);
    });

    test('⚠ KAZANILAN İŞTE MASKELEME YOK', () {
      // Bu ekran kabul edilmiş işleri listeler; kimlik zaten açık.
      expect(jobs.contains('maskeli: false'), isTrue);
    });

    test('⚠ MAHALLE GÖSTERİLİR', () {
      // Hizmet veren işin NEREDE olduğunu bilmek zorunda; ilçe tek
      // başına yetmiyor. İlan tabanlı kart mahalleyi zaten
      // gösteriyordu, özet göstermiyordu — aynı ekranda iki farklı
      // ayrıntı düzeyi vardı.
      final o = _kodu('lib/domain/hizmet_alan_ozeti.dart');
      expect(o.contains('konumMetni(adres, mahalleDahil: true)'), isTrue);
    });

    test('ad, konum, tamamlanan iş ve üyelik çizilir', () {
      expect(satir.contains('ozet.adSoyad'), isTrue);
      expect(satir.contains('ozet.konum'), isTrue);
      expect(satir.contains('iş tamamladı'), isTrue);
      expect(satir.contains('ozet.uyelikMetni'), isTrue);
    });

    test('⚠ PROFİL FOTOĞRAFI YOK (kullanıcı isteği, 10 Eyl)', () {
      // Solda 38 px'lik avatar çiziliyordu (maskeliyken kilit ikonu,
      // açıkken baş harf). Yazılar artık kartın sol kenarından
      // başlıyor.
      //
      // ⚠ `maskeli` parametresi KALDI: adın maskelenip
      // maskelenmeyeceğini hâlâ o belirliyor; giden yalnız avatar.
      expect(satir.contains('RefBasHarfAvatar'), isFalse);
      expect(satir.contains('ic_avlock'), isFalse);
      expect(satir.contains('this.maskeli'), isTrue);
    });

    test('⚠ PUAN/YORUM YOK', () {
      // Değerlendirme yalnız hizmet verene yapılır; buraya yıldız
      // koymak olmayan bir veriyi varmış gibi gösterirdi.
      expect(satir.contains('ic_starfill'), isFalse);
      expect(satir.contains('yorum'), isFalse);
    });
  });

  group('2 — HESAPLAMA TEK KAYNAKTA', () {
    test('detay ekranı ortak fonksiyona delege eder', () {
      expect(detay.contains('hizmetAlanTamamlananIs(c, hizmetAlanId)'), isTrue);
      expect(detay.contains('uyelikTarihiMetni(tarih)'), isTrue);
      // Ay adları listesi artık burada olmamalı.
      expect(detay.contains('_kAyAdlari'), isFalse,
          reason: 'üyelik metni kopyası geri gelmiş');
    });

    test('üyelik metni biçimi', () {
      expect(uyelikTarihiMetni(DateTime(2026, 9, 10)),
          "Eylül 2026'ten beri üye");
      expect(uyelikTarihiMetni(DateTime(2025, 1, 3)),
          "Ocak 2025'ten beri üye");
    });
  });

  group('3 — TUTAR VE SAYAÇ', () {
    test('⚠ İKİ KART DA ORTAK TUTAR BİÇİMİNİ KULLANIR', () {
      // Aynı ekranda "₺5000" ve "3.000 TL" yan yana duruyordu.
      expect(jobs.contains('tutarMetni(t.teklifFiyati ?? 0)'), isTrue);
      expect(jobs.contains('tutarMetni(o.amount)'), isTrue);
      expect(jobs.contains('tl(t.teklifFiyati'), isFalse);
      expect(jobs.contains('tl(o.amount)'), isFalse);
    });

    test('⚠ TUTAR RENGİ VE ÖLÇÜSÜ İKİ KARTTA DA AYNI', () {
      // ── ⚠ KULLANICI BULGUSU (12 Eyl) ──
      //
      // İki kart aynı bilgiyi (hizmet verenin KENDİ verdiği tutar)
      // farklı renkte gösteriyordu: ilan tabanlı kart mavi, doğrudan
      // teklif kartı koyu. Alt alta duran iki kart arasında olmayan
      // bir anlam farkı sezdiriyordu.
      //
      // ⚠ KİLİT STİLİN KENDİSİNE DEĞİL, TEK KAYNAK OLMASINA: iki
      // çağrı da aynı sabiti okumalı. Renk ileride değişirse tek
      // yerde değişir.
      expect(jobs.contains('const TextStyle _kKazanilanTutarStili'), isTrue,
          reason: 'ortak tutar stili tanımlı değil');
      expect(
          RegExp(r'style:\s*_kKazanilanTutarStili').allMatches(jobs).length, 2,
          reason: 'iki karttan biri ortak stili kullanmıyor');
      // Kart içinde elle yazılmış tutar stili kalmamalı.
      expect(
          RegExp(r'tutarMetni\([^)]*\),\s*style:\s*const TextStyle\(')
              .hasMatch(jobs),
          isFalse,
          reason: 'tutar stili yine kart içinde elle yazılmış');
    });

    test('⚠ "SEÇİLDİ" ROZETİ YOK (kullanıcı isteği, 12 Eyl)', () {
      // Rozet bilgi taşımıyordu: bu sekme ZATEN "Kazandığım".
      // Üstelik yalnız doğrudan teklif kartında vardı; iki kart aynı
      // durumu farklı anlatıyordu. Aynı gerekçeyle "Aktif" rozeti de
      // 10 Eyl'de kaldırılmıştı.
      expect(jobs.contains("StatusChip('Seçildi'"), isFalse,
          reason: 'Seçildi rozeti geri gelmiş');
    });

    test('⚠ SIRALAMA İKİ TÜRÜ BİRLİKTE DİZER', () {
      // ── ⚠ KULLANICI BULGUSU (12 Eyl): "sıralama çalışmıyor" ──
      //
      // Sıralama YALNIZ `myOffers`a uygulanıyordu; `secilenTalepler`
      // hiç sıralanmıyor ve liste iki bölüm hâlinde çiziliyordu —
      // önce bütün teklifler, sonra bütün talepler. "Düşük tutarlı
      // üstte" seçiliyken 6.000 TL'lik teklif, 4.000 TL'lik talebin
      // ÜSTÜNDE kalıyordu: ölçüt doğru uygulanıyordu ama TÜR SINIRINI
      // geçemiyordu.
      //
      // ⚠ KİLİT TEK LİSTEYE: iki tür tek listede sıralanmalı.
      expect(jobs.contains('final kazanilanlar ='), isTrue,
          reason: 'birleşik liste kurulmamış');
      expect(jobs.contains('kazanilanlar.sort('), isTrue);
      expect(jobs.contains('myOffers.sort('), isFalse,
          reason: 'sıralama yine yalnız tekliflere uygulanıyor');
      expect(jobs.contains('itemCount: kazanilanlar.length'), isTrue,
          reason: 'liste yine iki bölüm hâlinde çiziliyor');
      // İndeks aritmetiğiyle bölümleme geri gelmemeli.
      expect(jobs.contains('i - myOffers.length'), isFalse);
    });

    test('⚠ TARİH ÖLÇÜTÜ İKİ TÜRDE DE TEKLİF ANIDIR', () {
      // Talepte `createdAt` TALEBİN açılma tarihidir, teklifin değil.
      // İki türü farklı anlamda iki tarihle sıralamak listeyi sessizce
      // yanlış dizerdi.
      expect(jobs.contains('t.teklifTarihi ?? t.createdAt'), isTrue);
    });

    test('⚠ SAYAÇ KAZANILAN TALEPLERİ DE SAYAR', () {
      // ⚠ SAYAÇ ARTIK BİRLEŞİK LİSTEDEN OKUR: iki türü ayrı ayrı
      // toplamak yerine tek kaynağın uzunluğu kullanılır.
      expect(jobs.contains('kazanilanlar.length'), isTrue,
          reason: 'listede kart varken "0 ilan bulundu" yazılır');
    });
  });
}
