import 'package:flutter/material.dart';

import '../core/sys_state.dart';
import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';

/// ═══════════════════════════════════════════════════════════════
/// BULUNAMADI (404)
///
/// ## ⚠ NİÇİN GEREKLİ
///
/// `MaterialApp` tanımsız bir route istendiğinde varsayılan olarak
/// hiçbir şey çizmez; web'de kullanıcı `/olmayan-sayfa` yazınca boş
/// bir ekranda kalıyordu. Mobilde bu durum oluşmaz (route adları
/// koddan gelir), web'de ADRES ÇUBUĞU kullanıcıya ait olduğu için
/// oluşur.
///
/// ## ⚠ YENİ TASARIM DEĞİL
///
/// Mevcut tasarım sistemi kullanıldı: `SysEmpty` boş durum bloğu,
/// `RefPageTitle` başlığı, `RefPrimaryButton` düğmesi, `RC` renkleri.
/// Yeni renk, yeni görsel, yeni tipografi ÜRETİLMEDİ.
///
/// ## ⚠ ADRES EKRANA YAZILMAZ
///
/// Kullanıcının yazdığı yolu ekranda göstermek, hazırlanmış bir
/// bağlantıyla yapılan yansıtma (reflected content) denemelerine
/// yüzey açar. Yalnız "bulunamadı" denir.
/// ═══════════════════════════════════════════════════════════════
class BulunamadiScreen extends StatelessWidget {
  const BulunamadiScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: RC.pageBg,
        body: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(14, 6, 14, 0),
                // ⚠ GERİ OKU YOK: kullanıcı buraya adres çubuğundan
                // gelmiş olabilir, dönülecek bir sayfa olmayabilir.
                child: RefPageTitle('Sayfa bulunamadı', geriDugmesi: false),
              ),
              const Expanded(
                child: Center(
                  child: SysEmpty(
                    title: 'Sayfa bulunamadı',
                    desc: 'Aradığınız sayfa taşınmış veya hiç var olmamış '
                        'olabilir.',
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                child: RefPrimaryButton(
                  'Ana sayfaya dön',
                  // ⚠ `pushNamedAndRemoveUntil`: geçersiz adres
                  // yığında kalmamalı; geri tuşu kullanıcıyı yeniden
                  // 404'e düşürmemeli.
                  onPressed: () => Navigator.of(context)
                      .pushNamedAndRemoveUntil('/home', (r) => false),
                ),
              ),
            ],
          ),
        ),
      );
}
