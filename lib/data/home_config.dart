import 'package:flutter/material.dart';
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
    HomeShortcut(138, 'Eczane'),
    HomeShortcut(62, 'Otopark'),
    HomeShortcut(139, 'Müze'),
    HomeShortcut(140, 'Mesire'),
    HomeShortcut(1081, 'Kahvaltı'),
    HomeShortcut(128, 'Tatlı & Fırın'),
    HomeShortcut(129, 'Fast Food'),
    HomeShortcut(1254, 'Balık'),
    HomeShortcut(1199, 'Çay Bahçesi'),
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
    1254: Icons.set_meal_outlined, // Balık
    1199: Icons.emoji_food_beverage_outlined, // Çay Bahçesi
    1: Icons.local_cafe_outlined, // Kafe
    122: Icons.restaurant_outlined, // Restoran
  };

  static IconData iconFor(int id) =>
      categoryIcons[id] ?? Icons.restaurant_outlined;
}
