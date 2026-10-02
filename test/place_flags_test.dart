import 'package:flutter_test/flutter_test.dart';
import 'package:gezgah/data/api.dart';
import 'package:gezgah/data/place_flags.dart';

void main() {
  group('parsePlusFlag', () {
    test('alan yoksa false', () {
      expect(parsePlusFlag({}), isFalse);
      expect(parsePlusFlag({'id': 1, 'name': 'x'}), isFalse);
    });

    test('is_plus doğru değerleri', () {
      for (final v in [true, 1, '1', 'true', ' TRUE ', 'evet', 'yes']) {
        expect(parsePlusFlag({'is_plus': v}), isTrue, reason: '$v');
      }
    });

    test('is_plus yanlış değerleri', () {
      for (final v in [false, 0, '0', '', null, 'abc']) {
        expect(parsePlusFlag({'is_plus': v}), isFalse, reason: '$v');
      }
    });

    test('yedek anahtarlar', () {
      expect(parsePlusFlag({'plus': 1}), isTrue);
      expect(parsePlusFlag({'isletme_plus': 'true'}), isTrue);
      expect(parsePlusFlag({'plus': {'aktif': true}}), isTrue);
      expect(parsePlusFlag({'plus': {'aktif': false}}), isFalse);
      expect(parsePlusFlag({'plus': <String, dynamic>{}}), isFalse);
    });

    test('null olmayan ilk anahtar belirleyici', () {
      expect(parsePlusFlag({'is_plus': false, 'plus': true}), isFalse);
      expect(parsePlusFlag({'is_plus': null, 'plus': true}), isTrue);
    });
  });

  group('ApiPlace önbellek', () {
    test('isPlus round-trip', () {
      const p = ApiPlace(id: 1, name: 'x', image: '', isPlus: true);
      final back = ApiPlace.fromCache(p.toCacheJson());
      expect(back.isPlus, isTrue);
    });

    test('eski önbellek (is_plus yok) → false', () {
      final back = ApiPlace.fromCache({'id': 1, 'name': 'x', 'image': ''});
      expect(back.isPlus, isFalse);
    });
  });
}
