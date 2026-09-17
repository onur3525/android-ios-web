import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/core/validators.dart';

void main() {
  group('Telefon', () {
    test('baştaki 0 atılır, yalnız rakam', () {
      expect(Validators.phoneFmt('0532 111 22 33'), '5321112233');
      expect(Validators.phoneFmt('0005321112233'), '5321112233');
      expect(Validators.phoneFmt('532abc1112233'), '5321112233');
    });
    test('10 hane ve 5 ile başlama zorunlu', () {
      expect(Validators.phone('5321112233'), isNull);
      expect(Validators.phone('05321112233'), isNull); // 0 normalize edilir
      expect(Validators.phone('1234567890'), isNotNull);
      expect(Validators.phone('532111'), isNotNull);
      expect(Validators.phone(''), 'Bu alan zorunludur');
    });
  });

  group('Junk isim engeli', () {
    test('gerçek isimler geçer', () {
      expect(Validators.name('Mehmet'), isNull);
      expect(Validators.name('Ayşe Nur'), isNull);
    });
    test('junk reddedilir', () {
      expect(Validators.name('asd'), isNotNull);
      expect(Validators.name('qwerty'), isNotNull);
      expect(Validators.name('aaa'), isNotNull);
      expect(Validators.name('xyz'), isNotNull); // sessiz harf kümesi
      expect(Validators.name(''), 'Bu alan zorunludur');
    });
  });

  group('Kart', () {
    test('16 hane, 4lü gruplama', () {
      expect(Validators.cardNumFmt('4111111122223333999'), '4111 1111 2222 3333');
      expect(Validators.cardNum('4111 1111 2222 3333'), isNull);
      expect(Validators.cardNum('4111 1111 2222 333'), isNotNull);
    });
    test('AA/YY yazarken otomatik /', () {
      expect(Validators.expFmt('12', deleting: false), '12/');
      expect(Validators.expFmt('3', deleting: false), '03/');
      expect(Validators.expFmt('1228', deleting: false), '12/28');
      expect(Validators.expFmt('13', deleting: false), '1'); // ay>12 engel
    });
    test('AA/YY silerken / yeniden EKLENMEZ (tek tuşla geri silme)', () {
      expect(Validators.expFmt('12', deleting: true), '12');
      expect(Validators.expFmt('1', deleting: true), '1');
      expect(Validators.expFmt('122', deleting: true), '12/2');
    });
    test('geçerlilik', () {
      expect(Validators.exp('12/28'), isNull);
      expect(Validators.exp('13/28'), isNotNull);
      expect(Validators.cvv('123'), isNull);
      expect(Validators.cvv('12'), isNotNull);
    });
  });
}
