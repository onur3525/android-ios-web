import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../core/firebase/firebase_baslatici.dart';
import '../../domain/failures.dart';

/// ═══════════════════════════════════════════════════════════════
/// FIREBASE KİMLİK — telefon OTP, e-posta doğrulama, şifre sıfırlama
///
/// MİMARİ (kalıcı üretim çözümü):
///   · Firebase KİMLİĞİ DOĞRULAR (SMS kodu, e-posta/şifre, e-posta
///     bağlantıları) ve kısa ömürlü bir ID token verir.
///   · HizmetCep backend bu token'ı Google'ın AÇIK sertifikalarıyla
///     doğrular, Firebase UID'yi kendi hesabına bağlar ve KENDİ oturumunu
///     verir. Hesap, rol, askı/ban, ilan/teklif/mesaj/bildirim verisi
///     backend'de kalır (source of truth).
///   · İstemcide gizli anahtar YOK (Admin SDK yalnız gerekirse sunucuda).
///
/// YALNIZ API MODUNDA kullanılır; mock/demo modu (OTP 123456) aynen.
/// Arayüz DEĞİŞMEZ: mevcut ekranlar aynı port yöntemlerini çağırır.
/// ═══════════════════════════════════════════════════════════════
class FirebaseKimlik {
  FirebaseKimlik._();
  static final FirebaseKimlik i = FirebaseKimlik._();

  int _sayac = 0;
  final Map<String, _Bekleyen> _bekleyen = {};
  final Map<String, String> _tokenTelefonu = {};
  DomainError? _sonGonderimHatasi;

  Future<FirebaseAuth?> _auth() async {
    if (await firebaseHazirla() == null) {
      return null;
    }
    final a = FirebaseAuth.instance;
    if (!_ayarlandi) {
      _ayarlandi = true;
      await a.setLanguageCode('tr'); // SMS ve e-posta şablonları Türkçe
      if (kIsWeb) {
        // ⚠ WEB: Firebase oturumu tarayıcı deposuna YAZILMAZ (M-05 ile
        // tutarlı). Token yalnız işlem anında alınır; HizmetCep oturumu
        // backend'den gelir.
        await a.setPersistence(Persistence.NONE);
      }
    }
    return a;
  }

  bool _ayarlandi = false;

