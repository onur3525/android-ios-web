/// E-POSTA YAZIM ÖNERİSİ VE NORMALİZASYON
///
/// ── NEDEN DOĞRULAMA DEĞİL, ÖNERİ ──
///
/// `hotmail.co` SÖZDİZİMSEL OLARAK GEÇERLİDİR: `.co` gerçek bir üst
/// düzey alan adıdır (Kolombiya) ve dünya genelinde kullanılır. Bu
/// yüzden hiçbir doğrulayıcı onu reddedemez — reddederse gerçekten
/// `.co` uzantılı adresi olan kullanıcı kaydolamaz.
///
/// Sunucu da düzeltmez ve DÜZELTMEMELİDİR: kullanıcının yazdığı
/// adresi sessizce değiştirmek, yazışmayı yanlış kişiye göndermek ve
/// hesabı başkasına ait olabilecek bir adrese bağlamak demektir.
///
/// Gerçek koruma E-POSTA DOĞRULAMASIDIR. Adres yanlışsa doğrulama
/// iletisi hiç ulaşmaz ve hesap doğrulanmaz.
///
/// Burada yapılan şey ENGELLEYİCİ DEĞİLDİR: yaygın alan adlarına çok
/// benzeyen bir yazım görülürse kullanıcıya "şunu mu demek
/// istediniz?" diye sorulur; kabul etmek zorunda değildir.
library;

import 'package:flutter/material.dart';

import '../ui/ref_tokens.dart';
import '../ui/ref_widgets.dart';

/// Yaygın alan adları — öneri YALNIZ bu listeye yakınlık için üretilir.
const _kBilinen = <String>[
  'gmail.com',
  'hotmail.com',
  'outlook.com',
  'yahoo.com',
  'icloud.com',
  'windowslive.com',
  'yandex.com',
  'protonmail.com',
  'mail.ru',
  'hotmail.com.tr',
  'yahoo.com.tr',
];

/// KAYDA YAZILACAK BİÇİM.
///
/// Boşluk kırpılır ve KÜÇÜK HARFE çevrilir. Aksi hâlde
/// `Ahmet@Gmail.com` ile `ahmet@gmail.com` iki ayrı kayıt gibi
/// davranır; e-posta alan adı zaten büyük/küçük harf duyarsızdır.
String epostaNormalize(String? v) => (v ?? '').trim().toLowerCase();

/// Alan adı için düzeltme önerisi; öneri yoksa `null`.
///
/// Kural: yazılan alan adı bilinen bir alan adına EN FAZLA BİR
/// düzenleme uzaklığındaysa (bir harf eksik/fazla/yanlış) öneri
/// üretilir. Tam eşleşmede öneri YOKTUR.
String? epostaOnerisi(String? v) {
  final e = epostaNormalize(v);
  final at = e.lastIndexOf('@');
  if (at <= 0 || at == e.length - 1) {
    return null;
  }
  final yerel = e.substring(0, at);
  final alan = e.substring(at + 1);
  if (_kBilinen.contains(alan)) {
    return null; // zaten doğru
  }
  for (final b in _kBilinen) {
    if (_uzaklikEnFazla1(alan, b)) {
      return '$yerel@$b';
    }
  }
  return null;
}

/// İki metin arasındaki düzenleme uzaklığı 1'i geçiyor mu?
///
/// Tam Levenshtein hesaplanmaz; yalnız "en fazla bir düzenleme" mi
/// diye bakılır — daha ucuz ve bu iş için yeterlidir.
bool _uzaklikEnFazla1(String a, String b) {
  if (a == b) {
    return false; // aynı — öneri gereksiz
  }
  final fark = a.length - b.length;
  if (fark > 1 || fark < -1) {
    return false;
  }
  if (a.length == b.length) {
    // Tek harf DEĞİŞMİŞ ya da KOMŞU İKİ HARF YER DEĞİŞTİRMİŞ olabilir.
    // (`gmial.com` → `gmail.com` en sık görülen yazım hatasıdır.)
    final farkli = <int>[];
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        farkli.add(i);
        if (farkli.length > 2) {
          return false;
        }
      }
    }
    if (farkli.length == 1) {
      return true;
    }
    if (farkli.length == 2 && farkli[1] == farkli[0] + 1) {
      return a[farkli[0]] == b[farkli[1]] && a[farkli[1]] == b[farkli[0]];
    }
    return false;
  }
  // Tek harf EKSİK ya da FAZLA: uzun olanı kısaltarak dene.
  final uzun = a.length > b.length ? a : b;
  final kisa = a.length > b.length ? b : a;
  var i = 0;
  var j = 0;
  var atlandi = false;
  while (i < uzun.length && j < kisa.length) {
    if (uzun[i] == kisa[j]) {
      i++;
      j++;
      continue;
    }
    if (atlandi) {
      return false;
    }
    atlandi = true;
    i++;
  }
  return true;
}

/// Alanın ALTINDA çıkan öneri satırı.
///
/// ⚠ Kaydı ENGELLEMEZ. Öneri yoksa hiçbir yer kaplamaz.
class EpostaOneriSatiri extends StatelessWidget {
  const EpostaOneriSatiri({
    super.key,
    required this.controller,
    required this.onKabul,
  });

  final TextEditingController controller;
  final ValueChanged<String> onKabul;

  @override
  Widget build(BuildContext context) {
    final oneri = epostaOnerisi(controller.text);
    if (oneri == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 2),
      child: RefTap(
        onTap: () => onKabul(oneri),
        borderRadius: BorderRadius.circular(RR.r8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Row(
            children: [
              const RefSvg('assets/svg/ic_info.svg', size: 15),
              const SizedBox(width: 6),
              Flexible(
                child: RichText(
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(children: [
                    TextSpan(
                        text: 'Şunu mu demek istediniz: ',
                        style: refText(
                            size: RF.s125,
                            weight: RF.w400,
                            color: RC.textSoft)),
                    TextSpan(
                        text: oneri,
                        style: refText(
                            size: RF.s125,
                            weight: RF.w700,
                            color: RC.blue)),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
