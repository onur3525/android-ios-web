// EKSİK HİZMET VEREN KAPISI (6 Kas, kullanıcı kararı)
//
// Kaydı tamamlanmamış hizmet veren aktif hesap sayılmaz: hizmet veren
// rolündeki ekranlar içerik yerine ortak uyarıyı ve "Formu Doldur"
// düğmesini çizer. Kapı TEK KAYNAKTA (`RoleGuard` → `SaglayiciProfilKapisi`).
//
// ⚠ Kaynak metni denetleyen testlerde YORUM SATIRLARI ELENİR.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/screens/widgets/saglayici_profil_kapisi.dart';

String _kod(String yol) => File(yol)
    .readAsStringSync()
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('metin kullanıcının cümleleriyle, düğme "Formu Doldur"', () {
    expect(SaglayiciProfilKapisi.baslik, 'Önce formu tamamlayalım!');
    expect(
        SaglayiciProfilKapisi.metin,
        'Formu eksiksiz doldurmazsanız ilanları göremez, Bul özelliğinde '
        'görünemez ve hiçbir ilana ya da isteğe teklif veremezsiniz. Hemen '
        'formu doldurun, işleri listelemeye başlayalım.');
    expect(SaglayiciProfilKapisi.dugme, 'Formu Doldur');
  });

  test('uyarı ortada; düğme profil tamamlama formunu açar; alt menü durur', () {
    final k = _kod('lib/screens/widgets/saglayici_profil_kapisi.dart');
    expect(k.contains('child: KalanAlandaOrtala('), isTrue);
    expect(k.contains('onPressed: () => profilKapisi(context, Role.provider),'),
        isTrue);
    expect(k.contains('items: custNavItems(context, saglayici: true),'), isTrue);
  });

  test('RoleGuard: yalnız aktif rol hizmet veren VE bilgiler eksikken kapı', () {
    final g = _kod('lib/core/route_guard.dart');
    expect(
        g.contains('if (eksikSaglayiciyiKapat &&\n'
            '        acc.activeRole == Role.provider &&\n'
            '        !acc.profilTamam(Role.provider)) {\n'
            '      return const SaglayiciProfilKapisi();'),
        isTrue);
    // Kapı rol denetiminden SONRA: hizmet alan yine "erişiminiz yok" görür.
    expect(g.indexOf('return const SaglayiciProfilKapisi();'),
        greaterThan(g.indexOf("title: 'Bu ekrana erişiminiz yok',")));
    // `RoleGuard.provider` davranışı değişmedi (kapı yalnız panel kurucusunda).
    expect(
        g.contains('const RoleGuard.provider({super.key, required this.builder})\n'
            '      : requires = Role.provider,\n'
            '        eksikSaglayiciyiKapat = false;'),
        isTrue);
  });

  test('hizmet veren rolündeki bütün rotalar kapıdan geçer; Profil açık', () {
    final m = _kod('lib/main.dart');
    for (final ekran in const [
      'const JobsScreen()',
      'const JobsScreen(kazandigim: true)',
      'const ProviderStatusScreen()',
      'const MyReviewsScreen()',
      'const MyCategoriesScreen()',
      'const MyAreasScreen()',
      'JobDetailScreen(listingId: is_)',
    ]) {
      final i = m.indexOf(ekran);
      expect(i, greaterThan(0), reason: ekran);
      expect(m.substring(i - 120, i).contains('RoleGuard.saglayiciPaneli('),
          isTrue, reason: ekran);
    }
    for (final ekran in const [
      'const NotificationsScreen()',
      'TeklifTalebiDetayScreen(talepId: talep)',
      'ChatScreen(offerId: mesaj)',
    ]) {
      final i = m.indexOf(ekran);
      expect(m.substring(i - 120, i).contains('eksikSaglayiciyiKapat: true,'),
          isTrue, reason: ekran);
    }
    expect(m.contains('RoleGuard.provider('), isFalse,
        reason: 'kapısız hizmet veren rotası kalmış');
    // Profil (çıkış, hesap ayarları, destek) kapıya bağlı DEĞİL.
    final p = m.indexOf("'/profile': (_) => RoleGuard(");
    expect(p, greaterThan(0));
    expect(m.substring(p, p + 200).contains('eksikSaglayiciyiKapat'), isFalse);
  });
}