  static String _e164(String telefon10) => '+90${telefon10.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^0+'), '')}';

  static DomainError _hata(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-verification-code':
        case 'invalid-verification-id':
          return const ValidationError('Doğrulama kodu hatalı');
        case 'session-expired':
        case 'code-expired':
          return const ValidationError('Doğrulama kodunun süresi doldu. Yeni kod isteyin.');
        case 'too-many-requests':
        case 'quota-exceeded':
          return const ValidationError('Çok fazla deneme yapıldı. Lütfen daha sonra tekrar deneyin.');
        case 'invalid-phone-number':
          return const ValidationError('Geçerli bir cep telefonu numarası giriniz');
        case 'wrong-password':
        case 'invalid-credential':
        case 'user-not-found':
        case 'invalid-email':
          return const AuthFailedError();
        case 'email-already-in-use':
        case 'credential-already-in-use':
        case 'provider-already-linked':
          return const ValidationError('Bu e-posta adresi başka bir hesapta kayıtlı');
        case 'requires-recent-login':
          return const ValidationError('Güvenlik için lütfen yeniden giriş yapın');
        case 'network-request-failed':
          return const ValidationError('İnternet bağlantınızı kontrol edin');
      }
      debugPrint('FIREBASE_AUTH ${e.code}');
    }
    return const ValidationError('İşlem tamamlanamadı. Lütfen tekrar deneyin.');
  }

  /// SMS kodu gönderir. Dönen kimlik `kodDogrula`ya verilir.
  Future<({String? id, DomainError? error})> kodGonder(String telefon10) async {
    _sonGonderimHatasi = null;
    final a = await _auth();
    if (a == null) {
      return (id: null, error: _sonGonderimHatasi = const ValidationError('Doğrulama hizmetine ulaşılamadı'));
    }
    final id = 'fb${++_sayac}';
    final numara = _e164(telefon10);
    try {
      if (kIsWeb) {
        // Web: görünmez reCAPTCHA (yetkili alan adı: onur3525.github.io).
        final onay = await a.signInWithPhoneNumber(numara);
        _bekleyen[id] = _Bekleyen(telefon10, onay: onay);
        return (id: id, error: null);
      }
      final bitti = Completer<DomainError?>();
      await a.verifyPhoneNumber(
        phoneNumber: numara,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (kimlik) {
          // Android otomatik SMS okuma: kod girilmeden de doğrulanabilir.
          final b = _bekleyen[id];
          if (b != null) {
            b.otomatik = kimlik;
          } else {
            _bekleyen[id] = _Bekleyen(telefon10)..otomatik = kimlik;
          }
          if (!bitti.isCompleted) bitti.complete(null);
        },
        verificationFailed: (e) {
          if (!bitti.isCompleted) bitti.complete(_hata(e));
        },
        codeSent: (dogrulamaId, _) {
          (_bekleyen[id] ??= _Bekleyen(telefon10)).dogrulamaId = dogrulamaId;
          if (!bitti.isCompleted) bitti.complete(null);
        },
        codeAutoRetrievalTimeout: (dogrulamaId) {
          (_bekleyen[id] ??= _Bekleyen(telefon10)).dogrulamaId ??= dogrulamaId;
        },
      );
      final err = await bitti.future.timeout(const Duration(seconds: 90),
          onTimeout: () => const ValidationError('Doğrulama kodu gönderilemedi. Tekrar deneyin.'));
      if (err != null) {
        _sonGonderimHatasi = err;
        return (id: null, error: err);
      }
      return (id: id, error: null);
    } catch (e) {
      return (id: null, error: _sonGonderimHatasi = _hata(e));
    }
  }

  /// Kodu doğrular, Firebase'de oturum açar ve ID token döndürür.
  /// [mevcutKullanici] true ise (telefon değişimi) numara açık Firebase
  /// kullanıcısına bağlanır.
  Future<({String? idToken, DomainError? error})> kodDogrula(String id, String kod,
      {bool mevcutKullanici = false}) async {
    final b = _bekleyen[id];
    if (b == null) {
      return (idToken: null, error: _sonGonderimHatasi ?? const ValidationError('Doğrulama kodunun süresi doldu. Yeni kod isteyin.'));
    }
    final a = await _auth();
    if (a == null) {
      return (idToken: null, error: const ValidationError('Doğrulama hizmetine ulaşılamadı'));
    }
    try {
      UserCredential sonuc;
      if (b.onay != null) {
        sonuc = await b.onay!.confirm(kod.trim());
      } else {
        final kimlik = b.otomatik ??
            PhoneAuthProvider.credential(verificationId: b.dogrulamaId ?? '', smsCode: kod.trim());
        final u = a.currentUser;
        if (mevcutKullanici && u != null) {
          await u.updatePhoneNumber(kimlik);
          final t = await u.getIdToken(true);
          _bekleyen.remove(id);
          if (t != null) _tokenTelefonu[t] = b.telefon;
          return (idToken: t, error: null);
        }
        sonuc = await a.signInWithCredential(kimlik);
      }
      final t = await sonuc.user?.getIdToken(true);
      _bekleyen.remove(id);
      if (t == null) {
        return (idToken: null, error: const ValidationError('İşlem tamamlanamadı. Lütfen tekrar deneyin.'));
      }
      _tokenTelefonu[t] = b.telefon;
      return (idToken: t, error: null);
    } catch (e) {
      return (idToken: null, error: _hata(e));
    }
  }

  /// Bu token hangi telefon doğrulamasından geldi (kurtarma akışı için).
  String? tokenTelefonu(String idToken) => _tokenTelefonu[idToken];

  Future<({String? idToken, DomainError? error})> epostaSifreGiris(String email, String sifre) async {
    final a = await _auth();
    if (a == null) {
      return (idToken: null, error: const ValidationError('Doğrulama hizmetine ulaşılamadı'));
    }
    try {
      final s = await a.signInWithEmailAndPassword(email: email.trim(), password: sifre);
      return (idToken: await s.user?.getIdToken(true), error: null);
    } catch (e) {
      return (idToken: null, error: _hata(e));
    }
  }

  /// Kayıttan sonra: e-posta/şifreyi telefonla açılan Firebase kullanıcısına
  /// bağlar ve DOĞRULAMA E-POSTASI gönderir (Firebase şablonu).
  Future<DomainError?> epostaBaglaVeDogrulamaGonder(String email, String sifre) async {
    final u = (await _auth())?.currentUser;
    if (u == null) {
      return const ValidationError('Doğrulama hizmetine ulaşılamadı');
    }
    try {
      if (!u.providerData.any((p) => p.providerId == 'password')) {
        await u.linkWithCredential(EmailAuthProvider.credential(email: email.trim(), password: sifre));
      }
      await u.sendEmailVerification();
      return null;
    } catch (e) {
      return _hata(e);
    }
  }

  Future<DomainError?> sifreSifirlamaEpostasi(String email) async {
    final a = await _auth();
    if (a == null) {
      return const ValidationError('Doğrulama hizmetine ulaşılamadı');
    }
    try {
      await a.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      // Hesap var/yok bilgisi sızmasın: "bulunamadı" da başarı gibi görünür.
      if (e.code == 'user-not-found') {
        return null;
      }
      return _hata(e);
    } catch (e) {
      return _hata(e);
    }
  }

  /// Telefonla kurtarma sonrası Firebase şifresini de günceller (iki kaynak
  /// ayrışmasın). Firebase kullanıcısında e-posta/şifre yoksa bir şey yapmaz.
  Future<void> sifreGuncelle(String yeniSifre) async {
    try {
      final u = (await _auth())?.currentUser;
      if (u != null && u.providerData.any((p) => p.providerId == 'password')) {
        await u.updatePassword(yeniSifre);
      }
    } catch (_) {}
  }

  /// Yeni adrese doğrulama bağlantısı gönderir; adres BAĞLANTI tıklanınca
  /// değişir ve sonraki girişte backend hesabına işlenir.
  Future<DomainError?> epostaDegistir(String yeni) async {
    final u = (await _auth())?.currentUser;
    if (u == null) {
      return const ValidationError('Güvenlik için lütfen yeniden giriş yapın');
    }
    try {
      await u.verifyBeforeUpdateEmail(yeni.trim());
      return null;
    } catch (e) {
      return _hata(e);
    }
  }

  Future<void> cikis() async {
    _bekleyen.clear();
    _tokenTelefonu.clear();
    try {
      if (await firebaseHazirla() != null) {
        await FirebaseAuth.instance.signOut();
      }
    } catch (_) {}
  }
}

class _Bekleyen {
  _Bekleyen(this.telefon, {this.onay});
  final String telefon;
  final ConfirmationResult? onay;
  String? dogrulamaId;
  PhoneAuthCredential? otomatik;
}
