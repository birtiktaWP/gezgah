import 'package:flutter/material.dart';
import 'models.dart';

/// HTML mockup'larındaki tüm örnek içerik buradan beslenir.
class MockData {
  // Hero başlığındaki daktilo efekti ifadeleri
  static const List<String> typedPhrases = [
    'lezzetlerini keşfet',
    'kafelerini keşfet',
    'mekanlarını keşfet',
    'etkinliklerini keşfet',
  ];

  // Ana kategori hapları
  static const List<CategoryChip> categories = [
    CategoryChip('Tümü', Icons.coffee_outlined),
    CategoryChip('Kafe', Icons.local_cafe_outlined),
    CategoryChip('Otel', Icons.apartment_outlined),
    CategoryChip('Eğlence', Icons.sentiment_satisfied_alt_outlined),
    CategoryChip('Müze', Icons.account_balance_outlined),
    CategoryChip('Doğa', Icons.park_outlined),
  ];

  // İkincil kare kategoriler
  static const List<QuickCategory> quickCategories = [
    QuickCategory('Kahvaltı', Icons.free_breakfast_outlined),
    QuickCategory('Sokak', Icons.ramen_dining_outlined),
    QuickCategory('Tatlı', Icons.cake_outlined),
    QuickCategory('Deniz', Icons.set_meal_outlined),
    QuickCategory('Bar', Icons.local_bar_outlined),
    QuickCategory('Fast', Icons.lunch_dining_outlined),
    QuickCategory('Vegan', Icons.eco_outlined),
    QuickCategory('7/24', Icons.access_time),
  ];

  // Kampanya kayan şerit metinleri
  static const List<String> promos = [
    '🔥 Hafta sonu tüm kahvelerde %30 indirim',
    '🍝 İlk siparişe özel ücretsiz tatlı',
    '🎉 Yeni üyelere 50₺ hoş geldin puanı',
    '📍 Kadıköy mekanlarında 2 al 1 öde',
  ];

  static const List<EventItem> events = [
    EventItem(
      title: 'İstanbul Caz Festivali',
      tag: '🎵 Konser',
      day: '14',
      month: 'Haz',
      location: 'Harbiye Açıkhava · 20:00',
      image:
          'https://images.unsplash.com/photo-1459749411175-04bf5292ceea?auto=format&fit=crop&w=640&q=70',
    ),
    EventItem(
      title: 'Sokak Lezzetleri Günü',
      tag: '🍴 Festival',
      day: '21',
      month: 'Haz',
      location: 'Moda Sahili · 12:00',
      image:
          'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=640&q=70',
    ),
    EventItem(
      title: 'Yaz Akşamı Konserleri',
      tag: '🎤 Sahne',
      day: '28',
      month: 'Haz',
      location: 'Kadıköy Sahne · 21:00',
      image:
          'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=640&q=70',
    ),
  ];

  static final List<Place> popular = [
    Place(
      name: 'Karaköy Lokantası',
      category: 'Türk Mutfağı',
      subtitle: 'Türk Mutfağı · 1.1 km',
      rating: 4.9,
      distance: '1.1 km',
      price: '₺₺',
      image:
          'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=420&q=70',
      tags: ['restoran'],
      favorite: true,
    ),
    Place(
      name: 'Moda Sahil Kafe',
      category: 'Kahve & Tatlı',
      subtitle: 'Kahve & Tatlı · 0.6 km',
      rating: 4.7,
      distance: '0.6 km',
      price: '₺₺',
      image:
          'https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&w=420&q=70',
      tags: ['kafe', 'tatlı'],
    ),
    Place(
      name: 'Topkapı Sarayı',
      category: 'Tarihi Mekan',
      subtitle: 'Tarihi Mekan · 4.2 km',
      rating: 4.8,
      distance: '4.2 km',
      price: '₺',
      image:
          'https://images.unsplash.com/photo-1524231757912-21f4fe3a7200?auto=format&fit=crop&w=420&q=70',
      tags: ['müze'],
    ),
  ];

