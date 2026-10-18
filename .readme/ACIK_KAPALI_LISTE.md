# Liste kartlarında açık / kapalı — backend

Kategori ve tip listelerindeki (restoran, mesire, otopark, plaj) mekan kartlarında, görselin üstündeki "Açık" rozeti kaldırıldı. Eskiden kartta "Restoran / Plaj…" yazan satırda artık **gerçek açık/kapalı durumu** gösteriliyor:

- `● Açık · 02:00'a kadar` (yeşil)
- `● Kapalı` (kırmızı)

Durum, mekan detayındaki "Şu an açık / kapalı" şeridiyle **aynı hesapla**, çalışma saatlerinden uygulamada hesaplanıyor.

## 1. Sorun

Eski "Açık" rozeti **sahteydi**: liste yanıtlarında çalışma saati yok, uygulama her kartı varsayılan olarak "Açık" gösteriyordu. Liste uçları saat göndermediği için yeni satır bugün **hiçbir kartta görünmüyor**. Uydurma "Açık" yazmak yerine satırı gizliyoruz.

Canlı kontrol (`calisma_saatleri` alanı var mı):

| Uç | Bugün |
|---|---|
| `GET /kategoriler/{id}` → `mekanlar[]` | yok |
| `GET /yerler?type=mesire\|otopark\|plaj` | yok |
| `GET /mekanlar` | yok |
| `GET /mekanlar/{id}` (detay) | **var** |

## 2. İstenen

Liste uçlarındaki her mekan kaydına, detaydakiyle **aynı biçimde** `calisma_saatleri` ekleyin:

```json
{
  "id": 5137,
  "name": "Zeytinburnu Sahil Cep Otoparkı",
  "calisma_saatleri": {
    "pazartesi": "12:00 - 22:00",
    "sali": "12:00 - 22:00",
    "carsamba": "12:00 - 22:00",
    "persembe": "12:00 - 22:00",
    "cuma": "12:00 - 22:00",
    "cumartesi": "12:00 - 22:00",
    "pazar": "12:00 - 22:00"
  }
}
```

Uçlar: `/kategoriler/{id}` (`mekanlar[]` ve `sabit_restoran`), `/kategoriler/{id}/mekanlar`, `/yerler`, `/mekanlar`, `/mekanlar/yakindakiler`, `/arama` (mekan sonuçları). Hepsi aynı özet fonksiyonundan (`MekanController::summary()`) geçiyorsa tek yerde eklenebilir.

### Biçim kuralları (uygulama böyle okuyor)

| Durum | Değer |
|---|---|
| Anahtarlar | `pazartesi, sali, carsamba, persembe, cuma, cumartesi, pazar` (küçük harf, Türkçe karaktersiz) |
| Açık gün | `"HH:MM - HH:MM"` (tire etrafındaki boşluk/–/— fark etmez) |
| Gece yarısını aşan | `"18:00 - 02:00"` desteklenir (ertesi gün 02:00'a kadar açık sayılır) |
| 24 saat açık | `"00:00 - 00:00"` |
| Kapalı gün | `"Kapalı"` ya da `null` |
| Saat girilmemiş mekan | Alanı göndermeyin ya da `{}` / tüm günler `null` |

**Önemli — veri temizliği:** Tüm günleri `"Kapalı"` olan kayıtlar (ör. #4623 Reşadiye Mesire Alanı) uygulamada "saat bilinmiyor" sayılıyor ve satır gizleniyor; çünkü bu kayıtlar büyük olasılıkla "girilmemiş" demek. Gerçekten kalıcı kapalı bir mekan varsa ayrı bir alanla (`kalici_kapali: true`) bildirilmeli. Plajların çoğunda tüm günler `null`; plaj/mesire için saat girilirse satır görünür.

### Performans

Liste başına 20 kayıt × 7 kısa metin; yanıt boyutuna etkisi küçük. Saatler mekan meta'sından okunuyorsa listede tek sorguda (`IN (...)`) toplu çekin, kayıt başına ayrı sorgu atmayın.

## 3. Uygulama tarafı (bilgi)

- Okuyan kod: `parseCalismaSaatleri`, `acikDurumu` (`lib/data/models.dart`), `ApiPlace.calismaSaatleri` (`lib/data/api.dart`), gösterim `OpenStatusLine` (`lib/widgets/common.dart`) ve `ListTileCard` (`lib/widgets/place_cards.dart`).
- Saat cihazın yerel saatine göre değerlendirilir (Türkiye).
- Alan eklendiğinde **yeni uygulama sürümü gerekmez**.

## 4. Kontrol

```
GET /kategoriler/4787?limit=3     → mekanlar[0].calisma_saatleri dolu
GET /yerler?type=otopark&limit=3  → data[0].calisma_saatleri dolu
```

Aynı mekan için liste ve detaydaki `calisma_saatleri` birebir aynı olmalı (aksi halde kart "Açık", detay "Kapalı" diyebilir).
