// GÖRSEL META VERİSİ TEMİZLEYİCİ (KVKK takip denetimi B5, 22 Eki)
//
// Fikstürler Pillow ile üretildi: EXIF'te GPS + model + yön (6), JPEG'de
// yorum ve EOI sonrası ek, PNG'de tEXt + eXIf, WEBP'de EXIF + XMP.
// Beklenen çıktılar, aynı algoritmanın bağımsız bir uygulamasıyla
// üretildi ve görsellerin piksel olarak bozulmadan açıldığı doğrulandı.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hizmetcep/data/remote/gorsel_meta_temizleyici.dart';

const Map<String, (String, String)> _fikstur = {
  'jpeg': ('/9j/4AAQSkZJRgABAQAAAQABAAD/4QB4RXhpZgAATU0AKgAAAAgAAwEQAAIAAAAHAAAAMgESAAMAAAABAAYAAIglAAQAAAABAAAAOgAAAABNb2RlbFkAAAACAAEAAgAAAAJOAAAAAAIABQAAAAMAAABYAAAAAAAAACYAAAABAAAAGwAAAAEAAAAfAAAAAv/+AApFdkFkcmVzaf/bAEMABgQFBgUEBgYFBgcHBggKEAoKCQkKFA4PDBAXFBgYFxQWFhodJR8aGyMcFhYgLCAjJicpKikZHy0wLSgwJSgpKP/bAEMBBwcHCggKEwoKEygaFhooKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKP/AABEIAAwAEAMBIgACEQEDEQH/xAAfAAABBQEBAQEBAQAAAAAAAAAAAQIDBAUGBwgJCgv/xAC1EAACAQMDAgQDBQUEBAAAAX0BAgMABBEFEiExQQYTUWEHInEUMoGRoQgjQrHBFVLR8CQzYnKCCQoWFxgZGiUmJygpKjQ1Njc4OTpDREVGR0hJSlNUVVZXWFlaY2RlZmdoaWpzdHV2d3h5eoOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4eLj5OXm5+jp6vHy8/T19vf4+fr/xAAfAQADAQEBAQEBAQEBAAAAAAAAAQIDBAUGBwgJCgv/xAC1EQACAQIEBAMEBwUEBAABAncAAQIDEQQFITEGEkFRB2FxEyIygQgUQpGhscEJIzNS8BVictEKFiQ04SXxFxgZGiYnKCkqNTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqCg4SFhoeIiYqSk5SVlpeYmZqio6Slpqeoqaqys7S1tre4ubrCw8TFxsfIycrS09TV1tfY2dri4+Tl5ufo6ery8/T19vf4+fr/2gAMAwEAAhEDEQA/AOAooor54/YT/9lFS1ZFUkk=', '/9j/4AAQSkZJRgABAQAAAQABAAD/4QAiRXhpZgAATU0AKgAAAAgAAQESAAMAAAABAAYAAAAAAAD/2wBDAAYEBQYFBAYGBQYHBwYIChAKCgkJChQODwwQFxQYGBcUFhYaHSUfGhsjHBYWICwgIyYnKSopGR8tMC0oMCUoKSj/2wBDAQcHBwoIChMKChMoGhYaKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCj/wAARCAAMABADASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwDgKKKK+eP2E//Z'),
  'png': ('iVBORw0KGgoAAAANSUhEUgAAABAAAAAMCAIAAADkharWAAAAEXRFWHRMb2NhdGlvbgBFdkFkcmVzafecQbcAAABwZVhJZk1NACoAAAAIAAMBEAACAAAABwAAADIBEgADAAAAAQAGAACIJQAEAAAAAQAAADoAAAAATW9kZWxZAAAAAgABAAIAAAACTgAAAAACAAUAAAADAAAAWAAAAAAAAAAmAAAAAQAAABsAAAABAAAAHwAAAAIpsKzMAAAAF0lEQVR4nGM8ISfHQApgIkn1qIYRpAEAccwBHAhqXtYAAAAASUVORK5CYII=', 'iVBORw0KGgoAAAANSUhEUgAAABAAAAAMCAIAAADkharWAAAAF0lEQVR4nGM8ISfHQApgIkn1qIYRpAEAccwBHAhqXtYAAAAASUVORK5CYII='),
  'webp': ('UklGRtwAAABXRUJQVlA4WAoAAAAMAAAADwAACwAAVlA4IC4AAACwAQCdASoQAAwAAUAmJaACdLoABDAAAP7x3I/4DdfFtMv/vYL/3YL/3YL/WwAARVhJRnAAAABNTQAqAAAACAADARAAAgAAAAcAAAAyARIAAwAAAAEABgAAiCUABAAAAAEAAAA6AAAAAE1vZGVsWQAAAAIAAQACAAAAAk4AAAAAAgAFAAAAAwAAAFgAAAAAAAAAJgAAAAEAAAAbAAAAAQAAAB8AAAACWE1QIA8AAAA8eD5FdkFkcmVzaTwveD4A', 'UklGRkwAAABXRUJQVlA4WAoAAAAAAAAADwAACwAAVlA4IC4AAACwAQCdASoQAAwAAUAmJaACdLoABDAAAP7x3I/4DdfFtMv/vYL/3YL/3YL/WwAA'),
};