  static final List<Place> nearby = [
    Place(
      name: 'Çiya Sofrası',
      category: 'Geleneksel Türk',
      subtitle: 'Geleneksel Türk · ₺₺',
      rating: 4.8,
      distance: '1.2 km',
      price: '₺250',
      image:
          'https://images.unsplash.com/photo-1601050690597-df0568f70950?auto=format&fit=crop&w=420&q=70',
      state: OpenState.open,
      favorite: true,
      tags: ['restoran'],
    ),
    Place(
      name: 'Forno İtalyan',
      category: 'Pizza & Makarna',
      subtitle: 'Pizza & Makarna · ₺₺',
      rating: 4.6,
      distance: '0.8 km',
      price: '₺320',
      image:
          'https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&w=420&q=70',
      state: OpenState.open,
      tags: ['restoran'],
    ),
    Place(
      name: 'Sakura Sushi',
      category: 'Suşi',
      subtitle: 'Suşi · ₺₺₺',
      rating: 4.9,
      distance: '2.4 km',
      price: '₺480',
      image:
          'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?auto=format&fit=crop&w=420&q=70',
      state: OpenState.closing,
      tags: ['suşi', 'restoran'],
    ),
    Place(
      name: 'Yeşil Bahçe',
      category: 'Vejetaryen',
      subtitle: 'Vejetaryen · ₺₺',
      rating: 4.5,
      distance: '1.6 km',
      price: '₺190',
      image:
          'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=420&q=70',
      state: OpenState.open,
      tags: ['vegan', 'restoran'],
    ),
  ];

  // Kategori (Kahvaltı) liste ekranı verisi
  static final List<Place> categoryList = [
    Place(
      name: 'Coffee Lab',
      category: 'Kahve & Brunch',
      subtitle: 'Kahve & Brunch · ₺₺',
      rating: 4.7,
      distance: '0.7 km',
      price: '%25 indirim',
      image:
          'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=640&q=70',
      sponsored: true,
      verified: true,
      state: OpenState.open,
    ),
    Place(
      name: 'Van Kahvaltı Evi',
      category: 'Serpme Kahvaltı',
      subtitle: 'Serpme Kahvaltı · ₺₺',
      rating: 4.8,
      distance: '0.9 km',
      price: '₺220 / kişi',
      image:
          'https://images.unsplash.com/photo-1533089860892-a7c6f0a88666?auto=format&fit=crop&w=640&q=70',
      state: OpenState.open,
      favorite: true,
    ),
    Place(
      name: 'Bahçe Kahvaltı',
      category: 'Köy Kahvaltısı',
      subtitle: 'Köy Kahvaltısı · ₺₺',
      rating: 4.6,
      distance: '1.4 km',
      price: '₺180 / kişi',
      image:
          'https://images.unsplash.com/photo-1525351484163-7529414344d8?auto=format&fit=crop&w=640&q=70',
      state: OpenState.open,
    ),
    Place(
      name: 'Günaydın Brunch',
      category: 'Brunch & Kahve',
      subtitle: 'Brunch & Kahve · ₺₺₺',
      rating: 4.5,
      distance: '2.1 km',
      price: '₺340 / kişi',
      image:
          'https://images.unsplash.com/photo-1490645935967-10de6ba17061?auto=format&fit=crop&w=640&q=70',
      state: OpenState.closing,
    ),
    Place(
      name: 'Sahil Kahvaltı',
      category: 'Deniz Manzaralı',
      subtitle: 'Deniz Manzaralı · ₺₺',
      rating: 4.7,
      distance: '1.8 km',
      price: '₺200 / kişi',
      image:
          'https://images.unsplash.com/photo-1504754524776-8f4f37790ca0?auto=format&fit=crop&w=640&q=70',
      state: OpenState.open,
    ),
    Place(
      name: 'Köşe Kahvaltı',
      category: 'Klasik Kahvaltı',
      subtitle: 'Klasik Kahvaltı · ₺',
      rating: 4.4,
      distance: '0.5 km',
      price: '₺150 / kişi',
      image:
          'https://images.unsplash.com/photo-1551218808-94e220e084d2?auto=format&fit=crop&w=640&q=70',
      state: OpenState.open,
    ),
  ];

