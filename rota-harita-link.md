# Gezgah — Gezi Rotası Harita (Google Maps) Linkleri

Rota detayında, hem **tüm rotayı** gezen bir Google Maps yol tarifi linki, hem de **her durak**
(mekan) için tekil bir harita linki döner. Koordinatlar mekanın `kordinat` / `plaj_kordinat` /
`mesire_kordinat` metasından alınır.

- Uç: `GET /uye/rotalar/{id}`
- Başlıklar: `X-App-Key: <app_key>` + `Authorization: Bearer <token>`

---

## 1. Rota geneli — `harita_link`

Rota nesnesinde, duraklardaki koordinatları **sırayla** gezen yol tarifi linki:
```
https://www.google.com/maps/dir/<lat1,lng1>/<lat2,lng2>/<lat3,lng3>
```
- **2+ koordinatlı durak** varsa → yukarıdaki yol tarifi (directions) linki.
- **Tek koordinat** varsa → tekil arama linki (`.../maps/search/?api=1&query=lat,lng`).
- Hiç koordinat yoksa → `harita_link: null`.

Koordinatı olmayan duraklar rotadan atlanır (linkte yer almaz).

## 2. Durak (mekan) başına — `duraklar[].harita_link`

Her durağın kendi mekanını haritada açan link:
```
https://www.google.com/maps/search/?api=1&query=<lat,lng>
```
Koordinatı olmayan durakta `harita_link: null`.

---

## 3. Örnek yanıt

`GET /uye/rotalar/5`:
```json
{
  "success": true,
  "data": {
    "rota": {
      "id": 5, "baslik": "Kadıköy Turu",
      "rota_fiyat": 450.0,
      "harita_link": "https://www.google.com/maps/dir/40.9901,29.0270/41.0082,28.9784",
      "sahip": { "uye_id": 12, "isim": "Ada", "soyisim": "Yılmaz", "avatar": "..." },
      "duraklar": [
        {
          "durak_id": 11, "sira": 1, "yorum": "Kahve iç",
          "mekan": { "id": 1064, "name": "Favolin", "kordinat": "40.9901,29.0270", "ilce": "Kadıköy" },
          "secili_urun": { "qr_id": 5, "ad": "Latte", "fiyat": "100", "gorsel": "..." },
          "harita_link": "https://www.google.com/maps/search/?api=1&query=40.9901,29.0270"
        },
        {
          "durak_id": 12, "sira": 2, "yorum": null,
          "mekan": { "id": 2091, "name": "Ada Restoran", "kordinat": "41.0082,28.9784" },
          "secili_urun": null,
          "harita_link": "https://www.google.com/maps/search/?api=1&query=41.0082,28.9784"
        }
      ]
    }
  }
}
```

---

## 4. Notlar

- Linkler **evrensel** Google Maps URL'leridir; mobilde Google Maps uygulaması kuruluysa
  otomatik onda, değilse tarayıcıda açılır. Ek API anahtarı gerekmez.
- Rota linki durak **sırasına** göre üretilir (durak sıralaması değişirse link güncellenir).
- Koordinatı olmayan mekan hem rota linkine hem kendi linkine dahil edilmez (`null`).
- Yeni alan; şema/tablo değişikliği yoktur. Yalnız `GET /uye/rotalar/{id}` yanıtı genişledi.

---

## 5. Mobil Kullanım

1. Rota detayında "Haritada Aç / Yol Tarifi" butonu → `rota.harita_link` (varsa) aç.
2. Her durak kartında küçük bir "konum" ikonu → `durak.harita_link` aç.
3. `harita_link: null` ise butonu gizle (o mekan/rota için koordinat yok).
