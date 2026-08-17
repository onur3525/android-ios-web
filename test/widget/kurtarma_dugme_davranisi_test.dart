import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/core/theme.dart';
import 'package:hizmetcep/data/controllers/auth_controller.dart';
import 'package:hizmetcep/data/ports/mock_ports.dart';
import 'package:hizmetcep/data/repositories/auth_repository.dart';
import 'package:hizmetcep/screens/forgot_password_screen.dart';
import 'package:hizmetcep/ui/ref_widgets.dart';
import 'package:provider/provider.dart';

/// ŞİFREMİ UNUTTUM — DÜĞMENİN CANLI DAVRANIŞI
///
/// ⚠ BU DOSYA, KAYNAK-METİN TESTLERİNİN KAÇIRDIĞI BİR HATAYI KİLİTLER.
///
/// Düğme kuralı (`_zorunluDolu`) doğru yazılmıştı ve bütün kaynak
/// testleri geçiyordu; buna rağmen cihazda düğme AÇILMIYORDU. Sebep
/// kuralda değil ÇİZİMDEYDİ: metin değiştiğinde `setState`
/// çağrılmadığı için düğme, ekran ilk kurulduğu andaki (alan boş →
/// pasif) hâlinde kalıyordu.
///
/// Kayıtsızlık denetimi güvenlik gerekçesiyle kaldırılınca, o
/// denetimin dolaylı olarak sağladığı yeniden çizim tetikleyicisi de
/// ortadan kalkmıştı.
///
/// ⚠ DERS: "kural kaynakta doğru" ile "ekranda çalışıyor" aynı şey
/// değildir. Düğme etkinliği artık ÇALIŞTIRILARAK doğrulanır.
///
/// ⚠ KAYITLILIK DENETLENMEZ (K5): biçim geçerliyse düğme açılır,
/// numara sistemde kayıtlı olsa da olmasa da. Fark yalnız kodun
/// gerçekten gönderilip gönderilmediğindedir ve ekranda görünmez.
void main() {
  Widget host() {
    // ⚠ BOŞ DEPO: hiçbir numara kayıtlı DEĞİL. Düğmenin yine de
    // açılması gerekir — kayıtlılık düğmeyi etkilemez.
    final repo = AuthRepository(seedTestAccount: false);
    return ChangeNotifierProvider(
      create: (_) => AuthController(MockAuthPort(repo)),
      child: MaterialApp(
        theme: HC.theme(),
        home: const ForgotPasswordScreen(),
      ),
    );
  }

  /// Telefon yoluna geçer.
  Future<void> telefonYolu(WidgetTester t) async {
    await t.pumpWidget(host());
    await t.pump();
    await t.tap(find.text('Telefon ile devam et'));
    await t.pumpAndSettle();
  }

  /// Düğme etkin mi? (`onPressed == null` ise pasif)
  bool etkin(WidgetTester t, String metin) {
    final b = t.widget<RefPrimaryButton>(
        find.widgetWithText(RefPrimaryButton, metin));
    return b.onPressed != null;
  }

  group('1 — TELEFON: geçerli numarada düğme AÇILIR', () {
    testWidgets('alan boşken pasif, 10 hane girilince AKTİF', (t) async {
      await telefonYolu(t);
      const dugme = 'Doğrulama Kodu Gönder';

      expect(etkin(t, dugme), isFalse, reason: 'boş alanda düğme aktif');

      await t.enterText(find.byKey(const ValueKey('kurtarma-telefon')),
          '5321112233');
      await t.pump();

      // ⚠ ASIL KİLİT: kayıt DEĞİL, ÇİZİM. Bu satır eskiden düşüyordu.
      expect(etkin(t, dugme), isTrue,
          reason: 'geçerli numarada düğme açılmadı — '
              'metin değişince ekran yeniden çizilmiyor');
    });

    testWidgets('hane silinince yeniden PASİF olur', (t) async {
      await telefonYolu(t);
      const dugme = 'Doğrulama Kodu Gönder';
      final alan = find.byKey(const ValueKey('kurtarma-telefon'));

      await t.enterText(alan, '5321112233');
      await t.pump();
      expect(etkin(t, dugme), isTrue);

      await t.enterText(alan, '532111223');
      await t.pump();
      expect(etkin(t, dugme), isFalse,
          reason: 'eksik numarada düğme aktif kaldı');
    });

    testWidgets('KAYITLI OLMAYAN numarada da AÇILIR (K5)', (t) async {
      // Depo boş; bu numara sistemde YOK. Düğme yine de açılmalı,
      // yoksa uygulama hesap varlığını ele verir.
      await telefonYolu(t);
      await t.enterText(find.byKey(const ValueKey('kurtarma-telefon')),
          '5559998877');
      await t.pump();
      expect(etkin(t, 'Doğrulama Kodu Gönder'), isTrue,
          reason: 'kayıtsız numarada düğme kilitlenmiş — enumeration');
    });
  });

  group('2 — E-POSTA: aynı ilke', () {
    testWidgets('geçersiz biçimde pasif, geçerli biçimde AKTİF', (t) async {
      await t.pumpWidget(host());
      await t.pump();
      const dugme = 'Şifre Yenileme Bağlantısı Gönder';
      final alan = find.byKey(const ValueKey('kurtarma-eposta'));

      expect(etkin(t, dugme), isFalse);

      await t.enterText(alan, 'abc');
      await t.pump();
      expect(etkin(t, dugme), isFalse, reason: 'geçersiz biçimde açıldı');

      await t.enterText(alan, 'kayitli.olmayan@ornek.com');
      await t.pump();
      // ⚠ Adres kayıtlı DEĞİL ama düğme açılır (K5).
      expect(etkin(t, dugme), isTrue);
    });
  });
}
