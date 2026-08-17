# Gezgah — Gezi Rotası: Uygulama İçi Harita

Rotayı harici Google Maps yerine **uygulama içindeki haritada** (`google_maps_flutter`) göster:
sıralı numaralı marker'lar + rota çizgisi + markera dokununca mekan detayına gitme.

> **DURUM: CANLI — uygulandı.** Aşağıdaki tüm alanlar `GET /uye/rotalar/{id}` yanıtında döner
> (madde 1 + 2 + 3-B dahil). Diğer uçlar değişmedi; `harita_link` alanları korundu.

- Uç: `GET /uye/rotalar/{id}`
- Başlıklar: `X-App-Key: <app_key>` + `Authorization: Bearer <token>`
- Koordinat kaynağı: mekan metaları (`kordinat` / `plaj_kordinat` / `mesire_kordinat`); sunucu
  parse edip **sayısal** döndürür (istemci string ayrıştırmaz).

---

## 1. Her durak için koordinat — `duraklar[].mekan.lat` / `lng`

```json
{
  "durak_id": 11, "sira": 1, "yorum": "Kahve iç",
  "mekan": {
    "id": 1064,
    "name": "Favolin",
    "ilce": "Kadıköy",
    "lat": 40.9901,
    "lng": 29.0270
  },
  "secili_urun": { "qr_id": 5, "ad": "Latte", "fiyat": "100", "gorsel": "..." },
  "harita_link": "https://www.google.com/maps/search/?api=1&query=40.9901,29.0270"
}
```
- `lat`/`lng` **number** tipinde (string değil). Koordinatı olmayan mekanda `lat: null, lng: null`.

---

## 2. Rota seviyesinde sıralı koordinat listesi — `rota.koordinatlar[]`

Haritayı tek alanla çizmek için. Koordinatı olmayan duraklar listeye **dahil edilmez**.

```json
"koordinatlar": [
  { "sira": 1, "durak_id": 11, "post_id": 1064, "name": "Favolin",      "lat": 40.9901, "lng": 29.0270 },
  { "sira": 2, "durak_id": 12, "post_id": 2091, "name": "Ada Restoran", "lat": 41.0082, "lng": 28.9784 }
]
```
- `post_id` = markera dokununca mekan detayını (`GET /mekanlar/{id}`) açmak için.
- Sıra durakların sırasına göredir (sıralama değişirse liste de değişir).

---

## 3. Gerçek yol çizgisi — `rota.polyline` (+ mesafe/süre) · CANLI

Backend Google **Directions API** ile hesaplayıp **encoded polyline** + özet döndürür (Redis'te 1 gün cache):

```json
"polyline": "e|hkFwd...encoded_polyline...",
"toplam_mesafe_m": 5200,
"toplam_sure_sn": 1200
```
- `polyline`: Google encoded polyline → uygulamada `flutter_polyline_points` ile `decodePolyline()` yapıp çiz.
- `toplam_mesafe_m` (metre) / `toplam_sure_sn` (saniye): rota özeti (opsiyonel gösterim).
- Directions anahtarı sunucuda ayarlı (`config/maps.php`). Servis hata verirse **hepsi `null`** →
  uygulama otomatik olarak `koordinatlar`'ı **düz çizgiyle** bağlamaya düşer.
- Duraklar/sıra değişince otomatik yeniden hesaplanır (cache anahtarı koordinatlara bağlı).

### Flutter (özet)
```dart
final koordinatlar = (rota['koordinatlar'] as List);

final markers = <Marker>{
  for (final n in koordinatlar)
    Marker(
      markerId: MarkerId('durak_${n['durak_id']}'),
      position: LatLng((n['lat'] as num).toDouble(), (n['lng'] as num).toDouble()),
      infoWindow: InfoWindow(title: '${n['sira']}. ${n['name'] ?? ''}'),
      onTap: () => openMekan(n['post_id']), // GET /mekanlar/{id}
    )
};

// Rota çizgisi: yol-takipli polyline varsa onu, yoksa düz çizgi.
final enc = rota['polyline'] as String?;
final points = (enc != null && enc.isNotEmpty)
    ? PolylinePoints().decodePolyline(enc).map((p) => LatLng(p.latitude, p.longitude)).toList()
    : [ for (final n in koordinatlar) LatLng((n['lat'] as num).toDouble(), (n['lng'] as num).toDouble()) ];
final polyline = Polyline(polylineId: const PolylineId('rota'), width: 4, points: points);
// Kamera: tüm noktaları sığdır (fitBounds).
```

---

## 4. Özet Kontrol Listesi

- [x] `duraklar[].mekan.lat` + `lng` (number).
- [x] `rota.koordinatlar[]` (sıralı: `sira, durak_id, post_id, name, lat, lng`).
- [x] `rota.polyline` + `toplam_mesafe_m` + `toplam_sure_sn` (Google Directions, canlı).
- [x] Mevcut `harita_link` alanları korunuyor (harici "Google Haritalar'da aç").
- [x] Koordinatı olmayan duraklar `lat/lng: null` ve `koordinatlar` listesine dahil değil.

---

## 5. Örnek Tam Yanıt

```json
{
  "success": true,
  "data": {
    "rota": {
      "id": 5, "baslik": "Kadıköy Turu", "rota_fiyat": 450.0,
      "harita_link": "https://www.google.com/maps/dir/40.9901,29.0270/41.0082,28.9784",
      "koordinatlar": [
        { "sira": 1, "durak_id": 11, "post_id": 1064, "name": "Favolin",      "lat": 40.9901, "lng": 29.0270 },
        { "sira": 2, "durak_id": 12, "post_id": 2091, "name": "Ada Restoran", "lat": 41.0082, "lng": 28.9784 }
      ],
      "polyline": "e|hkFwd...",
      "toplam_mesafe_m": 5200,
      "toplam_sure_sn": 1200,
      "sahip": { "uye_id": 12, "isim": "Ada", "soyisim": "Yılmaz", "avatar": "..." },
      "duraklar": [
        {
          "durak_id": 11, "sira": 1, "yorum": "Kahve iç",
          "mekan": { "id": 1064, "name": "Favolin", "ilce": "Kadıköy", "lat": 40.9901, "lng": 29.0270 },
          "secili_urun": { "qr_id": 5, "ad": "Latte", "fiyat": "100", "gorsel": "..." },
          "harita_link": "https://www.google.com/maps/search/?api=1&query=40.9901,29.0270"
        },
        {
          "durak_id": 12, "sira": 2, "yorum": null,
          "mekan": { "id": 2091, "name": "Ada Restoran", "lat": 41.0082, "lng": 28.9784 },
          "secili_urun": null,
          "harita_link": "https://www.google.com/maps/search/?api=1&query=41.0082,28.9784"
        }
      ]
    }
  }
}
```

---

## 6. Notlar

- Bu değişiklik yalnız `GET /uye/rotalar/{id}` yanıtını genişletir; şema/tablo değişikliği yok.
- Koordinatlar mevcut mekan metalarından (`kordinat` / `plaj_kordinat` / `mesire_kordinat`) türetilir.
- `koordinatlar` gelmezse `duraklar[].mekan.lat/lng`'e, o da yoksa `harita_link` (harici) davranışına düş.
