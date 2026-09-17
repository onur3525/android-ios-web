// ALTTAKİ ONAY UYARILARI KALDIRILDI — KİLİT
//
// ⚠ KULLANICI İSTEĞİ (9 Eyl): "Altta çıkan bilgilendirme yazılarını
// tamamen kaldır." Ekranın altında beliren "Adresiniz güncellendi ✓"
// türü ONAY şeritleri artık hiç çizilmez.
//
// ⚠ SINIR ÇİZGİSİ — HATA VE KURAL UYARILARI KALDIRILMADI: onlar
// bilgilendirme değil, kullanıcının bilmesi ZORUNLU geri
// bildirimlerdir. Susturulsalardı başarısız bir kayıt ya da izin
// vermeyen bir kural sessizce geçer, kullanıcı neden ilerleyemediğini
// anlayamazdı. Bu test o sınırı iki yönlü kilitler: onay YOK, hata
// VAR.
//
// ⚠ KAYNAK OKUNMAZ, EKRAN ÖLÇÜLÜR: "fonksiyon boş" demek yetmez;
// uyarının gerçekten çizilmediği `SnackBar` widget'ı aranarak
// doğrulanır.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/core/sys_state.dart';

void main() {
  /// Verilen çağrıyı bir düğmeye bağlar, düğmeye basar ve ekranda
  /// `SnackBar` kalıp kalmadığını döndürür.
  Future<bool> uyariCiktiMi(
      WidgetTester t, void Function(BuildContext) cagri) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (c) => Center(
            child: ElevatedButton(
              onPressed: () => cagri(c),
              child: const Text('ÇAĞIR'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('ÇAĞIR'));
    // ⚠ `pumpAndSettle` KULLANILMAZ: SnackBar kendi süresi dolana
    // kadar açık kalır ve `pumpAndSettle` zaman aşımına düşerdi.
    // Giriş animasyonunu bitirecek kadar tek tek ilerlenir.
    await t.pump();
    await t.pump(const Duration(milliseconds: 800));
    return find.byType(SnackBar).evaluate().isNotEmpty;
  }

  testWidgets('sysToastOk HİÇBİR ŞEY çizmez', (t) async {
    final cikti =
        await uyariCiktiMi(t, (c) => sysToastOk(c, 'Adresiniz güncellendi'));
    expect(cikti, isFalse, reason: 'onay uyarısı geri gelmiş');
    // ⚠ Metin de hiçbir yerde görünmemeli (✓ ekiyle birlikte).
    expect(find.textContaining('Adresiniz güncellendi'), findsNothing);
  });

  testWidgets('⚠ HATA UYARISI HÂLÂ ÇIKAR — sessiz hata YOK', (t) async {
    final cikti =
        await uyariCiktiMi(t, (c) => sysToastErr(c, SysKind.genericError));
    expect(cikti, isTrue,
        reason: 'hata uyarısı da susturulmuş — başarısız işlem '
            'kullanıcıya hiç bildirilmez');
  });

  testWidgets('⚠ KURAL UYARISI HÂLÂ ÇIKAR', (t) async {
    final cikti = await uyariCiktiMi(
        t, (c) => sysToastKural(c, 'Bu işlem için önce adres eklemelisiniz.'));
    expect(cikti, isTrue, reason: 'kural uyarısı susturulmuş');
    expect(find.textContaining('önce adres eklemelisiniz'), findsOneWidget);
  });

  testWidgets('sysToastOk çağrısı HATA ATMAZ', (t) async {
    // ⚠ Çağrı yerleri (33 adet, 21 dosya) SİLİNMEDİ; fonksiyon
    // susturuldu. Bu yüzden çağrının sessizce ve güvenle dönmesi
    // sözleşmenin parçasıdır.
    await uyariCiktiMi(t, (c) => sysToastOk(c, 'herhangi bir metin'));
    expect(t.takeException(), isNull);
  });
}
