# Kategori sayfası alt kategori sekmeleri — backend

Uygulamada kategori sayfasındaki alt kategori sekmeleri artık **aynı sayfada** çalışıyor: Türk Mutfağı açıkken "Dürümcü" sekmesine basınca yeni sayfa açılmıyor; sekmeler yerinde kalıyor, yalnız liste `GET /kategoriler/{altId}` ile değişiyor ve seçilen sekme ortalanıyor. Uygulama tarafı tamam; aşağıdaki üç madde deneyimi tamamlamak için backend'den isteniyor.

Base URL: `https://api.gezgah.com/rest` · Uç: `GET /kategoriler/{id}`.

## 1. Alt kategori doğrudan açılınca sekmeler (en önemli)

Bir alt kategori sayfası doğrudan açıldığında (harita, arama, bildirim, paylaşılan bağlantı) yanıtta **ne üst kategori ne kardeş alt kategoriler** var; bu yüzden sekme çubuğu hiç görünmüyor.

Canlı (`GET /kategoriler/4862` — Dürümcü):

```
data.kategori anahtarları: id,type,slug,name,description,thumbnail,status,date,icon,mekan_sayisi   ← parent yok
data.alt_kategoriler: []
```

İstenen: alt kategori istendiğinde `data`'ya **üst kategori** ve onun **alt kategorileri (kardeşler)** eklensin:

```json
"data": {
  "kategori": { "id": 4862, "name": "Dürümcü", "parent": 4807, ... },
  "ust_kategori": { "id": 4807, "name": "Türk Mutfağı", "icon": "<svg…>" },
  "kardes_kategoriler": [
    { "id": 4812, "name": "Çorba & İşkembe", "icon": null, "mekan_sayisi": 7 },
    { "id": 4862, "name": "Dürümcü", "icon": null, "mekan_sayisi": 19 }
  ],
  "alt_kategoriler": [],
  "mekanlar": [ ... ]
}
```

- `kategori.parent` her durumda dolu olsun (kök kategoride `0`).
- Kök kategoride `ust_kategori` = `null`, `kardes_kategoriler` = `[]` (bugünkü davranış).
- `kardes_kategoriler` sırası, kökteki `alt_kategoriler` sırasıyla aynı olsun.

Bu alanlar gelince uygulamada küçük bir ek değişiklikle sekmeler `[ust_kategori, ...kardes_kategoriler]` olarak gösterilip açılan alt kategori seçili ve ortalanmış gelir. (Alanlar gelene kadar bugünkü gibi sekmesiz açılır, bozulma yok.)

## 2. Alt kategori ikonları (içerik)

`/kategoriler/agac`'taki 53 alt kategorinin **hiçbirinde ikon yok**. Uygulama uydurma ikon yerine sekmeyi ikonsuz gösteriyor; sekmeler bu yüzden yalnız yazı. ERP'den alt kategorilere SVG ikon girilirse uygulama değişikliği gerekmeden görünür.

## 3. `alt_kategoriler[]` içinde `mekan_sayisi` (isteğe bağlı)

Kökün `alt_kategoriler[]` öğelerinde `mekan_sayisi` gelmiyor (`null`). Gelirse uygulama 0 mekanlı alt kategorileri sekmede gizleyebilir (boş liste açılmaz). Alan aynı `kategori` özet fonksiyonundan gelebilir.

## Kontrol

```
GET /kategoriler/4862   → kategori.parent = 4807, ust_kategori.id = 4807, kardes_kategoriler 9 öğe
GET /kategoriler/4807   → ust_kategori = null, kardes_kategoriler = [], alt_kategoriler[].mekan_sayisi dolu
```
