# Gezgah Fontları — UberMove ("gezgah-pro")

Bu klasör, Gezgah pro panelinde (pro.gezgah.com) kullanılan **UberMove** font ailesini içerir.
Projede font ailesi `gezgah-pro` adıyla tanımlıdır ve **iki ağırlık** kullanılır: Medium (500) ve Bold (700).

## Dosyalar

| Dosya | Ağırlık | Format |
|-------|---------|--------|
| `UberMove-Medium.*` | 500 (normal metin) | eot, woff2, woff, ttf, svg |
| `UberMove-Bold.*` | 700 (vurgu/başlık) | eot, woff2, woff, ttf, svg |

> Modern tarayıcılar için **woff2** yeterlidir (en küçük boyut). woff geriye dönük destek,
> ttf/eot/svg ise çok eski tarayıcılar içindir. Yeni projede sadece woff2 + woff kullanman önerilir.

## @font-face tanımı (proddaki ile birebir)

```css
@font-face {
    font-family: 'gezgah-pro';
    src: url('fonts/Medium/UberMove-Medium.woff2') format('woff2'),
         url('fonts/Medium/UberMove-Medium.woff')  format('woff'),
         url('fonts/Medium/UberMove-Medium.ttf')   format('truetype');
    font-weight: 400 500;   /* 400 istekleri de bu yüze düşer, sentetik incelme olmaz */
    font-style: normal;
    font-display: swap;
}
@font-face {
    font-family: 'gezgah-pro';
    src: url('fonts/Bold/UberMove-Bold.woff2') format('woff2'),
         url('fonts/Bold/UberMove-Bold.woff')  format('woff'),
         url('fonts/Bold/UberMove-Bold.ttf')   format('truetype');
    font-weight: 600 800;   /* 600 ve 700 istekleri Bold yüzüne düşer */
    font-style: normal;
    font-display: swap;
}

body { font-family: 'gezgah-pro', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
```

> Prodda `src` yolu mutlak (`/assets/fonts/...`). Yeni projede kendi klasör yapına göre
> göreli/mutlak yolu ayarla.

## Prodda hangi ağırlık nerede kullanılıyor?

Kural basit: **başlıklar ve para/rozet gibi vurgular Bold, geri kalan her şey Medium.**

### Medium (500) — gövde / normal metin
Varsayılan ağırlık. `body` dahil çoğu yer bunu kullanır.

| Element / kullanım | font-weight | Örnek |
|--------------------|-------------|-------|
| Gövde metni | 400 / normal / 500 | `body`, `p` |
| Paragraf açıklama | 400 | `.detail p`, `.cat_area li a .text p`, `.qr_item_detay .text p` |
| Liste ikincil metin | normal | `.detay ul li span` (fiyat hariç), `.order_details li span` |
| Butonlar | 500 | ana aksiyon butonları, `.input .form-control` |
| Form elemanları | normal / 500 | `input`, `select`, `textarea` |
| Sekme / segment metni | 500 | `.item_head_edit`, filtre sekmeleri |

### Bold (700) — başlıklar ve vurgular
`font-weight: bold` (700) **veya 600** verilen her şey Bold yüzüne düşer.

| Element / kullanım | font-weight | Örnek |
|--------------------|-------------|-------|
| Sayfa/bölüm başlıkları | bold | `h1`, `h2.title`, `.big_title`, `.yakinda h2`, `.hello h2`, `.cat_detail h2` |
| Kart başlıkları | bold | `.product .title h2`, `.notice h2`, `.tarihce h2`, `.ois_head h2` |
| Fiyat / tutar | bold | `.detay ul li span`, `.ois_total b`, `.sepet_content li` |
| Rozet / etiket (badge) | 600 / 700 | plus rozeti, durum etiketleri, `.eklenti_badge` |
| Sayaçlar / öne çıkanlar | bold | `.one_cikanlar2 li span`, `.lider_item span` |
| Vurgulu satır başı | 600 | `.iletisim_detaylari ul li span`, `.reports .report span` |

### Özet zihin haritası

```
h1, h2, h3 (başlıklar)      → Bold (700)
fiyat, tutar, rozet, sayaç  → Bold (700) / 600
p, li açıklama, buton, input→ Medium (500 / normal)
body varsayılan             → Medium (500)
```

## Notlar
- UberMove'da yalnızca **Medium** ve **Bold** yüzleri var. Ara ağırlık (300, 900) yoktur;
  400–500 → Medium, 600–800 → Bold yüzüne eşlenir. Bu yüzden `font-weight: 300` veya `900`
  kullanma — tarayıcı sentetik (yapay) kalınlık/incelik uydurur, görünüm bozulur.
- Başlıklarda hafif **negatif letter-spacing** (ör. `-0.01em`) UberMove ile şık durur.
- Lisans: UberMove Uber'in kurumsal fontudur; kullanım hakkını kendi projen için doğrula.
