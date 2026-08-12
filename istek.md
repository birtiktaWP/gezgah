# İstek — Arama v3.1: Mesafe/Fiyat Sıralama + Yemek Filtreleme

Mobil arama sonuç sayfasına eklenecek özellikler için `/arama` ucunun
genişletilmesi talebi. Amaç: sıralama/filtrelemenin **sunucu tarafında** ve
**sayfalama ile tutarlı** yapılması (istemcide yalnız görüntülenen sayfayı
sıralamak yanlış sonuç verir; tüm sonuç kümesi üzerinde sıralanmalı).

- **Uç:** `GET /rest/arama` (mevcut; genişletilecek)
- **Taban URL:** `https://api.gezgah.com/rest`
- **Kimlik:** mevcut (cihaz/üye token + X-App-Key)
- **Geriye dönük uyum:** Yeni parametreler **opsiyonel**. Gönderilmezse mevcut
  davranış korunur (mekan = alaka; yemek = beğeni azalan).

---

## 1) Yeni ortak parametreler

| Param   | Tip   | Sekme        | Açıklama |
|---------|-------|--------------|----------|
| `lat`   | float | mekan, yemek | Kullanıcı enlemi (mesafe sıralaması + `mesafe_m` için). |
| `lng`   | float | mekan, yemek | Kullanıcı boylamı. |
| `sort`  | string| mekan, yemek | Sıralama biçimi (aşağıda). |
| `filtreler` | string | (öncelik: yemek) | Virgülle ayrık filtre id listesi (ör. `12,45`). Mekanın aktif filtrelerine göre süzer. |

> `lat`/`lng` verilmezse mesafe sıralaması yapılamaz → varsayılan sıralamaya
> düşülür (mekan=alaka, yemek=beğeni). App konum iznine göre koordinatı
> gönderir; yoksa göndermez.

---

## 2) `sort` değerleri

### tab=mekan
| sort | Açıklama |
|------|----------|
| `distance` | **Koordinat verildiyse VARSAYILAN.** Kullanıcıya en yakın mekan önce. |
| `relevance` | ES alaka (koordinat yoksa varsayılan). |

### tab=yemek
| sort | Açıklama |
|------|----------|
| `distance` | **Koordinat verildiyse VARSAYILAN.** Ürünün ait olduğu mekanın mesafesine göre. |
| `price_asc` | Fiyata göre **artan** (ucuzdan pahalıya). |
| `price_desc` | Fiyata göre **azalan**. |
| `likes` | Beğeni azalan (koordinat yoksa varsayılan; mevcut davranış). |

> **Fiyat sıralaması notu:** `fiyat` alanı metin ("550", "1.250,00", boş vb.).
> Sunucu sayısal olarak sıralamalı (CAST/temizlenmiş sayısal kolon). Boş/null
> fiyatlar her iki yönde de **sona** atılmalı.

---

## 3) Yanıta eklenecek alan: `mesafe_m`

Koordinat gönderildiğinde her sonuç öğesine mesafe eklensin (metre, tam sayı):

```json
// tab=mekan öğesi
{ "id": 1038, "name": "...", "kordinat": "41.02,28.98", "mesafe_m": 1240, ... }

// tab=yemek öğesi
{ "urun_id": 1423, "urun": "...", "mekan": { "id": 1311, "kordinat": "...", "mesafe_m": 3520, ... } }
```

- App zaten koordinattan mesafeyi hesaplayabiliyor; ancak **sıralama sunucuda**
  yapıldığı için `mesafe_m`'in sunucudan gelmesi tutarlılık sağlar (aynı formül).
- Koordinat yoksa `mesafe_m` alanı gönderilmeyebilir (null/eksik).

---

## 4) Yemek filtreleme (`filtreler`)

- Kaynak: mevcut `GET /filtreler` listesi (Otopark, Wi-Fi, Vale, Dijital Menü…).
- `filtreler=12,45` → yalnızca, ait olduğu **mekanı bu filtrelerin hepsine sahip**
  olan ürünler döner (AND mantığı; app böyle bekliyor).