bool _icerir(List<int> b, String s) => latin1.decode(b).contains(s);

void main() {
  for (final e in _fikstur.entries) {
    test('${e.key}: GPS/model/yorum/XMP ayıklanır, çıktı beklenenle birebir', () {
      final ham = base64.decode(e.value.$1);
      final temiz = GorselMetaTemizleyici.temizle(ham, 'image/${e.key}');
      expect(_icerir(ham, 'ModelY') || _icerir(ham, 'EvAdresi'), isTrue, reason: 'fikstür meta veri taşımalı');
      expect(_icerir(temiz, 'ModelY'), isFalse);
      expect(_icerir(temiz, 'EvAdresi'), isFalse);
      expect(_icerir(temiz, 'EKVERI'), isFalse);
      expect(temiz.length, lessThanOrEqualTo(ham.length));
      expect(base64.encode(temiz), e.value.$2);
    });
  }

  test('JPEG: yön (6) korunur, yalnız yön etiketli küçük EXIF yazılır', () {
    final temiz = GorselMetaTemizleyici.temizle(base64.decode(_fikstur['jpeg']!.$1), 'image/jpeg');
    final yon = [0x01, 0x12, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01, 0x00, 0x06];
    expect(latin1.decode(temiz).contains(latin1.decode(yon)), isTrue);
    expect(_icerir(temiz, 'Exif'), isTrue);
  });

  test('bozuk dosya FormatException verir (meta verili dosya sessizce gitmez)', () {
    expect(() => GorselMetaTemizleyici.temizle([0xFF, 0xD8, 0xFF, 0xE1, 0x00], 'image/jpeg'), throwsFormatException);
    expect(() => GorselMetaTemizleyici.temizle([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1], 'image/png'), throwsFormatException);
    expect(() => GorselMetaTemizleyici.temizle(latin1.encode('RIFF\x10\x00\x00\x00WEBPVP8 '), 'image/webp'), throwsFormatException);
  });

  test('desteklenmeyen tür (HEIC) değiştirilmeden döner', () {
    final b = [1, 2, 3, 4];
    expect(GorselMetaTemizleyici.temizle(b, 'image/heic'), b);
    expect(GorselMetaTemizleyici.destekleniyor('image/heic'), isFalse);
  });

  test('bütün yüklemeler temizleyiciden geçer (tek geçit: StorageApi.uploadBytes)', () {
    final k = File('lib/data/remote/api/storage_api.dart').readAsStringSync();
    expect(k.contains('GorselMetaTemizleyici.temizle(bytes, contentType)'), isTrue);
    expect(k.contains('body: temiz,'), isTrue);
  });
}