  // Harita için mekanlar (Kadıköy çevresi)
  static final List<Place> mapPlaces = [
    Place(
      name: 'Petra Roasting Co.',
      category: 'Kahve & Brunch',
      subtitle: 'Kahve & Brunch',
      rating: 4.9,
      distance: '3.5 km',
      price: '₺₺',
      image:
          'https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&w=320&q=70',
      lat: 40.9810,
      lng: 29.0270,
      tags: ['kafe'],
    ),
    Place(
      name: 'Çiya Sofrası',
      category: 'Geleneksel Türk',
      subtitle: 'Geleneksel Türk',
      rating: 4.8,
      distance: '1.2 km',
      price: '₺250',
      image:
          'https://images.unsplash.com/photo-1601050690597-df0568f70950?auto=format&fit=crop&w=320&q=70',
      lat: 40.9905,
      lng: 29.0258,
      tags: ['restoran'],
    ),
    Place(
      name: 'Forno İtalyan',
      category: 'Pizza & Makarna',
      subtitle: 'Pizza & Makarna',
      rating: 4.6,
      distance: '0.8 km',
      price: '₺320',
      image:
          'https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&w=320&q=70',
      lat: 40.9868,
      lng: 29.0331,
      tags: ['restoran'],
    ),
    Place(
      name: 'Sakura Sushi',
      category: 'Suşi',
      subtitle: 'Suşi',
      rating: 4.9,
      distance: '2.4 km',
      price: '₺480',
      image:
          'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?auto=format&fit=crop&w=320&q=70',
      lat: 40.9942,
      lng: 29.0292,
      tags: ['suşi', 'restoran'],
    ),
    Place(
      name: 'Moda Sahil Kafe',
      category: 'Kahve & Tatlı',
      subtitle: 'Kahve & Tatlı',
      rating: 4.7,
      distance: '0.6 km',
      price: '₺180',
      image:
          'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=320&q=70',
      lat: 40.9772,
      lng: 29.0248,
      tags: ['kafe', 'tatlı'],
    ),
    Place(
      name: 'Yeşil Bahçe',
      category: 'Vejetaryen',
      subtitle: 'Vejetaryen',
      rating: 4.5,
      distance: '1.6 km',
      price: '₺190',
      image:
          'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=320&q=70',
      lat: 40.9931,
      lng: 29.0205,
      tags: ['vegan', 'restoran'],
    ),
  ];

  static const List<CategoryChip> mapCategories = [
    CategoryChip('Tümü', Icons.search),
    CategoryChip('Kafe', Icons.local_cafe_outlined),
    CategoryChip('Restoran', Icons.restaurant_outlined),
    CategoryChip('Suşi', Icons.set_meal_outlined),
    CategoryChip('Tatlı', Icons.cake_outlined),
    CategoryChip('Vegan', Icons.eco_outlined),
  ];

  // Detay ekranı için etkinlikler
  static const List<EventItem> detailEvents = [
    EventItem(
      title: 'Akustik Gece',
      tag: '',
      day: '14',
      month: 'Haz',
      location: 'Cumartesi · 20:00',
      image:
          'https://images.unsplash.com/photo-1459749411175-04bf5292ceea?auto=format&fit=crop&w=420&q=70',
    ),
    EventItem(
      title: 'Kahve Tadımı',
      tag: '',
      day: '18',
      month: 'Haz',
      location: 'Çarşamba · 15:00',
      image:
          'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=420&q=70',
    ),
    EventItem(
      title: 'DJ Performans',
      tag: '',
      day: '21',
      month: 'Haz',
      location: 'Cumartesi · 22:00',
      image:
          'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=420&q=70',
    ),
  ];

