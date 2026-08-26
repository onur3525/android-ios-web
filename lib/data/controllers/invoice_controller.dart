import 'package:flutter/foundation.dart';
import '../../domain/failures.dart';
import '../remote/api_error_mapper.dart';

import '../models/invoice.dart';

/// FATURA LİSTESİ — SALT OKUNUR, BİLGİ AMAÇLI.
///
/// ⚠ Uygulama fatura ÜRETMEZ, DÜZENLEMEZ, SİLMEZ. Belgeler admin ve
/// muhasebe tarafında oluşturulur; buraya yalnız görüntülenmek üzere
/// gelir. Bu yüzden burada `create`/`update`/`delete` yoktur.
///
/// ⚠ Tahsilat ÖNCEDEN yapılmıştır (bkz. `Invoice` notu); burada
/// ödeme durumu veya borç takibi bulunmaz.
///
/// ⚠ MOCK MODDA tohumlanmış örnek belgeler gösterilir; gerçek modda
/// liste `GET /invoices/mine` ucundan gelir (bkz. `yukle`).
class InvoiceController extends ChangeNotifier {
  List<Invoice> _items = const [];
  bool _yukleniyor = false;
  /// ── ⚠ HATANIN TÜRÜ SAKLANIR ──
  ///
  /// Yalnız metin saklanınca ağ sorunu, sunucu arızası ve oturum
  /// düşmesi aynı cümleye düşüyordu. Tür saklanınca ekran doğru
  /// başlığı ve doğru eylemi merkezden alır.
  DomainError? _lastError;

  List<Invoice> get items => _items;
  bool get yukleniyor => _yukleniyor;
  DomainError? get lastError => _lastError;

  /// Eski sözleşme — metin isteyen çağıranlar için.
  String? get hata => _lastError?.message;

  /// ⚠ "Ödenmemiş fatura" KAVRAMI YOKTUR: tahsilat iletişim
  /// açılışında cüzdandan zaten yapılır. Fatura yalnız bilgi
  /// belgesidir.

  /// Listeyi doldurur.
  ///
  /// [getir] gerçek uçtan çekim yapan işlevdir; verilmezse mock tohum
  /// kullanılır. Böylece ekran her iki modda da AYNI kodu çalıştırır.
  Future<void> yukle({
    Future<List<Invoice>> Function()? getir,
  }) async {
    _yukleniyor = true;
    _lastError = null;
    notifyListeners();
    try {
      _items = getir == null ? _mockTohum() : await getir();
      // Yeniden eskiye.
      _items.sort((a, b) => b.donem.compareTo(a.donem));
    } on ApiFailure catch (e) {
      // ⚠ Sunucunun sınıflandırdığı hata KORUNUR (ağ / sunucu / yetki).
      _lastError = e.error;
    } catch (_) {
      _lastError = const NetworkError('Sunucuya ulaşılamıyor');
    }
    _yukleniyor = false;
    notifyListeners();
  }

  /// ⚠ YALNIZ MOCK. Gerçek belgeler muhasebeden gelir.
  List<Invoice> _mockTohum() {
    final simdi = DateTime.now();
    // ⚠ Fatura, ay içinde açılan iletişimlerin TOPLAMIDIR. Tutar
    // `adet × iletişim ücreti` ile tutarlı üretilir; uydurma bir
    // rakam kullanılmaz.
    const birimKurus = 5000; // 50,00 TL — `DomainConfig.contactFee`
    Invoice ay(int geri, int adet) {
      final d = DateTime(simdi.year, simdi.month - geri, 1);
      return Invoice(
        id: 'inv-${d.year}-${d.month}',
        no: 'HC-${d.year}-${(1000 + d.month * 7).toString()}',
        donem: d,
        // Belge, dönem KAPANDIKTAN sonra düzenlenir.
        tarih: DateTime(d.year, d.month + 1, 5),
        kurus: adet * birimKurus,
        islemAdedi: adet,
      );
    }

    return [ay(1, 3), ay(2, 5), ay(3, 2)];
  }
}
