import 'package:flutter_test/flutter_test.dart';
import 'package:gezgah/data/api.dart';

void main() {
  group('idsCsv', () {
    test('boş/null → boş string (parametre gönderilmez)', () {
      expect(idsCsv(null), '');
      expect(idsCsv(const []), '');
    });

    test('sıralı, virgüllü', () {
      expect(idsCsv([40, 3, 12]), '3,12,40');
      expect(idsCsv({7}), '7');
    });
  });

  group('SearchResult özellik eşleşmesi', () {
    const place = ApiPlace(id: 1, name: 'Test', image: '');

    test('varsayılan: eşleşme yok', () {
      const r = SearchResult(place: place);
      expect(r.matchedOzellikler, isEmpty);
      expect(r.matchedByOzellik, isFalse);
    });

    test('eslesme içinde "ozellik"', () {
      const r = SearchResult(place: place, matchTypes: ['ozellik']);
      expect(r.matchedByOzellik, isTrue);
    });

    test('eslesen_ozellikler dolu', () {
      const r = SearchResult(place: place, matchedOzellikler: ['Bahçe']);
      expect(r.matchedByOzellik, isTrue);
    });
  });
}
