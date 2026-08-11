# Kedy — Mobil App Asistanı (source=app)

Mobil uygulama **son kullanıcıları** için Kedy asistanı. Kullanıcı; mekanlar
hakkında bilgi alır, **arama** yapar, bir mekanın **QR menüsünü / yemek
içeriklerini / en çok beğenilen ürünlerini** öğrenir, **filtreler** hakkında
bilgi alır ve **rezervasyon** yapar.

Mimari, erp/pro/qr Kedy entegrasyonlarıyla aynıdır: mobil API bir **proxy**
uçtur, isteği `kedy.gezgah.com`'a `source=app` ile iletir; OpenAI anahtarı
sunucuda kalır. Sohbet geçmişi `app_kedy_chats` tablosunda tutulur.

---

## Güvenlik / Kapsam (KRİTİK)

`source=app`, Kedy tarafında **fail-closed** bir kapsamla (`Tools::guardApp`)
sınırlanır. Uygulama asistanı **yalnızca** şunları yapabilir:

- İşletme **arama** ve **herkese açık** işletme bilgisi
- **QR menü** içeriği + **ürün detayı** (içindekiler, kalori, alerjen)
- **Popüler** ve **en çok beğenilen** ürünler
- **Kategori** ve **filtre** bilgisi
- **Rezervasyon** (Plus işletmede, SMS OTP + KVKK ile)

**ASLA yapamaz:** işletme/menü yönetimi, sipariş yönetimi, başka kullanıcıların
verisi, kişisel/idari veri. Yönetim araçları (pro/admin) kapsam dışıdır; izinsiz
araç çağrısı reddedilir. İşletmeye bağlı araçlarda `postId` **yayında bir mekan**
olmalıdır (aksi halde reddedilir).

### İzin verilen araçlar (whitelist)
`read_knowledge`, `app_search`, `qr_menu`, `menu_item_detail`,
`menu_business_info`, `menu_popular`, `menu_top_liked`, `list_categories`,
`list_filters`, `reservation_options`, `qr_reservation_send_code`,
`qr_create_reservation`.

### Hassas veri koruması (önemli)
Admin/pro'ya özel araçlar (`search_businesses`, `business_detail`, müşteri/üye/
kullanıcı listeleri, raporlar, yönetim) **app kapsamında YOKTUR** ve `denyIfPro`
ile ayrıca fail-closed reddedilir. App'e özel araçlar yalnızca **herkese açık**
alanları döndürür:
- `app_search` → **yalnız yayındaki** mekanlar; `postId, ad, tip, şehir/ilçe`. **Durum,
  doğrulama, Plus, harici QR, sahip/iletişim gibi iç alanları DÖNDÜRMEZ.**
- `menu_business_info` → QR sayfasında zaten herkese açık olan bilgiler (ad, adres,
  kurumsal telefon/e-posta, sosyal medya, çalışma saatleri, özellikler).
- Menü/ürün araçları → yalnız `status=1` (yayında) ürünler.

---

## Uçlar (mobil API — `https://api.gezgah.com/rest/`)

Tüm isteklerde `Authorization: Bearer <token>` (cihaz veya üye token'ı).

### POST /kedy
```json
{ "message": "Kadıköy'de deniz manzaralı restoran öner", "postId": 1073, "lang": "tr" }
```
- `message` (zorunlu): kullanıcının serbest sorusu/komutu.
- `postId` (opsiyonel): "bu işletme" bağlamı (kullanıcının açtığı mekan).
- `lang` (opsiyonel): yanıt dili (tr/en/de/ru/ar).
- `history` (opsiyonel): yalnızca **anonim** (üye değil) kullanıcıda; üye ise sunucu geçmişi kullanılır.

Yanıt (Kedy gövdesi API zarfında):
```json
{ "success": true, "data": { "ok": true, "answer": "…", "usedTools": ["search_businesses"] }, "error": null }
```

### GET /kedy/gecmis?days=7
Giriş yapmış **üyenin** son N günlük sohbet geçmişi. Anonim kullanıcıda boş döner.
```json
{ "success": true, "data": { "history": [ { "role": "user", "content": "…" }, { "role": "assistant", "content": "…" } ] } }
```

---

## Sohbet Geçmişi (`app_kedy_chats`)

- Kaynak = `app`, sahip kolonu = `app_id` (ChatStore). Tablo ilk kullanımda **otomatik** oluşur.
- Kayıt **günlük satır** bazlıdır (her gün ayrı satır, `history` = JSON mesaj dizisi) — erp/pro/qr ile aynı desen.
- **Üye (app_uyeler)** girişliyse `app_id = üye id` → geçmiş sunucuda saklanır.
- **Anonim** (yalnız cihaz token'ı) kullanıcıda geçmiş sunucuda tutulmaz; istemci `history` gönderebilir.

---

## Örnek Kullanımlar

| Kullanıcı sorusu | Kedy'nin kullandığı araç |
|------------------|--------------------------|
| "Beşiktaş'ta kahveci ara" | `app_search` |
| "Bu mekanın menüsü ne?" (`postId`) | `qr_menu` |
| "Latte'nin içinde ne var, kaç kalori?" | `menu_item_detail` |
| "En çok beğenilen ürünler neler?" | `menu_top_liked` |
| "Popüler / ne önerirsin?" | `menu_popular` |
| "Adresi, telefonu, çalışma saatleri?" | `menu_business_info` |
| "Hangi filtreler var / otoparklı mekan?" | `list_filters` |
| "Yarın 20:00'ye 4 kişi rezervasyon" | `reservation_options` → `qr_reservation_send_code` → `qr_create_reservation` |

Rezervasyon akışı qr ile aynı kurallara tabidir: **Plus** zorunlu, kapalı
gün/saat engeli, bölge/masa doğrulama, **SMS OTP** ve **KVKK onayı**.

---

## Hız Sınırı
Kullanıcı/cihaz başına **dakikada 20** Kedy isteği (OpenAI maliyeti). Aşımda `429`.

## Kimlik / Auth (özet)
- Kedy anahtarı mobil API sunucusunda kalır (`config.kedy.key`, varsayılan gömülü).
- kedy.gezgah.com `Authorization: Bearer <KEDY_API_KEY>` bekler; `KEDY_API_KEYS` ile eşleşmeli.

---

## Deploy

### 1) Kedy backend — `/home/kedy/public_html/`
- `lib/Tools.php` — `app` kapsamı (APP_TOOLS whitelist, `guardApp`, `menu_item_detail`)
- `index.php` — `source=app` dalı (admin'e düşmesi engellendi)

### 2) Mobil API — `/home/gezgah/public_html/api/rest/`
- `index.php` — `/kedy` ve `/kedy/gecmis` rotaları
- `src/Controllers/KedyController.php` *(yeni)* — proxy
- `config/config.php` — `kedy` bağlantı bloğu *(opsiyonel; controller varsayılanla da çalışır)*

Migration gerekmez: `app_kedy_chats` ilk sohbette `CREATE TABLE IF NOT EXISTS`
ile oluşur.

> Not: Kedy `app` kapsamı `menu_item_detail` aracını qr menü ziyaretçisine de
> (QR_TOOLS) açar; bu ürün içeriği herkese açıktır, güvenlik etkisi yoktur.
