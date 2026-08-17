enum TxKind { load, block, contact, refund }

class WalletTx {
  final String id;
  final TxKind kind;
  final String title, sub;
  final int amount; // TL; bloke/tüketim negatif, iade/yükleme pozitif
  /// İŞLEMİN GERÇEKLEŞTİĞİ AN.
  ///
  /// ⚠ ESKİDEN HER ZAMAN `DateTime.now()` İDİ ve dışarıdan
  /// verilemiyordu. Mock'ta işlem o anda üretildiği için sorun
  /// görünmüyordu; ama sunucudan gelen geçmiş hareketler de
  /// OKUNDUKLARI ana damgalanıyordu — yani cüzdan her açıldığında
  /// bütün işlemler "az önce olmuş" gibi görünürdü.
  ///
  /// Artık kaynak neyse o taşınır; verilmezse (yeni oluşturulan
  /// işlem) şimdiki zaman kullanılır.
  final DateTime time;
  WalletTx({
    required this.id,
    required this.kind,
    required this.title,
    required this.sub,
    required this.amount,
    DateTime? time,
  }) : time = time ?? DateTime.now();

  /// `18 Haziran 2026 · 14:35`
  ///
  /// ⚠ TEK SATIR, TEK YER. Ekran kendi biçimini kurmaz; para
  /// hareketinin ne zaman olduğu her yerde AYNI yazılır.
  ///
  /// ⚠ "2 saat önce" gibi göreli ifade KULLANILMAZ: cüzdan bir
  /// muhasebe kaydıdır, kullanıcı hangi gün ve saatte ne olduğunu
  /// KESİN görmelidir.
  String get zamanMetni =>
      '${time.day.toString().padLeft(2, '0')} ${_aylar[time.month - 1]} '
      '${time.year} · ${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  static const _aylar = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];
}

/// Hizmet veren cüzdanı. Müşteri HİÇBİR aşamada ödeme yapmaz,
/// dolayısıyla müşterilerin cüzdanı yoktur.
class Wallet {
  int avail;
  int blocked;
  final List<WalletTx> txs = [];
  Wallet({this.avail = 0, this.blocked = 0});   // production varsayılanı: boş cüzdan
}
