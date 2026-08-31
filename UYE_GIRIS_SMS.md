# Üye Girişi — Parolasız (Telefon + SMS Kodu)

Giriş iki adımdır ve **parola kullanılmaz**: kullanıcı telefonunu girer, SMS ile
gelen 6 haneli kodu yazar, oturum açılır.

> Taban URL: `https://api.gezgah.com/rest`

## Ortak Başlıklar
| Başlık | Değer |
|---|---|
| `X-App-Key` | `ba9db8d2c420adbaeed122fe53c15e878fbcc67b55ba41cd` (zorunlu) |
| `Authorization` | `Bearer <cihaz_token>` (zorunlu — giriş öncesi cihaz token'ı ile) |
| `Content-Type` | `application/json` |

> Giriş uçları da token ister; uygulama açılışta `POST /cihaz/kayit` ile aldığı
> **cihaz token'ı** ile bu istekleri yapar. Giriş başarılı olduğunda dönen
> **üye token'ı** ile devam edilir.

Yanıt zarfı: `{ "success": bool, "data": {...}, "error": ..., "meta": {...} }`

---

## Adım 1 — Kod gönder

| Metot | Yol |
|---|---|
| POST | `/uye/giris-kod-gonder` |

```json
{ "ulke_kodu": "+90", "telefon": "5366250810" }
```

| Alan | Zorunlu | Açıklama |
|---|---|---|
| `telefon` | Evet | 7-15 hane. Rakam dışı karakterler (boşluk, `+`, `-`, parantez) atılır. |
| `ulke_kodu` | Hayır | Varsayılan `+90`. `90`, `0090`, `+90` hepsi `+90`'a normalize edilir. |

### Yanıt (200)
```json
{
  "success": true,
  "data": { "gonderildi": true, "sms": true },
  "meta": { "gecerlilik_sn": 300, "ad": "Furkan" }
}
```

- `sms`: SMS sağlayıcısına iletim sonucu. `false` olsa da kod üretilmiştir
  (tekrar denemeye gerek yok, 60 sn beklenmelidir).
- `meta.ad`: Kodu bekleyen ekranda "Merhaba Furkan" gibi gösterim için üyenin adı.
- Kod **300 saniye** geçerlidir.

### Hatalar
| Kod | Durum | Gövde işareti | Anlamı |
|---|---|---|---|
| 422 | Geçersiz telefon / ülke kodu | — | Biçim hatası |
| 404 | Kayıtlı hesap yok | `kayit_gerekli: true` | Kullanıcı kayıt akışına yönlendirilmeli |
| 403 | Hesap pasif | — | `status = 0` |
| 429 | 60 sn dolmadı ya da saatlik sınır | — | Numara başına 60 sn bekleme, saatte en fazla 5 kod |
| 503 | Doğrulama servisi yok | — | Redis erişilemiyor |

---

## Adım 2 — Kod ile giriş

| Metot | Yol |
|---|---|
| POST | `/uye/giris` |

```json
{ "ulke_kodu": "+90", "telefon": "5366250810", "kod": "123456" }
```

Cihazı üyeye bağlamak için gövdeye cihaz token'ı da eklenebilir
(`cihaz_token` / `device_token`; bkz. CIHAZ_TOKEN.md).

### Yanıt (200)
```json
{
  "success": true,
  "data": {
    "token": "9f2c…",
    "uye": {
      "id": 3, "isim": "Ömer", "soyisim": "Çelik",
      "email": "omer@gmail.com", "telefon": "5380589358", "ulke_kodu": "+90",
      "sehir": 34, "ilce_id": null, "avatar": null,
      "plus": { "aktif": true, "bitis": "2027-08-17 18:26:19" },
      "status": 1, "son_giris_at": "2026-08-31 18:02:11"
    }
  },
  "meta": { "yontem": "sms" }
}
```

`data.token` = **üye token'ı**. Sonraki tüm üye isteklerinde
`Authorization: Bearer <token>` olarak kullanılır. Cihazda saklanmalıdır.

Token ömrü **180 gün kayan penceredir**: her kullanımda tazelenir, 180 gün hiç
kullanılmazsa düşer. Çoklu cihaz desteklenir — yeni giriş diğer cihazların
oturumunu düşürmez.

### Hatalar
| Kod | Gövde işareti | Anlamı |
|---|---|---|
| 422 | `need_code: true` | `kod` gönderilmedi ya da kodun süresi doldu → yeni kod iste |
| 422 | `code_wrong: true` | Kod hatalı (5 hakka kadar) |
| 429 | `need_code: true` | 5 hatalı deneme doldu, kod iptal edildi → yeni kod iste |
| 401 | — | Hesap bulunamadı/pasif (kod doğruydu ama hesap yok) |
| 429 | — | IP başına deneme sınırı (bkz. GUVENLIK.md) |

Kod **tek kullanımlıktır**; başarılı girişten sonra silinir.

---

## Kayıt akışı (değişiklik)

Kayıt da SMS doğrulamalıdır ve **parola artık opsiyoneldir**:

1. `POST /uye/kayit-kod-gonder` `{ telefon }` → SMS kodu
   (numara **zaten kayıtlıysa** 409 döner → giriş akışına yönlendir)
2. `POST /uye/kayit` `{ isim, soyisim, email, telefon, kod, parola? }`

`parola` gönderilmezse `NULL` saklanır; hesap SMS ile sorunsuz çalışır. Parola
göndermek isteyen istemci için kural aynı (en az 6 karakter).

> Kayıt ve giriş kodları **ayrı Redis anahtarlarında** tutulur
> (`uyeotp:*` / `uyegiris:*`); biri diğerinin kodunu tüketemez.

---

## Parolalı giriş (geriye dönük uyum)

`POST /uye/giris` gövdesinde `kod` **yok** ama `parola` **varsa** eski akış
çalışmaya devam eder ve yanıt `meta.yontem = "parola"` döner. Bu, yayında olan
eski uygulama sürümleri kırılmasın diye bırakılmış **geçici** bir yoldur.

Kapatmak için tek satır:
`api/rest/src/Controllers/UyeController.php` → `PAROLA_ILE_GIRIS = false`.
Kapatıldığında `parola` ile gelen istek `422 need_code` alır.

`POST /uye/sifre-degistir` duruyor ama giriş için gerekli değildir. Parolası
olmayan hesapta ilk parola belirlenirken `eski_parola` istenmez (kimlik zaten
SMS ile doğrulanmış token üzerinden kanıtlı); parolası olan hesapta istenir.

---

## İstemci akışı (özet)

```
Uygulama açılışı
  └─ POST /cihaz/kayit                → cihaz_token (sakla)

Giriş ekranı
  ├─ telefon gir
  ├─ POST /uye/giris-kod-gonder       → 404 kayit_gerekli ise Kayıt ekranı
  ├─ kod ekranı (300 sn geri sayım, "Tekrar gönder" 60 sn sonra aktif)
  └─ POST /uye/giris {telefon, kod}   → uye_token (sakla), cihaz üyeye bağlanır
```

Kod ekranında `code_wrong` gelirse alan temizlenip kalan hak gösterilebilir
(5 deneme). `need_code` gelirse "Kodun süresi doldu, yeni kod gönder" durumuna
düşülmelidir.

---

## Güvenlik notları

- Numara tespitine (enumeration) karşı: `giris-kod-gonder` kayıtlı olmayan
  numarada bilinçli olarak `404 kayit_gerekli` döner — çünkü kullanıcıyı kayıt
  ekranına yönlendirmek gerekiyor. Bu bilinçli bir üründe-kabul edilmiş takastır.
  Numara taramasını sınırlayan katmanlar: numara başına 60 sn bekleme + saatte
  5 kod, IP başına dakikada `rate_limit_auth` (varsayılan 30) istek.
- Kod 6 hane, `random_int` ile üretilir; karşılaştırma `hash_equals` ile yapılır.
- Kod Redis'te 300 sn TTL ile tutulur, 5 hatalı denemede iptal edilir, başarılı
  girişte hemen silinir.
- SMS gönderimi başarısız olsa dahi kod üretilir (kullanıcıya yeniden gönderme
  hakkı 60 sn sonra); bu durumda `sms: false` bilgisi döner.
- Redis yoksa giriş **çalışmaz** (503). OTP'nin güvenli tek kullanımlık olması
  buna bağlıdır; DB'ye düşürülerek fail-open yapılmamıştır.

Sürüm: Ağustos 2026
