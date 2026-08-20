# Rota Yorumları — İşletme Yorumu (Mavi Tik + En Üstte)

Gezi rotasındaki bir mekanın **işletme sahibi**, pro panelden (pro.gezgah.com) o rotaya
yorum yapabilir. Bu yorum hem pro panelde hem **mobil uygulamada**:

- **Listenin en üstünde** gösterilir (kaç tane olursa olsun, üye yorumlarından önce).
- **İşletme adı + öne çıkan görseli** ile gösterilir (üye adı/avatarı yerine).
- **Mavi tik / "İŞLETME" rozeti** ile işaretlenir (Instagram verified görünümü).

Endpoint **değişmedi**; yanıt objesine `isletme` alanı eklendi. Mobil tarafta yeni bir
uç çağırmaya gerek yok — mevcut yorum listeleme yanıtındaki `isletme` alanına bakılır.

---

## Endpoint

```
GET /uye/rotalar/{id}/yorumlar?page=1&limit=20
```

- Header: `X-App-Key: <app_key>` (zorunlu), `Authorization: Bearer <token>` (opsiyonel; tepki/benim bilgisi için).
- Sıralama sunucuda garanti: **işletme yorumları en üstte**, sonra üye yorumları (en yeni → en eski).
  Mobil tarafta ekstra sıralama gerekmez; gelen sırayı koru.

---

## Yanıt

```json
{
  "data": {
    "items": [
      {
        "id": 42,
        "yorum": "Bu rotadaki durağımıza bekleriz!",
        "created_at": "2026-08-20 14:05:00",
        "isletme": true,
        "uye": {
          "uye_id": 0,
          "post_id": 1063,
          "isim": "Vanilpuff",
          "soyisim": "",
          "avatar": "https://gezgah.com/uploads/xxx.jpg"
        },
        "begeni_sayisi": 3,
        "begenmeme_sayisi": 0,
        "tepki": null,
        "begendim": false,
        "begenmedim": false,
        "benim": false,
        "silebilir_mi": false
      },
      {
        "id": 41,
        "yorum": "Harika bir rota olmuş.",
        "created_at": "2026-08-20 13:40:00",
        "isletme": false,
        "uye": {
          "uye_id": 87,
          "isim": "Ahmet",
          "soyisim": "Yılmaz",
          "avatar": "https://.../avatar.jpg"
        },
        "begeni_sayisi": 1,
        "begenmeme_sayisi": 0,
        "tepki": "begeni",
        "begendim": true,
        "begenmedim": false,
        "benim": true,
        "silebilir_mi": true
      }
    ]
  },
  "meta": {
    "page": 1,
    "limit": 20,
    "total": 2,
    "pages": 1,
    "has_more": false,
    "next_page": null,
    "yorumlar_acik": true
  }
}
```

---

## Alan Açıklamaları (yorum objesi)

| Alan | Tip | Açıklama |
|------|-----|----------|
| `id` | int | Yorum id'si. |
| `yorum` | string | Yorum metni. |
| `created_at` | string | Oluşturma zamanı. |
| **`isletme`** | bool | **`true` ise işletme yorumu** → mavi tik/rozet göster + en üstte gelir. `false` ise normal üye yorumu. |
| `uye` | object | Yazar bilgisi. **İşletme yorumunda** `uye_id=0`, `post_id`=işletmenin post id'si, `isim`=işletme adı, `avatar`=işletme öne çıkan görseli. **Üye yorumunda** normal üye alanları. |
| `uye.post_id` | int? | Yalnız işletme yorumunda dolu. Mekan detayına yönlendirmek için kullanılabilir. |
| `begeni_sayisi` / `begenmeme_sayisi` | int | Tepki sayıları. |
| `tepki` | string? | Bu kullanıcının tepkisi: `begeni` \| `begenmeme` \| `null`. |
| `begendim` / `begenmedim` | bool | Kolaylık bayrakları. |
| `benim` | bool | Yorum bu kullanıcıya mı ait (işletme yorumunda daima `false`). |
| `silebilir_mi` | bool | Kullanıcı bu yorumu silebilir mi (işletme yorumunda daima `false` — işletme kendi silmesini pro panelden yapar). |

---

## Mobil UI Notları

1. **Rozet:** `isletme === true` olan yorumlarda, yazar adının yanına **mavi tik** (verified)
   ve/veya **"İşletme"** etiketi koy. Instagram'daki doğrulanmış hesap görünümü hedeflenir.
2. **Sıra:** Sunucu işletme yorumlarını zaten en üstte döndürür. Client-side yeniden
   sıralama yapma; gelen `items` sırasını olduğu gibi göster.
3. **Avatar:** İşletme yorumunda `uye.avatar` işletmenin öne çıkan görselidir (null olabilir → placeholder).
4. **Tıklama:** İşletme yorumunda `uye.post_id` ile mekan detayına yönlendirme yapılabilir (opsiyonel).
5. **Beğeni/beğenmeme:** İşletme yorumları da normal yorumlar gibi beğenilebilir/beğenilmeyebilir
   (`POST/DELETE /uye/rotalar/{id}/yorum/begen` ve `.../yorum/begenme`).
6. **Silme/düzenleme:** İşletme yorumları mobil app'ten silinemez (`silebilir_mi=false`).
   İşletme kendi yorumunu pro panelden yönetir.

---

## Backend Özeti (referans)

- Tablo: `app_rota_yorum` → yeni kolonlar `yazar_tipi` (`uye` | `isletme`), `post_id` (işletme yorumunda dolu).
- İşletme yorumu: `uye_id = 0`, `yazar_tipi = 'isletme'`, `post_id = <mekan post_id>`.
- Sıralama: `ORDER BY (yazar_tipi='isletme') DESC, created_at DESC, id DESC`.
- İşletme yorumu ekleme/silme yalnız **pro panelden** (router aksiyonları `rota_yorum_ekle` / `rota_yorum_sil`),
  o işletme rotanın bir durağı olmalı ve rota herkese açık olmalı.