  static const List<InfoRow> detailInfo = [
    InfoRow('Çalışma Saatleri', 'Her gün 08:00 - 23:00', Icons.access_time),
    InfoRow('İletişim', '0216 000 00 00', Icons.phone_outlined),
    InfoRow('Instagram', '@petraroasting', Icons.camera_alt_outlined),
  ];

  static const List<Amenity> detailAmenities = [
    Amenity('Otopark', Icons.local_parking_outlined, true),
    Amenity('Dijital Menü', Icons.qr_code_2, true),
    Amenity('Ücretsiz Wi-Fi', Icons.wifi, true),
    Amenity('Çalışma Alanı', Icons.work_outline, true),
    Amenity('Çocuk Alanı', Icons.child_care_outlined, false),
    Amenity('Alkol', Icons.local_bar_outlined, false),
  ];

  static const String aboutText =
      'Petra Roasting Co., 2018 yılında Moda\'da açılan butik bir kahve dükkânıdır. '
      'Özel olarak seçilmiş tek kökenli kahve çekirdeklerini kendi kavurma tesisinde '
      'kavuruyor ve en taze şekilde sunuyor. Mekan, hem kahve tutkunları hem de sakin '
      'bir ortamda çalışmak isteyenler için ideal bir atmosfer sunuyor…';

  static final List<Place> detailSimilar = [
    Place(
      name: 'Norm Coffee',
      category: 'Üçüncü Dalga',
      subtitle: 'Üçüncü Dalga · 1.2 km',
      rating: 4.8,
      distance: '1.2 km',
      price: '₺₺',
      image:
          'https://images.unsplash.com/photo-1453614512568-c4024d13c247?auto=format&fit=crop&w=420&q=70',
    ),
    Place(
      name: 'Kronotrop',
      category: 'Kavurma',
      subtitle: 'Kavurma · 2.0 km',
      rating: 4.7,
      distance: '2.0 km',
      price: '₺₺',
      image:
          'https://images.unsplash.com/photo-1442512595331-e89e73853f31?auto=format&fit=crop&w=420&q=70',
    ),
    Place(
      name: 'Coffee Sapiens',
      category: 'Espresso Bar',
      subtitle: 'Espresso Bar · 2.8 km',
      rating: 4.6,
      distance: '2.8 km',
      price: '₺₺',
      image:
          'https://images.unsplash.com/photo-1493857671505-72967e2e2760?auto=format&fit=crop&w=420&q=70',
    ),
  ];

  static final List<NotificationItem> notifications = [
    NotificationItem(
      title: 'Petra Roasting Co.',
      body: 'Yakınındaki favori mekanında bugün %25 indirim seni bekliyor.',
      time: '2 saat önce',
      group: 'Bugün',
      icon: Icons.local_offer_outlined,
      iconColor: const Color(0xFFE8943A),
      iconBg: const Color(0x1FE8943A),
    ),
    NotificationItem(
      title: 'Yeni rozet kazandın 🎉',
      body: '"Kafe Avcısı" rozetini kazandın. Profilinden görebilirsin.',
      time: '5 saat önce',
      group: 'Bugün',
      icon: Icons.star_rounded,
      iconColor: const Color(0xFF120C63),
      iconBg: const Color(0x12120C63),
    ),
    NotificationItem(
      title: 'İstanbul Caz Festivali',
      body: 'İlgilendiğin etkinliğin biletleri satışa çıktı.',
      time: '2 gün önce',
      group: 'Bu Hafta',
      icon: Icons.calendar_today_outlined,
      iconColor: const Color(0xFF16A34A),
      iconBg: const Color(0x1F16A34A),
    ),
    NotificationItem(
      title: 'Çiya Sofrası',
      body: 'Yaptığın değerlendirme 12 kişi tarafından beğenildi.',
      time: '3 gün önce',
      group: 'Bu Hafta',
      icon: Icons.favorite,
      iconColor: const Color(0xFFFF3D6E),
      iconBg: const Color(0x1FFF3D6E),
      unread: false,
    ),
    NotificationItem(
      title: 'Gezgah\'a hoş geldin!',
      body: 'Hesabın hazır. 50₺ değerinde hoş geldin puanı hediyen tanımlandı.',
      time: '1 hafta önce',
      group: 'Daha Önce',
      icon: Icons.card_giftcard,
      iconColor: const Color(0xFF120C63),
      iconBg: const Color(0x12120C63),
      unread: false,
    ),
  ];