- Filtre + fiyat/mesafe sıralaması **birlikte** çalışabilmeli.
- Not: Mekan sekmesinde de aynı `filtreler` desteği eklenirse app ileride oraya
  da filtre koyabilir; öncelik **yemek** sekmesi.

---

## 5) meta

Uygulanan sıralama/filtre `meta`'da yankılansın (app durum göstergesi için):

```json
"meta": {
  "q": "köfte", "tab": "yemek",
  "sort": "price_asc",
  "filtreler": [12, 45],
  "has_coord": true,
  "page": 1, "limit": 20, "total": 12, "pages": 3
}
```

---

## 6) Performans / Redis (kritik)

Bu özelliklerin performans sorunu yaratmaması için:

1. **Redis cache anahtarı** artık `sort`, `filtreler` ve **konumu** de içermeli:
   `mek:arama:<tab>:<sort>:<filtreler>:<latq>:<lngq>:<md5(q)>:<page>:<limit>`.
   - Konumu **yuvarlayarak** anahtara koyun (ör. 2 ondalık ≈ ~1.1 km kovası) ki
     her metrede farklı anahtar oluşup cache isabet oranı düşmesin.
   - Konum yoksa (`distance` değil) anahtar konumdan bağımsız olsun.
2. **Mesafe sıralaması:**
   - `tab=mekan` (ES): `geo_distance` sort kullanın (mekan index'inde koordinat
     alanı `geo_point` olmalı). ES yoksa DB fallback'te hesaplanmış mesafeyle
     sıralayın.
   - `tab=yemek` (DB): ürün→mekan join'inde mekan koordinatından mesafe hesaplanıp
     sıralanır; sayfa başına sınırlı olduğundan pahalı değildir, ancak
     `yzd_qr.post_id` ve mekan koordinat kolonlarında **index** olsun.
3. **Fiyat sıralaması:** `yzd_qr` üzerinde sayısal fiyat için **kalıcı sayısal
   kolon** (ör. `fiyat_num DECIMAL`) + index önerilir; her sorguda CAST maliyetli
   olur. Kolon yoksa en azından `CAST` + uygun index.
4. **Filtre:** filtre-mekan ilişki tablosunda index; `filtreler` AND sorgusu
   join/EXISTS ile.
5. **Sayfalama tutarlılığı:** Sıralama alanında eşitlikte ikincil olarak `id`
   ile deterministik sırala (sayfalar arası kayma olmasın).

---

## 7) Örnek istekler

```
# Mekanlar — konuma göre en yakın
GET /rest/arama?q=kahve&tab=mekan&lat=41.02&lng=28.98&sort=distance&page=1&limit=20

# Yemekler — fiyat artan + otopark filtresi
GET /rest/arama?q=köfte&tab=yemek&sort=price_asc&filtreler=12&page=1&limit=20

# Yemekler — konuma göre en yakın (varsayılan, koordinat verilince)
GET /rest/arama?q=köfte&tab=yemek&lat=41.02&lng=28.98&page=1&limit=20
```

---

## 8) App tarafı (bu istek tamamlanınca yapılacaklar)

- **Mekanlar:** koordinat varsa `sort=distance` (varsayılan) gönderilecek;
  `mesafe_m` ile "1.2 km" gösterilecek.
- **Yemekler:** varsayılan `sort=distance` (koordinat varsa); üstte
  **Sıralama** butonu (Yakınlık / Fiyat artan / Fiyat azalan / Beğeni) ve
  **Filtrele** butonu (bottom sheet, `/filtreler`) eklenecek. Seçimler `sort` +
  `filtreler` olarak isteğe eklenecek; sekme/filtre/sıralama değişince `page=1`.

> Onay: Yukarıdaki parametre adları (`sort`, `filtreler`, `lat`, `lng`) ve
> `mesafe_m` alan adı netleşince app tarafını buna göre bağlarım. Farklı isim
> tercih ederseniz belirtin, ona göre uyarlarım.
