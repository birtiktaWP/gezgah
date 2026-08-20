# Gezi Rotası — Sosyal Medya (Instagram) Paylaşım Görseli

Bir gezi rotası için **hazır paylaşım görsel(ler)i** üretir. Her görselin üstünde **Gezgah logosu**,
altında rotanın **durakları** listelenir. Duraklar tek görsele sığmazsa **birden fazla görsel** döner
(çok sayfalı; her sayfada logo + sayfa numarası).

Taban URL: `https://api.gezgah.com/rest`

## Ortak Başlıklar
| Başlık | Değer |
|---|---|
| `X-App-Key` | `ba9db8d2c420adbaeed122fe53c15e878fbcc67b55ba41cd` (zorunlu) |
| `Authorization` | `Bearer <uye_token>` |

> Cihaz veya üye token'ı yeterli. Gizli (herkese açık olmayan) bir rotanın görseli yalnız **sahibi** tarafından üretilebilir (aksi halde 403).

Yanıt zarfı: `{ "success": bool, "data": ..., "error": ..., "meta": ... }`

---

## Görsel Üret

`GET /uye/rotalar/{id}/paylasim?format=story|post`

| Param | Zorunlu | Açıklama |
|---|---|---|
| `format` | – | `story` = 1080×1920 (Instagram Story, varsayılan) · `post` = 1080×1350 (dikey gönderi). |

Sayfa başına durak: **story ≈ 7**, **post ≈ 4**. Durak sayısına göre görsel sayısı otomatik hesaplanır.

Yanıt:
```json
{
  "success": true,
  "data": {
    "format": "story",
    "sayfa": 2,
    "boyut": { "w": 1080, "h": 1920 },
    "gorseller": [
      "https://gezgah.com/uploads/app-rota-paylasim/rota123-story-76284fe361-p1.jpg",
      "https://gezgah.com/uploads/app-rota-paylasim/rota123-story-76284fe361-p2.jpg"
    ]
  }
}
```

- `gorseller`: sıralı görsel URL'leri (sayfa 1, 2, …). Instagram'a **çoklu görsel/story** olarak sırayla paylaşılır.
- `sayfa`: toplam görsel sayısı.
- `boyut`: piksel ölçüsü.

---

## Görselin İçeriği
- **Üst (her sayfada):** Gezgah logosu (marka bandı).
- **Başlık bloğu:** rota başlığı + alt bilgi `N durak · ₺fiyat · Paylaşan Adı`. Çok sayfada sağ üstte `1 / 2` rozeti.
- **Duraklar:** her durak bir kart — sıra numarası, mekan/konum adı, durak yorumu; varsa mekan fotoğrafı (thumbnail) ve seçili ürün çipi (`Ürün · fiyat ₺`).
- **Alt:** "Gezgah ile keşfet · gezgah.com".

Konum durakları (serbest konum) da listelenir; fotoğrafı varsa kullanılır, yoksa numara dairesi gösterilir.

---

## Mobil Akış (öneri)
1. Rota detayında "Paylaş" → `GET /uye/rotalar/{id}/paylasim?format=story`.
2. Dönen `gorseller[]` URL'lerini indir.
3. Tek görselse doğrudan Instagram Story/gönderi paylaşımına gönder; birden fazlaysa **çoklu** olarak sırayla ekle (story'de art arda, gönderide carousel).
4. Feed gönderisi için `format=post` kullanılabilir.

> Not: URL'ler kalıcıdır; aynı içerik için tekrar istenirse aynı görseller (cache) döner. Rota değişince (durak ekle/çıkar, yorum, ürün vb.) yeni görseller üretilir ve eskileri temizlenir.

---

## Özet
| Metot | Yol | Açıklama |
|---|---|---|
| GET | `/uye/rotalar/{id}/paylasim?format=story\|post` | Rota için Instagram paylaşım görsel(ler)i üretir |

## Teknik Notlar
- Görseller sunucuda **GD** ile üretilir; `uploads/app-rota-paylasim/` altında JPEG (kalite 90).
- Logo: `assets/gezgah-logo-white.png` (SVG'den üretildi). Font: DejaVu Sans (Türkçe destekli).
- İçerik imzasına göre isimlendirilir → aynı içerik yeniden üretilmez (Redis + dosya cache, 1 gün).
- Mekan thumbnail'ı best-effort indirilir; başarısızsa numara dairesine düşer (fail-safe).
