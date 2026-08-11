# Rezervasyon API (Mobil App)

Bir **işletme için rezervasyon** oluşturma uçları. Base:
`https://api.gezgah.com/rest/`. Tüm isteklerde `Authorization: Bearer <token>`
gerekir (cihaz veya üye token'ı). Telefon **SMS OTP** ile doğrulanır, **KVKK**
onayı zorunludur. Durum Redis'te tutulur (durumsuz/stateless API).

Kaynak: `pro_reservations` (+ `pro_reservation_comments`, `mekan_musterileri`).
Kurallar `qr/reservation.php` ile birebir uyumludur.

---

## Akış

1. `GET /rezervasyon/secenekler?mekan_id=` → işletme rezervasyona açık mı, bölge/masa/çalışma saatleri.
2. `POST /rezervasyon/kod-gonder` → telefona 6 haneli SMS kodu (5 dk geçerli).
3. `POST /rezervasyon` → kodu + bilgileri gönder, rezervasyon oluşsun.

---

## 1) Rezervasyon Seçenekleri

```
GET /rezervasyon/secenekler?mekan_id=1073
```

Yanıt (Redis'te 5 dk önbellekli):
```json
{
  "success": true,
  "data": {
    "mekan_id": 1073,
    "rezervasyon_aktif": true,
    "bolge_zorunlu": true,
    "bolgeler": [ { "id": 4, "isim": "Bahçe" }, { "id": 5, "isim": "İç Salon" } ],
    "masalar": { "4": ["B1","B2"], "5": ["S1","S2"] },
    "calisma_saatleri": { "pazartesi": "09:00 - 23:00", "sali": "Kapalı", "...": null }
  }
}
```

- `rezervasyon_aktif=false` ise işletme **Gezgah Plus** değildir; rezervasyon alınmaz.
- `bolge_zorunlu=true` ise oluştururken `bolge_id` **zorunludur**.
- `masalar`, bölge id'sine göre gruplanmış masa/oda adlarıdır.

---

## 2) SMS Onay Kodu Gönder

```
POST /rezervasyon/kod-gonder
Content-Type: application/json
Authorization: Bearer <token>

{ "mekan_id": 1073, "telefon": "5xxxxxxxxx" }
```

Yanıt:
```json
{ "success": true, "data": { "gonderildi": true, "sms": true }, "meta": { "gecerlilik_sn": 300 } }
```

- `telefon` 10 hane (başındaki `0`/`90` otomatik ayıklanır).
- **Hız sınırı:** telefon başına **60 sn** bekleme + **saatte en fazla 5** kod. Aşımda `429`.
- Kod Redis'te 5 dk saklanır (`gzapi:kv:rezotp:{mekan_id}:{telefon}`).

---

## 3) Rezervasyon Oluştur

```
POST /rezervasyon
Content-Type: application/json
Authorization: Bearer <token>

{
  "mekan_id": 1073,
  "ad_soyad": "Ahmet Yılmaz",
  "telefon": "5xxxxxxxxx",
  "kisi": 4,
  "tarih": "2026-08-15T20:30",
  "bolge_id": 4,
  "masa": "B2",
  "not": "Pencere kenarı olsun",
  "kod": "123456",
  "kvkk": true
}
```

Başarılı yanıt:
```json
{ "success": true, "data": { "durum": "olusturuldu", "hash": "9f2c…", "mekan_id": 1073, "tarih": "2026-08-15 20:30:00" } }
```

### Alanlar
| Alan | Zorunlu | Açıklama |
|------|---------|----------|
| `mekan_id` | ✓ | İşletme post id |
| `ad_soyad` | ✓ | Müşteri adı (≤150) |
| `telefon` | ✓ | 10 hane; kod bu numaraya gönderilmiş olmalı |
| `kisi` | — | Kişi sayısı (vars. 1) |
| `tarih` | ✓ | `YYYY-MM-DDTHH:MM` veya `YYYY-MM-DD HH:MM` |
| `kod` | ✓ | SMS ile gelen 6 haneli kod |
| `kvkk` | ✓ | `true` olmalı (KVKK onayı) |
| `bolge_id` | koşullu | İşletmenin bölgesi varsa zorunlu |
| `masa` | — | Seçilen bölgeye ait masa/oda adı |
| `not` | — | Serbest not (≤500) |

### Doğrulamalar / Hatalar (HTTP + `error.details`)
| Durum | Kod | details |
|-------|-----|---------|
| Plus değil | 403 | — |
| KVKK onayı yok | 422 | `need_consent` |
| Kod istenmemiş / süresi dolmuş | 422 | `need_code` |
| Kod yanlış | 422 | `code_wrong` |
| Çok fazla hatalı kod (≥5) | 429 | `need_code` |
| Geçmiş / geçersiz tarih | 422 | — |
| Seçilen gün/saat kapalı | 422 | `closed` |
| Bölge seçilmemiş (gerekliyken) | 422 | `need_bolge` |

- Kod en fazla **5 kez** denenebilir; sonra yeniden istenmelidir.
- Başarıda OTP anahtarı Redis'ten silinir.
- Geçersiz `bolge_id`/`masa` sessizce yok sayılır (0/boş kabul edilir).

---

## Redis Kullanımı (özet)
- **OTP kodu:** `gzapi:kv:rezotp:{mekan_id}:{telefon}` (TTL 300 sn, deneme sayacı ile).
- **Hız sınırı:** `gzapi:rl:rezotp:{telefon}` (5/saat) + `gzapi:once:rezcd:{telefon}` (60 sn).
- **Seçenekler önbelleği:** `gzapi:resp:rez:opt:{mekan_id}` (TTL 300 sn).
- Redis yoksa OTP akışı çalışmaz → `503` ("Doğrulama servisi geçici olarak kullanılamıyor").

## Notlar
- Rezervasyon `status=0` (bekliyor) olarak oluşur; işletme pro panelinden onaylar/iptal eder.
- Müşteri `mekan_musterileri`'ne `referans='app'` ile (tekrar yoksa) eklenir.
- Kimlik: cihaz token'ı yeterlidir; telefon doğrulaması SMS OTP ile sağlanır.

## Deploy (yeni/değişen dosyalar) — `/home/gezgah/public_html/api/rest/`
- `src/Rezervasyon.php` *(yeni)*
- `src/Controllers/RezervasyonController.php` *(yeni)*
- `src/Cache.php` (store/fetch/forget/flushResp eklendi)
- `src/Guard.php` (rez uçları hız sınırına eklendi)
- `index.php` (rotalar eklendi)

Migration gerekmez: tablolar ilk rezervasyonda `CREATE TABLE IF NOT EXISTS` ile oluşur.
