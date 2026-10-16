# Aramada çoklu sıralama — backend

Uygulamada arama sonuçlarında (Mekanlar ve Yemekler sekmesi) sıralama artık filtreler gibi **çoklu seçilebiliyor**. Kullanıcı birden fazla kriter seçer; **seçim sırası öncelik sırasıdır** (1. kriter eşitse 2.'ye bakılır…).

Base URL: `https://api.gezgah.com/rest` · Uç: `GET /arama` (değişen yalnız sıralama parametresi).

## 1. Bugünkü durum (canlı test, Üsküdar konumu)

`sort` tek değer kabul ediyor. Virgüllü değer tanınmıyor ve **sessizce varsayılana düşüyor**:

| İstek | `meta.sort` |
|---|---|
| `tab=yemek&sort=distance` | `distance` ✓ |
| `tab=yemek&sort=distance,likes` | `likes` (varsayılan) ✗ |
| `tab=mekan&sort=distance` | `distance` ✓ |
| `tab=mekan&sort=distance,rating` | `relevance` (varsayılan) ✗ |

Bu yüzden uygulama `sort`'u bozmadı; çoklu sıralamayı **yeni bir parametreyle** gönderiyor.

## 2. Uygulamanın gönderdiği

```
GET /arama?q=kebap&tab=yemek&sort=distance&siralar=distance,likes&lat=..&lng=..
GET /arama?q=kahve&tab=mekan&sort=distance&siralar=distance,relevance&lat=..&lng=..
```

| Parametre | Değer |
|---|---|
| `sort` | Birincil kriter (bugünkü gibi). Mekan sekmesinde birincil "İlgi" ise **gönderilmez** (sunucu varsayılanı) |
| `siralar` | **Yeni.** Tüm kriterler, öncelik sırasıyla, virgüllü. **Yalnız 2+ kriter seçiliyse** gönderilir |

Geriye uyum: `siralar` bilinmiyorsa yok sayılır ve liste bugünkü gibi yalnız `sort`'a göre sıralanır. Uygulama bozulmaz.

### Kriter değerleri

| Sekme | Değer | Anlam | Not |
|---|---|---|---|
| yemek | `distance` | Mekana yakınlık (artan) | Yalnız konum gönderilmişse |
| yemek | `likes` | Ürün beğenisi (azalan) | |
| yemek | `price_asc` / `price_desc` | Fiyat artan / azalan | İkisi birlikte gelmez (uygulama engelliyor) |
| mekan | `distance` | Yakınlık (artan, tahmini yol mesafesi) | Yalnız konum gönderilmişse |
| mekan | `relevance` | Arama eşleşme skoru (azalan) | Bugünkü varsayılan |

## 3. İstenen

1. `siralar` virgüllü listesini okuyun; kriterleri **verilen sırayla** `ORDER BY`'a çevirin. Örnek `siralar=price_asc,distance,likes`:
   ```sql
   ORDER BY fiyat ASC, mesafe_m ASC, begeni DESC, id DESC   -- id: kararlı sayfalama
   ```
2. Bilinmeyen / tekrarlanan değerleri atlayın. Konum yoksa `distance`'ı atlayın. Hepsi atlanırsa `sort`'a, o da yoksa varsayılana düşün.
3. Sona her zaman kararlı bir kırıcı ekleyin (`id DESC`). Aksi halde sayfa sınırında (page 1 → page 2) kayıtlar tekrarlanabilir ya da kaybolabilir.
4. `meta.siralar` olarak **uygulanan** listeyi dönün: `"siralar": ["distance","likes"]`. `meta.sort` birincil kriter olarak kalsın.
5. Elasticsearch yolu: aynı liste `sort: [{...}, {...}]` dizisine çevrilmeli (MESAFE-MOBIL.md §3'teki ES/SQL farkına dikkat; iki yol aynı sırayı vermeli).
6. `fiyat` metin ise sayısala çevrilerek sıralanmalı (`"1.100,00"` ≠ alfabetik). Fiyatı olmayan ürünler fiyat sıralamasında sona.

## 4. Kontrol

| İstek | Beklenen |
|---|---|
| `tab=yemek&q=kebap&siralar=price_asc,likes` | Fiyat artan; aynı fiyatta beğeni azalan |
| `tab=yemek&q=kebap&siralar=distance,price_asc&lat=41.0255&lng=29.0153` | Aynı mekandaki (aynı mesafe) ürünler fiyata göre artan |
| `tab=mekan&q=kahve&siralar=distance,relevance&lat=..&lng=..` | Mesafe artan; eşit mesafede ilgi skoru |
| `siralar=bogus,likes` | `meta.siralar = ["likes"]` |
| `siralar` yok | Bugünkü davranış birebir |
| page=1 ve page=2 birleşimi | Tekrar/eksik kayıt yok |

## Sözleşme

Parametre adı `siralar` ve kriter değerleri uygulamada sabit (`lib/data/api.dart` → `siralarCsv`, `aramaMekan`/`aramaYemek`). Değişecekse uygulama ekibine bildirin.
