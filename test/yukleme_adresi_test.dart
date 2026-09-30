import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/remote/yukleme_adresi.dart';

/// DOSYA YÜKLEME ADRESİ — https + izinli alan + SigV4 imza
/// (güvenlik turu 2 · M-03)
void main() {
  final simdi = DateTime.utc(2026, 9, 30, 12, 0, 0);
  const izinli = ['.r2.cloudflarestorage.com', 'medya.hizmetcep.com'];

  String adres({
    String sema = 'https',
    String host = 'hesap.r2.cloudflarestorage.com',
    String tarih = '20260930T115500Z',
    String sure = '900',
    bool imza = true,
  }) =>
      '$sema://$host/kova/nesne.jpg?X-Amz-Algorithm=AWS4-HMAC-SHA256'
      '&X-Amz-Credential=abc%2F20260930%2Fauto%2Fs3%2Faws4_request'
      '&X-Amz-Date=$tarih&X-Amz-Expires=$sure&X-Amz-SignedHeaders=host'
      '${imza ? '&X-Amz-Signature=deadbeef' : ''}';

  String? d(String a, {List<String> liste = izinli, bool release = true}) =>
      YuklemeAdresi.denetle(a, simdi: simdi, izinli: liste, release: release);

  test('geçerli imzalı https adresi kabul', () {
    expect(d(adres()), isNull);
    expect(d(adres(host: 'medya.hizmetcep.com')), isNull);
  });

  test('düz http reddedilir', () {
    expect(d(adres(sema: 'http')), isNotNull);
  });

  test('izinli olmayan alan reddedilir (sonek taklidi dahil)', () {
    expect(d(adres(host: 'kotu.example.com')), isNotNull);
    expect(d(adres(host: 'r2.cloudflarestorage.com.kotu.com')), isNotNull);
    expect(d(adres(host: 'xmedya.hizmetcep.com')), isNotNull);
  });

  test('imzasız adres reddedilir', () {
    expect(d(adres(imza: false)), isNotNull);
  });

  test('süresi dolmuş ya da 7 günden uzun imza reddedilir', () {
    expect(d(adres(tarih: '20260930T100000Z', sure: '900')), isNotNull);
    expect(d(adres(sure: '604801')), isNotNull);
    expect(d(adres(tarih: 'bozuk')), isNotNull);
  });

  test('kullanıcı bilgisi / parça içeren adres reddedilir', () {
    expect(d(adres(host: 'u:p@hesap.r2.cloudflarestorage.com')), isNotNull);
    expect(d('${adres()}#x'), isNotNull);
  });

  test('liste boşsa: release REDDEDER, debug yalnız https+imza ister', () {
    expect(d(adres(), liste: const [], release: true), isNotNull);
    expect(d(adres(host: 'herhangi.example.com'), liste: const [], release: false),
        isNull);
    expect(d(adres(sema: 'http'), liste: const [], release: false), isNotNull);
  });
}
