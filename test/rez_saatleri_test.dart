import 'package:flutter_test/flutter_test.dart';
import 'package:gezgah/data/models.dart';
import 'package:gezgah/widgets/rez_time_picker.dart';

void main() {
  // Gezgah Kafe'nin canlıdaki çalışma saatleri (14.11.2026).
  const hours = {
    'pazartesi': '09:00 - 01:00',
    'sali': '00:00 - 23:59',
    'carsamba': 'Kapalı',
    'persembe': '09:00 - 01:00',
    'cuma': '09:00 - 01:00',
    'cumartesi': '11:10 - 23:30',
    'pazar': null,
  };
  // Geçmişten bağımsız olsun diye "şimdi" uzak geçmiş.
  final past = DateTime(2000);

  String hm(DateTime d) => rezHm(d);

  test('yalnız açık saatler, 15 dk, kapanıştan 30 dk önceye kadar', () {
    // 16.11.2026 Pazartesi 09:00 – 01:00 (gece yarısını aşar).
    final s = rezSaatleri(DateTime(2026, 11, 16), hours, now: past);
    expect(hm(s.first), '09:00');
    expect(hm(s[1]), '09:15');
    expect(hm(s.last), '00:30'); // 01:00 kapanış − 30 dk
    expect(s.last.day, 17); // ertesi gün
    expect(s.every((d) => d.minute % 15 == 0), isTrue);
  });

  test('açılış 15 dk katı değilse yukarı yuvarlanır', () {
    // 21.11.2026 Cumartesi 11:10 – 23:30.
    final s = rezSaatleri(DateTime(2026, 11, 21), hours, now: past);
    expect(hm(s.first), '11:15');
    expect(hm(s.last), '23:00');
  });

  test('kapalı, boş ya da bilinmeyen gün saat vermez', () {
    expect(rezSaatleri(DateTime(2026, 11, 18), hours, now: past), isEmpty);
    expect(rezSaatleri(DateTime(2026, 11, 22), hours, now: past), isEmpty);
  });

  test('00:00 - 23:59 gün boyu', () {
    final s = rezSaatleri(DateTime(2026, 11, 17), hours, now: past);
    expect(hm(s.first), '00:00');
    expect(hm(s.last), '23:15'); // 23:59 − 30 dk → 23:29 altı son 15'lik
  });

  test('bugün: şimdiden 30 dk öncesi listelenmez', () {
    final now = DateTime(2026, 11, 16, 20, 5);
    final s = rezSaatleri(DateTime(2026, 11, 16), hours, now: now);
    expect(hm(s.first), '20:45'); // 20:35 sonrası ilk 15'lik
  });

  test('çalışma saati bilgisi hiç yoksa varsayılan aralık', () {
    final s = rezSaatleri(DateTime(2026, 11, 16), const {}, now: past);
    expect(hm(s.first), '08:00');
    expect(hm(s.last), '23:30');
  });

  group('rezervasyon_saatleri (REZERVASYON_SAATLERI.md örneği)', () {
    // md'deki örnek yanıt.
    const calisma = {
      'pazartesi': '09:00 - 23:00',
      'sali': '09:00 - 23:00',
      'carsamba': '09:00 - 23:00',
      'persembe': '09:00 - 23:00',
      'cuma': '09:00 - 02:00',
      'cumartesi': 'Kapalı',
      'pazar': '10:00 - 22:00',
    };
    final rez = RezervasyonSecenekler.fromJson({
      'mekan_id': 2,
      'rezervasyon_saatleri': {
        'pazartesi': {'acik': false, 'baslangic': null, 'bitis': null},
        'sali': {'acik': true, 'baslangic': '12:00', 'bitis': '22:00'},
        'carsamba': {'acik': true, 'baslangic': null, 'bitis': null},
        'persembe': {'acik': true, 'baslangic': null, 'bitis': null},
        'cuma': {'acik': true, 'baslangic': '18:00', 'bitis': '01:00'},
        'cumartesi': {'acik': false, 'baslangic': null, 'bitis': null},
        'pazar': {'acik': true, 'baslangic': null, 'bitis': null},
      },
    }).rezervasyonSaatleri;

    List<DateTime> slots(DateTime d) =>
        rezSaatleri(d, calisma, rez: rez, now: past);

    test('rezervasyona kapalı gün (Pazartesi) saat vermez', () {
      expect(slots(DateTime(2026, 11, 16)), isEmpty);
    });

    test('Salı yalnız 12:00 – 22:00, iki uç dahil', () {
      final s = slots(DateTime(2026, 11, 17));
      expect(hm(s.first), '12:00');
      expect(hm(s.last), '22:00');
      expect(s.length, 41); // 12:00 … 22:00, 15 dk
    });

    test('kısıt yoksa çalışma saatleri (Çarşamba 09:00 – 22:30)', () {
      final s = slots(DateTime(2026, 11, 18));
      expect(hm(s.first), '09:00');
      expect(hm(s.last), '22:30');
    });

    test('Cuma 18:00 – 01:00: Cumartesi gecesi 00:00–01:00 da Cuma\'ya sayılır',
        () {
      final s = slots(DateTime(2026, 11, 20));
      expect(hm(s.first), '18:00');
      expect(hm(s.last), '01:00');
      expect(s.last.weekday, DateTime.saturday);
      // Cumartesi hem kapalı hem rezervasyona kapalı → kendi günü boş.
      expect(slots(DateTime(2026, 11, 21)), isEmpty);
    });

    test('rezSaatUygun: md\'deki JS kontrolüyle aynı sonuçlar', () {
      expect(rezSaatUygun(DateTime(2026, 11, 17, 11, 45), rez), isFalse);
      expect(rezSaatUygun(DateTime(2026, 11, 17, 12, 0), rez), isTrue);
      expect(rezSaatUygun(DateTime(2026, 11, 17, 22, 0), rez), isTrue);
      expect(rezSaatUygun(DateTime(2026, 11, 17, 22, 15), rez), isFalse);
      expect(rezSaatUygun(DateTime(2026, 11, 21, 0, 45), rez), isTrue);
      expect(rezSaatUygun(DateTime(2026, 11, 21, 1, 15), rez), isFalse);
      expect(rezSaatUygun(DateTime(2026, 11, 16, 20, 0), rez), isFalse);
    });

    test('bilgi metni', () {
      expect(
        rezAraligiMetni(DateTime(2026, 11, 17), rez),
        'Rezervasyon saatleri: 12:00 – 22:00',
      );
      expect(rezAraligiMetni(DateTime(2026, 11, 18), rez), isNull);
    });
  });
}
