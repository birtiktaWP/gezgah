# İşletme "Hakkımızda" Metni — `description`

İşletmeler pro panelden (**Ayarlar → İşletmem**) kendilerini tanıtan bir
**Hakkımızda** metni girebiliyor. Bu metin mobil API'de mevcut **`description`**
alanında döner — **yeni bir alan veya endpoint eklenmedi**, mobil tarafta ek bir
istek gerekmez.

> Taban URL: `https://api.gezgah.com/rest` · Doğrulama: 26 Ağustos 2026

## Ortak Başlıklar
| Başlık | Değer |
|---|---|
| `X-App-Key` | `ba9db8d2c420adbaeed122fe53c15e878fbcc67b55ba41cd` (zorunlu) |
| `Authorization` | `Bearer <cihaz_veya_uye_token>` (zorunlu) |

---

## Alan

| Alan | Tip | Açıklama |
|---|---|---|
| `description` | string | İşletmenin "Hakkımızda" metni. Girilmemişse **boş string** (`""`) döner. En fazla **1500 karakter**. |

**Kaynak:** `yzd_posts.description` (işletme kaydının kendisi; meta değil).

## Nerede döner?

`description`, `PostRepository::formatBase()` içinde olduğu için **tüm mekan
temsillerinde** bulunur — yeni bir şey eklenmedi, alan zaten vardı; artık
işletmeler tarafından doldurulabiliyor.

| Metot | Yol | Not |
|---|---|---|
| GET | `/mekanlar/{id}` | **Birincil kullanım** — detay sayfasında "Hakkımızda" bölümü |
| GET | `/mekanlar` | Liste özetinde de bulunur |
| GET | `/yerler` | Liste özetinde |
| GET | `/kategoriler/{id}` · `/kategoriler/{id}/mekanlar` | Kategori mekan listelerinde |
| GET | `/arama?tab=mekan` | Arama sonuçlarında |
| GET | `/uye/favoriler` | Favori listesinde |

---

## Örnek

### `GET /mekanlar/2`
```json
{
  "success": true,
  "data": {
    "id": 2,
    "type": "restoran",
    "slug": "gezgah-kafe",
    "name": "Gezgah Kafe",
    "description": "2018'den beri Şişli'de üçüncü nesil kahve ve ev yapımı tatlılar sunuyoruz. Kendi kavurduğumuz çekirdeklerle hazırlanan filtre kahvelerimiz ve günlük taze pastalarımızla sizi bekliyoruz.",
    "dogrulanmis": true,
    "adres": "…",
    "calisma_saatleri": { },
    "...": "diğer detay alanları"
  }
}
```

### Metin girilmemişse
```json
{ "id": 1064, "name": "Favolin", "description": "" }
```

---

## Mobil UI Notu

- Mekan detayında **"Hakkımızda"** başlığı altında gösterilebilir.
- `description` boş (`""`) ise **bölümü hiç gösterme** (başlık da dahil).
- Metin çok satırlı olabilir; satır sonlarını koru. HTML **içermez**
  (sunucuda `strip_tags` uygulanır), düz metin olarak render edilebilir.
- Uzun metinlerde "Devamını oku" ile kırpma önerilir (ör. 3 satır sonrası).

---

## İşletme Tarafı (pro panel)

| | |
|---|---|
| Yol | **Ayarlar → İşletmem** (`/isletme_bilgileri.php`) |
| Alan | "Hakkımızda" — çok satırlı, canlı karakter sayacı (`… /1500`) |
| Kaydeden aksiyon | `update_isletme` (`includes/router.php`) |
| Yetki | Yalnız işletme sahibi (**partner**). Personel (**garson**) bu sayfaya erişemez, `/hesap.php`'ye yönlendirilir. |

### Pro panel yapısal değişiklik (bilgi)

Bu özellikle birlikte hesap ekranı ikiye ayrıldı, **sekme sistemi kaldırıldı**:

- **Ayarlar → Hesabım** (`/hesap.php`) → yalnız **bireysel** bilgiler: isim, telefon, e-posta
- **Ayarlar → İşletmem** (`/isletme_bilgileri.php`) → **kurumsal** bilgiler: işletme adı, ünvan,
  **Hakkımızda**, kurumsal telefon/e-posta, il/ilçe, açık adres, çalışma saatleri (7/24 dahil)

Router aksiyonları da ayrıldı (`update_hesap` / `update_isletme`); böylece bir formu
kaydetmek diğerinin alanlarını **silmiyor**.

---

## Teknik Notlar

- Sunucuda `strip_tags` + 1500 karakter kırpma uygulanır.
- `description` alanı Elasticsearch mekan/menü index'lerinde de bulunur; metin
  güncellendikten sonra arama tarafına yansıması için mekan reindex'i gerekebilir
  (`es_reindex.php`). Detay ucu DB'den taze okuduğu için **detayda anında** görünür.
- Mevcut durum: 160 yayında restoranın **0**'ında metin var (alan yeni açıldı);
  işletmeler doldurdukça dolacak. Bu yüzden mobil tarafta **boş kontrolü şart**.
