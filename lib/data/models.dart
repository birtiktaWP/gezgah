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
