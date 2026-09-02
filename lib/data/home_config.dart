import 'package:flutter/material.dart';
import '../widgets/app_icons.dart';
import 'models.dart';

/// Ana sayfa alan yapılandırması — `home_page_settings` tablosundaki
/// `settings` JSON'larının uygulama tarafı karşılığı.
///
/// Canlı API'de henüz bir `home_page_settings` endpoint'i yayınlanmadığı için
/// (bkz. HOME_PAGE_SETTINGS.md) section yapılandırması burada dokümandaki
/// örnek değerlerle sabit tutulur. İçerik (kategori adları, restoran
/// bilgileri, yakındakiler, yeni eklenenler) çalışan REST endpoint'lerinden
/// dinamik olarak çekilir. Endpoint yayınlandığında bu sabitler tek noktadan
/// API çağrısıyla değiştirilebilir.
class HomeConfig {
  HomeConfig._();

  /// section_key: `tumu` — yatay kısayol satırı (ikonlar id'ye göre).
  /// "Tümü" (id 0) kaldırıldı; alan doğrudan kategori kısayolları ile başlar.
  static const List<HomeShortcut> tumu = [
    HomeShortcut(62, 'Otopark', type: 'otopark'),
    HomeShortcut(140, 'Mesire', type: 'mesire'),
    HomeShortcut(0, 'Plaj', type: 'plaj'),
  ];

  /// section_key: `kahvalti_sokak_tatli` — vitrin kategori id'leri.
  static const List<int> kategoriSecim = [1081, 129, 1050, 128];

  /// section_key: `sponsorlu_restoranlar` — öne çıkarılan restoran id'leri.
  static const List<int> sponsorluRestoranlar = [2, 1063, 1080, 1099];

  /// Bilinen kategori id'leri için ikon eşlemesi (API kategori kaydında ikon
  /// yok). Eşleşmeyenlerde varsayılan ikon kullanılır.
  static const Map<int, IconData> categoryIcons = {
    1081: Icons.free_breakfast_outlined, // Kahvaltı
    129: Icons.lunch_dining_outlined, // Fast Food
    1050: Icons.kebab_dining_outlined, // Döner
    128: Icons.cake_outlined, // Tatlı & Fırın
    138: Icons.local_pharmacy_outlined, // Eczane
    62: Icons.local_parking_outlined, // Otopark
    139: Icons.account_balance_outlined, // Müze
    140: Icons.park_outlined, // Mesire
    0: Icons.beach_access_outlined, // Plaj
    1254: Icons.set_meal_outlined, // Balık
    1199: Icons.emoji_food_beverage_outlined, // Çay Bahçesi
    1: Icons.local_cafe_outlined, // Kafe
    122: Icons.restaurant_outlined, // Restoran
  };

  static IconData iconFor(int id) =>
      categoryIcons[id] ?? Icons.restaurant_outlined;

  /// Otopark alt tipleri için ikon (kategori adı/slug ya da filtre adı verilir).
  /// Kategori çipleri, harita pinleri ve filtre listesi aynı eşlemeyi kullanır
  /// ki "Açık / Kapalı / Katlı / İSPARK" her yerde aynı görünsün.
  /// Eşleşme yoksa `null` döner (çağıran kendi varsayılanına düşer).
  static IconData? otoparkIconFor(String text) {
    final s = text.toLowerCase();
    bool has(String k) => s.contains(k);
    // "İSPARK" varyantları (İ/i küçültme farkı için 'spark' aranır).
    if (has('spark')) return Icons.location_city_outlined;
    if (has('katlı') || has('katli')) return Icons.layers_outlined;
    if (has('kapalı') || has('kapali')) return Icons.garage_outlined;
    if (has('açık') || has('acik')) return Icons.wb_sunny_outlined;
    if (has('yol üstü') || has('yol ustu') || has('yol-ustu')) {
      return Icons.add_road;
    }
    if (has('özel') || has('ozel')) return Icons.lock_outline;
    if (has('vale')) return Icons.directions_car_outlined;
    if (has('otopark') || has('otopak') || has('park')) {
      return Icons.local_parking;
    }
    return null;
  }

  /// Bazı kategoriler için SVG ikonu (Font Awesome). Verilirse Material ikon
  /// yerine bu kullanılır (bkz. AppIcons). Eşleşmezse null.
  static String? svgFor(int id) => _categorySvg[id];

  static const Map<int, String> _categorySvg = {
    139: AppIcons.muze, // Müze
    140: AppIcons.mesire, // Mesire
  };

  /// İşletmeye özel harita ikonları — API'nin `custom_ikon` alanındaki anahtar
  /// (slug) app içindeki bu sete eşlenir. Doluysa haritada bu ikon gösterilir;
  /// boş/tanımsızsa kategori ikonuna (ardından varsayılana) düşülür.
  ///
  /// Backend bu anahtarlardan birini göndermelidir (ör. `custom_ikon: "pizza"`).
  static const Map<String, IconData> customIcons = {
    'kahve': Icons.local_cafe_outlined,
    'kahvalti': Icons.free_breakfast_outlined,
    'restoran': Icons.restaurant_outlined,
    'fastfood': Icons.lunch_dining_outlined,
    'doner': Icons.kebab_dining_outlined,
    'tatli': Icons.cake_outlined,
    'pizza': Icons.local_pizza_outlined,
    'balik': Icons.set_meal_outlined,
    'bar': Icons.local_bar_outlined,
    'cay': Icons.emoji_food_beverage_outlined,
    'muze': Icons.account_balance_outlined,
    'park': Icons.park_outlined,
    'plaj': Icons.beach_access_outlined,
    'otel': Icons.hotel_outlined,
    'eczane': Icons.local_pharmacy_outlined,
    'otopark': Icons.local_parking_outlined,
    'vegan': Icons.eco_outlined,
    'yildiz': Icons.star_outline,
    'kalp': Icons.favorite_border,
    'muzik': Icons.music_note_outlined,
    'etkinlik': Icons.celebration_outlined,
  };

  /// `custom_ikon` anahtarını app içi ikona çevirir; boş/tanımsızsa `null`
  /// (çağıran kategori ikonuna düşer).
  static IconData? customIconFor(String key) {
    final k = key.trim().toLowerCase();
    if (k.isEmpty) return null;
    return customIcons[k];
  }
}
