import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/models/notification.dart';
import 'package:hizmetcep/data/models/provider_approval.dart';
import 'package:hizmetcep/data/remote/mappers.dart';
import 'support/kaynak_okuma.dart';

/// Hizmet veren onay durumu + bildirim tipi eşlemesi.
void main() {
  group('Onay durumu ayrıştırma', () {
    test('sunucu sözlüğü doğru eşlenir', () {
      expect(ProviderApproval.parse('APPROVED'), ProviderApproval.approved);
      expect(ProviderApproval.parse('PENDING'), ProviderApproval.pending);
      expect(ProviderApproval.parse('REJECTED'), ProviderApproval.rejected);
      expect(ProviderApproval.parse('SUSPENDED'), ProviderApproval.suspended);
    });

    test('BİLİNMEYEN/BOŞ değer ONAYLI SAYILMAZ', () {
      for (final raw in [null, '', 'OK', 'true', 'ONAY']) {
        final s = ProviderApproval.parse(raw);
        expect(s, ProviderApproval.pending, reason: raw);
        expect(s.canPlaceOffer, isFalse);
      }
    });

    test('yalnız APPROVED teklif verebilir', () {
      expect(ProviderApproval.approved.canPlaceOffer, isTrue);
      for (final s in [
        ProviderApproval.pending,
        ProviderApproval.rejected,
        ProviderApproval.suspended,
      ]) {
        expect(s.canPlaceOffer, isFalse);
      }
    });

    test('fromJson sözleşmesi', () {
      final s = ProviderApprovalState.fromJson(const {
        'status': 'REJECTED',
        'canPlaceOffer': false,
        'message': 'Başvurunuz onaylanmadı.',
        'reason': 'Eksik bilgi',
      });
      expect(s.status, ProviderApproval.rejected);
      expect(s.canPlaceOffer, isFalse);
      expect(s.reason, 'Eksik bilgi');
    });

    test('güvenli varsayılan (unknown) teklif vermeye izin VERMEZ', () {
      expect(ProviderApprovalState.unknown.canPlaceOffer, isFalse);
      expect(ProviderApprovalState.unknown.message, isNotEmpty);
    });

    test('her durumun etiketi vardır', () {
      for (final s in ProviderApproval.values) {
        expect(s.label, isNotEmpty);
      }
    });
  });

  group('Bildirim tipi eşlemesi', () {
    test('ACCOUNT_STATUS doğru eşlenir', () {
      expect(Mappers.notifType('ACCOUNT_STATUS'), NotifType.accountStatus);
    });

    test('CATEGORY_REQUEST doğru eşlenir', () {
      expect(Mappers.notifType('CATEGORY_REQUEST'), NotifType.categoryRequest);
    });

    test('ANNOUNCEMENT doğru eşlenir', () {
      expect(Mappers.notifType('ANNOUNCEMENT'), NotifType.announcement);
    });

    test('duyuru bildirimi tıklanınca GEÇERSİZ route oluşturulmaz', () {
      // Ayrı duyuru detay ekranı yoktur; ekran kaynağında announcement
      // dalı yönlendirme YAPMADAN break eder.
      final src = File('lib/screens/notifications_screen.dart')
          .readAsStringSync();
      final i = src.indexOf('case NotifType.announcement:');
      expect(i, greaterThan(-1));
      // Bu daldan sonraki ilk ifade break olmalı (pushNamed DEĞİL).
      final seg = src.pencere(i, 300);
      expect(seg.contains('break;'), isTrue);
      expect(seg.indexOf('break;') < seg.indexOf('pushNamed'), isTrue);
    });

    test('mevcut tipler bozulmadı', () {
      expect(Mappers.notifType('NEW_OFFER'), NotifType.newOffer);
      expect(Mappers.notifType('OFFER_SELECTED'), NotifType.offerSelected);
      expect(Mappers.notifType('REFUND'), NotifType.refund);
      expect(Mappers.notifType('CONTACT_OPENED'), NotifType.contactOpened);
      expect(Mappers.notifType('NEW_MESSAGE'), NotifType.newMessage);
      expect(Mappers.notifType('LISTING_EXPIRED'), NotifType.listingExpired);
    });

    test('BİLİNMEYEN tip çökertmez ve yanlış tipe eşlenmez', () {
      expect(Mappers.notifType('YENI_TIP'), NotifType.unknown);
      expect(Mappers.notifType(''), NotifType.unknown);
      expect(Mappers.notifType('LISTING_EXPIRED_X'), NotifType.unknown);
    });
  });
}
