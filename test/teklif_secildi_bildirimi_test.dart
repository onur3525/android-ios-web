// TEKLİF SEÇİLDİ BİLDİRİMİ — İKİ AKIŞTA TEK METİN (KİLİT)
//
// ⚠ ÜRÜN KARARI (12 Eyl, kullanıcı): "Teklif seçildiğinde, Bul ile
// veya ilan oluşturmayla farketmeksizin 'Teklifiniz seçildi 🎉'
// olarak bildirim gelmeli. 'Teklifiniz kabul edildi' kabul
// etmiyorum."
//
// ⚠ ÖNCEKİ DURUM: aynı olay iki portta ayrı ayrı yazılmıştı.
//   · `mock_ports`        → "Teklifiniz seçildi 🎉"
//   · `teklif_talebi_port` → "Teklifiniz kabul edildi"
//
// Hizmet veren için olay AYNI: verdiği teklif kabul edildi, iş
// başladı. Bildirim listesinde iki başlık alt alta düşünce iki farklı
// şey olmuş izlenimi veriyordu.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/domain/bildirim_metinleri.dart';

String _kod(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) =>
        !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
    .join('\n');

void main() {
  group('1 — ⚠ METİN TEK KAYNAKTA', () {
    test('başlık ve gövde domain katmanında', () {
      expect(kTeklifSecildiBaslik, 'Teklifiniz seçildi 🎉');
      expect(teklifSecildiGovde('Doğalgaz Kaçak Tespiti'),
          '"Doğalgaz Kaçak Tespiti" işinde hizmet alan sizinle '
          'çalışmak istiyor.');
    });

    test('⚠ EMOJİ BAŞLIĞIN PARÇASI', () {
      // Kutlama tonu ürün kararıdır, süs değil. Ayrı bir "emoji ekle"
      // adımı yoktur.
      expect(kTeklifSecildiBaslik.contains('🎉'), isTrue);
    });
  });

  group('2 — ⚠ PORTLAR KENDİ METNİNİ YAZMAZ', () {
    const portlar = <String>[
      'lib/data/ports/mock_ports.dart',
      'lib/data/ports/teklif_talebi_port.dart',
    ];

    test('ikisi de ortak sabiti kullanır', () {
      for (final yol in portlar) {
        final k = _kod(yol);
        expect(k.contains('title: kTeklifSecildiBaslik'), isTrue, reason: yol);
        expect(k.contains('body: teklifSecildiGovde('), isTrue, reason: yol);
      }
    });

    test('⚠ ELLE YAZILMIŞ SEÇİLDİ METNİ KALMADI', () {
      // ⚠ KAPSAM DAR TUTULUR: portlarda başka bildirim başlıkları da
      // var. Geniş bir "title: '" araması onları da yakalar ve
      // ilgisiz kuralları kilitlerdi.
      for (final yol in portlar) {
        final k = _kod(yol);
        expect(k.contains("title: 'Teklifiniz seçildi"), isFalse,
            reason: '$yol: başlık yine elle yazılmış');
      }
    });

    test('⚠ "kabul edildi" VARYANTI GERİ GELMEZ', () {
      // Kullanıcı bu ifadeyi açıkça reddetti.
      for (final yol in portlar) {
        expect(_kod(yol).contains('Teklifiniz kabul edildi'), isFalse,
            reason: yol);
      }
    });
  });

  group('3 — ⚠ YENİ TEKLİF: TEK BAŞLIK', () {
    // ── ⚠ ÜRÜN KARARI (12 Eyl, kullanıcı) ──
    //
    // "'Teklifiniz geldi' farklı bir dil, bunu kabul etmiyorum.
    // 'Yeni teklif aldınız' olarak yazılmalı. Bul veya ilan
    // oluşturmayla nereden gelirse gelsin."
    //
    // ⚠ ESKİ BAŞLIK AYRICA YANILTICIYDI: bildirimi alan hizmet
    // ALANDIR, teklifi o vermemiştir. "Teklifiniz" iyelik eki karşı
    // tarafın teklifini okuyana aitmiş gibi gösteriyordu.

    test('başlık ortak sabitte', () {
      expect(kYeniTeklifBaslik, 'Yeni teklif aldınız');
    });

    test('iki port da ortak başlığı kullanır', () {
      for (final yol in const [
        'lib/data/ports/mock_ports.dart',
        'lib/data/ports/teklif_talebi_port.dart',
      ]) {
        final k = _kod(yol);
        expect(k.contains('title: kYeniTeklifBaslik'), isTrue, reason: yol);
        expect(k.contains("title: 'Teklifiniz geldi'"), isFalse, reason: yol);
      }
    });

    test('⚠ GÖVDELER AYRI KALIR — BAŞLIK ORTAK', () {
      // İlan akışında henüz fiyat okunmadan bildirim gider, Bul
      // akışında teklif fiyatla birlikte gelir. Gövdeyi de zorla
      // eşitlemek, Bul akışındaki fiyat bilgisini SİLMEK olurdu.
      expect(yeniTeklifGovdeIlan('Doğalgaz Kaçak Onarımı'),
          '"Doğalgaz Kaçak Onarımı" ilanınıza yeni bir teklif geldi.');
      expect(yeniTeklifGovdeTalep('Doğalgaz Kaçak Kontrolü', 5500),
          '"Doğalgaz Kaçak Kontrolü" talebiniz için 5500 TL teklif '
          'aldınız.');
    });
  });

  group('4 — ⚠ "İş tamamlandı" BİLDİRİMİ GÖNDERİLMEZ', () {
    // ── ⚠ KULLANICI İSTEĞİ (12 Eyl) ──
    //
    // "Hizmet alan bildirimlerde iş tamamlandı bildirimi gereksiz,
    // gelmesin."
    //
    // Hizmet alan işin bittiğini zaten görüyor: talep detayında
    // "Yorum Yaz" düğmesi beliriyor ve kart "Tamamlanan işler"e
    // geçiyor. Bildirim üçüncü kez aynı şeyi söylüyordu.

    test('Bul akışı tamamlamada bildirim üretmez', () {
      final k = _kod('lib/data/ports/teklif_talebi_port.dart');
      expect(k.contains("title: 'İş tamamlandı'"), isFalse);
      expect(k.contains('NotifType.teklifIsiTamamlandi'), isFalse,
          reason: 'bildirim geri gelmiş');
    });

    test('⚠ TAMAMLAMA İŞLEMİNİN KENDİSİ DEĞİŞMEDİ', () {
      // Kalkan yalnız bildirimdir; durum güncellemesi ve sayaç
      // artışı yerinde.
      final k = _kod('lib/data/ports/teklif_talebi_port.dart');
      expect(k.contains('tamamlananIsArtir(t.saglayiciId)'), isTrue);
    });

    test('⚠ BİLDİRİM TÜRÜ SİLİNMEDİ', () {
      // Geçmişte gönderilmiş bildirimler hâlâ o türle kayıtlı; tür
      // kalkarsa eski kayıtlar çözümlenemez.
      final m = _kod('lib/data/models/notification.dart');
      expect(m.contains('teklifIsiTamamlandi'), isTrue);
    });

    test('⚠ İLAN AKIŞINDA ZATEN YOKTU — iki akış artık eşit', () {
      final k = _kod('lib/data/ports/mock_ports.dart');
      expect(k.contains("title: 'İş tamamlandı'"), isFalse);
    });
  });

  group('5 — ⚠ MESAJ BİLDİRİMİ: TEK DİL', () {
    // ── ⚠ ÜRÜN KARARI (12 Eyl, kullanıcı) ──
    //
    // "Mesaj bildirimlerini aynı dille yap, birleştir."
    //
    // İki port aynı olayı iki ayrı biçimde anlatıyordu:
    //   · ilan akışı → "Yeni mesajınız var" / "Sohbette yeni bir
    //                   mesaj aldınız."
    //   · Bul akışı  → "Yeni mesaj" / mesajın kendisi

    test('başlık ve gövde ortak kaynakta', () {
      expect(kYeniMesajBaslik, 'Yeni mesaj');
      expect(yeniMesajGovde('yarın uygun musunuz'), 'yarın uygun musunuz');
    });

    test('⚠ GÖVDE MESAJIN İÇERİĞİDİR', () {
      // "Sohbette yeni bir mesaj aldınız." hiçbir şey söylemiyordu;
      // kullanıcı ne geldiğini görmek için sohbeti açmak zorundaydı.
      expect(yeniMesajGovde(null), 'Fotoğraf gönderildi.');
      expect(yeniMesajGovde('   '), 'Fotoğraf gönderildi.',
          reason: 'boş metin fotoğraf sayılmalı');
    });

    test('iki port da ortak metni kullanır', () {
      for (final yol in const [
        'lib/data/ports/mock_ports.dart',
        'lib/data/ports/teklif_talebi_port.dart',
      ]) {
        final k = _kod(yol);
        expect(k.contains('title: kYeniMesajBaslik'), isTrue, reason: yol);
        expect(k.contains('yeniMesajGovde('), isTrue, reason: yol);
      }
      final m = _kod('lib/data/ports/mock_ports.dart');
      expect(m.contains('Yeni mesajınız var'), isFalse);
      expect(m.contains('Sohbette yeni bir mesaj'), isFalse);
    });
  });

  group('6 — ⚠ KALDIRILAN BİLDİRİMLER', () {
    test('"İletişim açıldı" gönderilmez', () {
      // Haber değeri düşüktü: açan taraf ne yaptığını biliyor, karşı
      // taraf ekranda numarayı ve mesaj düğmesini görüyor.
      final m = _kod('lib/data/ports/mock_ports.dart');
      expect(m.contains("title: 'İletişim açıldı'"), isFalse);
      expect(m.contains('NotifType.contactOpened'), isFalse);
    });

    test('⚠ İLETİŞİMİ AÇMA İŞLEMİ DEĞİŞMEDİ', () {
      // Kalkan yalnız bildirimdir.
      final m = _kod('lib/data/ports/mock_ports.dart');
      expect(m.contains('contacts.open(offerId)'), isTrue);
    });

    test('⚠ RED/İPTALDE HİÇ BİLDİRİM GÖNDERİLMEZ', () {
      // İki bildirim de kaldırıldı (12 Eyl, kullanıcı isteği):
      //   · "Teklifiniz reddedildi" — hizmet veren sonucu zaten
      //     görüyor; kart ve detay "Reddedildi" durumuna geçiyor.
      //   · "Talep iptal edildi" — teklif verilmeden iptal edilen
      //     talepler için gidiyordu.
      final t = _kod('lib/data/ports/teklif_talebi_port.dart');
      expect(t.contains("title: 'Teklifiniz reddedildi'"), isFalse);
      expect(t.contains("title: 'Talep iptal edildi'"), isFalse);
      // ⚠ Bu tür artık hiçbir yerde ÜRETİLMEZ.
      expect(t.contains('NotifType.teklifReddedildi'), isFalse);
    });

    test('⚠ RED İŞLEMİNİN KENDİSİ DEĞİŞMEDİ', () {
      // Kalkan yalnız bildirimdir; talep `reddedildi` durumuna
      // geçmeye devam eder ve ekranlar bunu gösterir.
      final t = _kod('lib/data/ports/teklif_talebi_port.dart');
      expect(t.contains('_repo.reddet(id, gerekce: gerekce)'), isTrue);
    });

    test('⚠ ÖLÜ DEĞİŞKEN BIRAKILMADI', () {
      // `oncekiDurum` ve `teklifVerilmisti` yalnız bildirim METNİNİ
      // seçmek için vardı. Ölü kalsalardı bildirim hâlâ
      // gönderiliyormuş izlenimi verirlerdi.
      final t = _kod('lib/data/ports/teklif_talebi_port.dart');
      expect(t.contains('teklifVerilmisti'), isFalse);
    });

    test('⚠ BİLDİRİM TÜRLERİ SİLİNMEDİ', () {
      // Geçmiş kayıtlar hâlâ bu türlerle kayıtlı; tür kalkarsa eski
      // bildirimler çözümlenemez ve yönlendirmeleri kırılır.
      // ⚠ İKİSİ DE ARTIK ÜRETİLMİYOR ama TÜR olarak duruyor: geçmişte
      // gönderilmiş bildirimler bu türlerle kayıtlı ve
      // yönlendirmeleri çalışıyor.
      final n = _kod('lib/data/models/notification.dart');
      expect(n.contains('contactOpened'), isTrue);
      expect(n.contains('teklifReddedildi'), isTrue);
    });
  });

  group('7 — ⚠ İKİ AKIŞ AYNI OLAYI AYNI ANLATIR', () {
    test('ilan akışı ilan başlığını, Bul akışı hizmet adını geçirir', () {
      // İki alan farklı ama kullanıcı için ikisi de "iş"tir.
      final m = _kod('lib/data/ports/mock_ports.dart');
      final t = _kod('lib/data/ports/teklif_talebi_port.dart');
      expect(m.contains('teklifSecildiGovde(l.title)'), isTrue);
      expect(t.contains('teklifSecildiGovde(t.hizmet)'), isTrue);
    });

    test('bildirim türü her iki akışta da korunur', () {
      // Tür ROTALAMA için kullanılır; metin eşitlendi diye tür
      // birleştirilmedi — iki akış farklı ekrana gider.
      final m = _kod('lib/data/ports/mock_ports.dart');
      final t = _kod('lib/data/ports/teklif_talebi_port.dart');
      expect(m.contains('NotifType.offerSelected'), isTrue);
      expect(t.contains('NotifType.teklifSecildi'), isTrue);
    });
  });
}
