import 'package:flutter/widgets.dart';

/// Mekan açık/kapanış durumu
enum OpenState { open, closing, closed }

class Place {
  final String name;
  final String category;
  String subtitle; // örn. "Geleneksel Türk · ₺₺" (mesafe sonradan eklenebilir)
  final double rating;
  String distance; // "1.2 km" (konuma göre hesaplanır)
  final String price; // "₺250"
  final String image;
  final OpenState state;
  final double lat;
  final double lng;
  final List<String> tags;
  final bool verified;
  final bool sponsored;
  final String date; // eklenme tarihi (ISO "2026-06-20"); sıralama için
  final List<int> filterIds; // aktif filtre id'leri (filtre_{id}=1)
  bool favorite;

  Place({
    required this.name,
    required this.category,
    required this.subtitle,
    required this.rating,
    required this.distance,
    required this.price,
    required this.image,
    this.state = OpenState.open,
    this.lat = 40.9875,
    this.lng = 29.0270,
    this.tags = const [],
    this.verified = false,
    this.sponsored = false,
    this.date = '',
    this.filterIds = const [],
    this.favorite = false,
  });
}

class EventItem {
  final String title;
  final String tag; // "🎵 Konser"
  final String day; // "14"
  final String month; // "Haz"
  final String location; // "Harbiye Açıkhava · 20:00"
  final String image;

  const EventItem({
    required this.title,
    required this.tag,
    required this.day,
    required this.month,
    required this.location,
    required this.image,
  });
}

class CategoryChip {
  final String label;
  final IconData icon;
  const CategoryChip(this.label, this.icon);
}

/// Ana sayfa "Tümü" kısayol öğesi (home_page_settings → section_key `tumu`).
/// İkon, id'ye göre `HomeConfig.iconFor` ile belirlenir (emoji kullanılmaz).
class HomeShortcut {
  final int id; // kategori post id (0 = "Tümü")
  final String name;
  const HomeShortcut(this.id, this.name);
}

/// Öne çıkan / sponsorlu etkinlik (home_page_settings → sponsorlu_etkinlikler
/// içindeki çözülmüş `events`).
class FeaturedEvent {
  final int id;
  final String name;
  final String date; // "2025-10-14"
  final String time; // "22:23"
  final String image;

  const FeaturedEvent({
    required this.id,
    required this.name,
    this.date = '',
    this.time = '',
    this.image = '',
  });
}

/// Filtre tanımı (`GET /filtreler`, FILTRELER.md).
class Filter {
  final int id;
  final String name;
  final String slug;
  final String type; // filter_type: restoran/plaj/...
  final String? icon; // SVG string (yoksa null)

  const Filter({
    required this.id,
    required this.name,
    this.slug = '',
    this.type = '',
    this.icon,
  });

  factory Filter.fromJson(Map<String, dynamic> j) => Filter(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] as String?)?.trim().isNotEmpty == true
            ? j['name'] as String
            : 'Filtre',
        slug: j['slug'] as String? ?? '',
        type: j['type'] as String? ?? '',
        icon: j['icon'] as String?,
      );
}

/// Sistem kategorisi (`GET /kategoriler`).
class Category {
  final int id;
  final String name;
  final String slug;
  final int mekanSayisi;
  const Category({
    required this.id,
    required this.name,
    this.slug = '',
    this.mekanSayisi = 0,
  });

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] as String?)?.trim().isNotEmpty == true
            ? j['name'] as String
            : 'Kategori',
        slug: j['slug'] as String? ?? '',
        mekanSayisi: (j['mekan_sayisi'] as num?)?.toInt() ?? 0,
      );
}

class QuickCategory {
  final String label;
  final IconData icon;
  const QuickCategory(this.label, this.icon);
}

class NotificationItem {
  final String title;
  final String body;
  final String time;
  final String group; // "Bugün", "Bu Hafta", "Daha Önce"
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  bool unread;

  NotificationItem({
    required this.title,
    required this.body,
    required this.time,
    required this.group,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    this.unread = true,
  });
}

class Amenity {
  final String name;
  final IconData icon;
  final bool available;
  const Amenity(this.name, this.icon, this.available);
}

class InfoRow {
  final String title;
  final String value;
  final IconData icon;
  const InfoRow(this.title, this.value, this.icon);
}
