# Mekan Doğrulama (Onaylı) Bilgisi — `dogrulanmis`

Mekanlarda ERP panelindeki **doğrulama (onaylı)** durumu artık mobil API'de `dogrulanmis`
(bool) alanıyla döner. Kaynak: ERP'de yönetilen `mekan_dogrulanmis` meta'sı (`1` = onaylı).

> Yalnız restoranlarda doğrulama yapılır. **plaj / mesire / otopark / müze**'de bu meta
> bulunmaz → `dogrulanmis` her zaman **`false`** döner.

Taban URL: `https://api.gezgah.com/rest`

## Ortak Başlıklar
| Başlık | Değer |
|---|---|
| `X-App-Key` | `ba9db8d2c420adbaeed122fe53c15e878fbcc67b55ba41cd` (zorunlu) |
| `Authorization` | `Bearer <cihaz_veya_uye_token>` (zorunlu) |

---

## Alan

| Alan | Tip | Açıklama |
|---|---|---|
| `dogrulanmis` | bool | `true` = ERP'de onaylanmış (mavi tik / "Onaylı" rozeti gösterilebilir). `false` = onaysız veya doğrulama yapılmayan tip (plaj/mesire/otopark/müze). |

## Eklendiği uçlar

### Detay
| Metot | Yol | Not |
|---|---|---|
| GET | `/mekanlar/{id}` | Detay yanıtına `dogrulanmis` eklendi (taze okunur; her tip için doğru). |

### Liste (her mekan kaydında)
| Metot | Yol |
|---|---|
| GET | `/mekanlar` |
| GET | `/yerler` (plaj/mesire/otopark/müze → daima false) |
| GET | `/mekanlar/yeni-eklenenler`, `/mekanlar/yakindakiler`, `/pagination_isletmeler`, `/harita` |
| GET | `/kategoriler/{id}` (mekanlar + sabit mekan) |
| GET | `/kategoriler/{id}/mekanlar` |
| GET | `/uye/favoriler` |

> Not: Yukarıdaki liste uçları ortak "mekan özeti" temsilini kullandığından `dogrulanmis`
> hepsinde tutarlı biçimde bulunur.

---

## Örnek

### Detay — `GET /mekanlar/927`
```json
{
  "success": true,
  "data": {
    "id": 927,
    "name": "Hona Snackary",
    "type": "restoran",
    "dogrulanmis": true,
    "...": "diğer detay alanları"
  }
}
```

### Liste öğesi — `GET /mekanlar` / `/kategoriler/{id}`
```json
{
  "id": 1592,
  "name": "Çarşı Et ve Balık",
  "type": "restoran",
  "filtre_ids": [109, 112],
  "ozellik_ids": [1082],
  "dogrulanmis": false
}
```

### Plaj (her zaman false) — `GET /yerler?type=plaj`
```json
{
  "id": 1469,
  "name": "Tırmata Beach",
  "type": "plaj",
  "dogrulanmis": false
}
```

---

## Mobil UI Notu
- `dogrulanmis === true` olan mekanlarda ad yanına **mavi tik / "Onaylı"** rozeti gösterilebilir
  (ERP'deki "Doğrulanmış" rozetiyle aynı anlam).
- plaj/mesire/otopark/müze kartlarında rozet gösterme (daima false).

## Teknik Not (backend)
- Kaynak meta: `yzd_postmetas.mekan_dogrulanmis` = `'1'` (onaylı) / yok veya `'0'` (değil).
- Detayda değer **taze** okunur (ES'te saklı eski detay önbelleğinden etkilenmez).
- Liste özetlerinde mekan meta'sından hesaplanır; ek sorgu maliyeti yok.
