import 'package:flutter_test/flutter_test.dart';
import 'package:gezgah/data/kampanya.dart';

void main() {
  // KAMPANYALAR.md §1 örnek satırı.
  final row = {
    'mekan': {
      'id': 2,
      'type': 'restoran',
      'name': 'Gezgah Kafe',
      'thumbnail': 'https://x/kapak.jpg',
      'thumbnails': {'square': 'https://x/s.webp', 'wide': 'https://x/w.webp'},
      'sehir': 'İstanbul',
      'ilce': 'Beşiktaş',
      'kordinat': '41.0430, 29.0070',
      'mesafe_m': 14241,
    },
    'en_yuksek_indirim': 30,
    'kampanya_sayisi': 2,
    'kampanyalar': [
      {
        'id': 12,
        'mekan_id': 2,
        'tip': 'urun',
        'baslik': 'Seçili ürünlerde %30 indirim',
        'aciklama': 'Hafta içi geçerli',
        'indirim_orani': 30,
        'bitis': '2026-11-21T23:59:59+03:00',
        'kullanim_limiti': null,
        'kalan_kullanim': null,
        'urun_sayisi': 2,
      },
      {
        'id': 11,
        'mekan_id': 2,
        'tip': 'genel',
        'baslik': null,
        'indirim_orani': 15,
        'bitis': null,
        'kullanim_limiti': 50,
        'kullanim_sayisi': 45,
        'kalan_kullanim': 5,
      },
    ],
  };

  test('liste satırı', () {
    final m = KampanyaliMekan.fromJson(row);
    expect(m.mekan.id, 2);
    expect(m.mekan.thumbWide, 'https://x/w.webp');
    expect(m.mekan.thumbCard, 'https://x/kapak.jpg'); // card yok → thumbnail
    expect(m.mekan.lat, closeTo(41.043, 1e-6));
    expect(m.enYuksekIndirim, 30);
    expect(m.kampanyalar.length, 2);
    final u = m.kampanyalar[0], g = m.kampanyalar[1];
    expect(u.urunBazli, isTrue);
    expect(u.kapsam, '2 üründe geçerli');
    expect(g.gosterilenBaslik, 'Tüm menüde %15 indirim'); // başlık boş
    expect(g.kapsam, 'Tüm menüde geçerli');
    expect(g.kontenjan(), 'Son 5 kişi');
    expect(u.kontenjan(), isNull);
    expect(g.kalanSure(), isNull);
  });

  test('kalan süre', () {
    final k = Kampanya(id: 1, bitis: DateTime(2026, 11, 21, 23, 59, 59));
    expect(k.kalanSure(now: DateTime(2026, 11, 21, 10)), 'Bugün son gün');
    expect(k.kalanSure(now: DateTime(2026, 11, 19, 10)), 'Son 3 gün');
    expect(k.kalanSure(now: DateTime(2026, 11, 1)), "21 Kasım'a kadar");
    expect(k.kalanSure(now: DateTime(2026, 11, 22)), 'Süresi doldu');
  });

  test('detay: durum, ürünler, kullanımım', () {
    final k = Kampanya.fromJson({
      'id': 12,
      'tip': 'urun',
      'indirim_orani': 30,
      'durum': 'limit_doldu',
      'aktif': false,
      'urunler': [
        {
          'id': 19067,
          'ad': 'Zeus Kahvaltı (2 Kişilik)',
          'fiyat': 2000,
          'indirimli_fiyat': 1400,
        },
        {'id': 1, 'ad': 'Fiyatsız', 'fiyat': null, 'indirimli_fiyat': null},
      ],
      'kullanimim': {'kod': 'K7M2QX', 'tarih': '2026-11-14T23:41:07+03:00'},
    });
    expect(k.aktif, isFalse);
    expect(k.pasifNedeni, 'Kontenjan doldu');
    expect(k.urunler.first.indirimliFiyat, 1400);
    expect(k.urunler.last.fiyat, isNull);
    expect(k.kullanimim?.kod, 'K7M2QX');
    expect(Kampanya.fromJson({'id': 3, 'kullanimim': null}).kullanimim, isNull);
  });
}