  // Arama modalı
  static const List<String> popularSearches = [
    'Brunch',
    'Üçüncü dalga kahve',
    'Deniz manzaralı',
    'Gece açık',
    'Canlı müzik',
    'Vegan',
  ];

  static const List<String> kedyTips = [
    'Sessiz çalışma kafeleri',
    'Yağmurlu güne uygun',
    'İlk buluşma için',
    'Bütçe dostu lezzetler',
    'Manzaralı kahvaltı',
    'Evcil hayvan dostu',
  ];

  // Kedy chatbot hazır mesajlar
  static const List<String> kedySuggests = [
    'Yakında kahve nerede?',
    'En iyi kahvaltı mekanı',
    'Gece geç saatte açık',
    'Canlı müzik var mı?',
  ];

  // Sözleşme dökümanları
  static const Map<String, String> documents = {
    'Kullanıcı Sözleşmesi':
        'İşbu Kullanıcı Sözleşmesi, Gezgah uygulamasını kullanan kullanıcı ile Gezgah '
            'arasında, hizmetin kullanım koşullarını düzenlemek amacıyla akdedilmiştir.\n\n'
            'Gezgah; yakın çevredeki mekanları, etkinlikleri ve kampanyaları keşfetmenizi '
            'sağlayan bir rehber hizmetidir. Mekanlara ilişkin bilgiler bilgilendirme amaçlıdır.\n\n'
            'Kullanıcı, uygulamayı yürürlükteki mevzuata ve dürüstlük kurallarına uygun '
            'şekilde kullanmayı kabul eder.',
    'Gizlilik Politikası':
        'Konum bilginiz, yalnızca yakınınızdaki mekanları gösterebilmek için ve izniniz '
            'dahilinde işlenir.\n\nToplanan veriler, hizmet kalitesini artırmak ve size uygun '
            'öneriler sunmak için kullanılır; üçüncü taraflarla pazarlama amacıyla paylaşılmaz.\n\n'
            'Verileriniz uygun teknik ve idari tedbirlerle korunur.',
    'KVKK Aydınlatma Metni':
        '6698 sayılı Kişisel Verilerin Korunması Kanunu uyarınca veri sorumlusu Gezgah\'tır.\n\n'
            'Kişisel verileriniz; hizmetin sunulması, hesabınızın yönetilmesi ve yasal '
            'yükümlülüklerin yerine getirilmesi amacıyla işlenir.\n\nKVKK m.11 kapsamında '
            'verilerinize erişme, düzeltme ve silinmesini talep etme haklarına sahipsiniz.',
    'Çerez Politikası':
        'Çerezler, uygulamayı kullanımınız sırasında cihazınıza kaydedilen küçük metin '
            'dosyalarıdır.\n\nÇerezler; tercihlerinizi hatırlamak ve deneyiminizi iyileştirmek '
            'için kullanılır.\n\nÇerez tercihlerinizi cihaz veya tarayıcı ayarlarınızdan '
            'dilediğiniz zaman değiştirebilirsiniz.',
  };
}
