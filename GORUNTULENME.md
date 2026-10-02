# Mekan Görüntülenme Sayacı — Backend Entegrasyonu

Uygulama, mekanların **listede görünme** ve **detay açılma** sayısını toplu olarak tek bir uca gönderiyor. Bu doküman ucu, gövde biçimini ve sunucuda nasıl saklanması gerektiğini anlatıyor.

Base URL: `https://api.gezgah.com/rest`. Kod: `api/rest/` (yeni `IstatistikController`).

## 1. Uç

```
POST /istatistik/goruntulenme
Authorization: Bearer <cihaz token>      (diğer uçlarla aynı)
X-App-Key, X-Timestamp, X-Nonce, X-Signature   (HMAC, GUVENLIK.md §4)
Content-Type: application/json
```

Üye girişi gerekmez, cihaz token'ı yeterli. Üye token'ı **gönderilmez**.

### Gövde

```json
{
  "oturum": "9f2c4e1ab07d3e55c1d2a6b8e4f09c13",
  "olaylar": [
    { "mekan_id": 123, "tip": "liste", "kaynak": "kategori", "kaynak_id": "45", "sira": 0, "zaman": "2026-10-03T11:22:05.123Z" },
    { "mekan_id": 88,  "tip": "liste", "kaynak": "kategori", "kaynak_id": "45", "one_cikan": true, "zaman": "2026-10-03T11:22:05.410Z" },
    { "mekan_id": 77,  "tip": "liste", "kaynak": "tip", "kaynak_id": "plaj", "sira": 4, "zaman": "2026-10-03T11:23:10.002Z" },
    { "mekan_id": 123, "tip": "detay", "zaman": "2026-10-03T11:22:09.871Z" }
  ]
}
```

| Alan | Tür | Açıklama |
|---|---|---|
| `oturum` | string (32 hex) | Uygulama her açılışta yeni üretir. Kişisel veri değil |
| `olaylar` | dizi | 1–100 olay |
| `mekan_id` | int > 0 | `yzd_posts.id` |
| `tip` | `liste` \| `detay` | Olay türü |
| `kaynak` | string | Yalnız `liste`'de. Şu an `kategori` ya da `tip`. İleride `arama`, `ana_sayfa`, `harita`, `favori` gelebilir |
| `kaynak_id` | string, opsiyonel | `kaynak=kategori` → kategori id'si, `kaynak=tip` → `otopark`/`muze`/`mesire`/`plaj` |
| `sira` | int, opsiyonel | Listedeki 0 tabanlı konum (sabitlenmiş kartta yok) |
| `one_cikan` | bool, opsiyonel | Kategorinin sabitlenmiş (pin) kartı. Yoksa `false` |
| `zaman` | ISO-8601 UTC | Olayın cihazdaki zamanı |

Örnek id'ler temsilidir.

### Yanıt

```json
{ "success": true, "data": { "kabul": 3, "atlanan": 1 } }
```

### Uygulamanın durum koduna tepkisi (sözleşme)

| Kod | Uygulama ne yapar |
|---|---|
| 2xx | Olaylar gönderildi sayılır |
| **404** | Uç yok sayılır, o oturumda bir daha gönderilmez |
| 429 | Olaylar kuyruğa geri konur, 15 sn sonra tekrar denenir |
| Diğer 4xx | Paket atılır, tekrar gönderilmez |
| 5xx / ağ hatası | Olaylar kuyruğa geri konur, tekrar denenir |

Bu yüzden **geçerli bir istekte asla 404 dönmeyin.** Bilinmeyen ya da yayında olmayan `mekan_id` → o olayı atlayın (`atlanan`), isteği 200 ile kapatın. Gövdenin tamamı bozuksa 400 dönün.

## 2. Uygulama ne zaman sayıyor?

- **liste:** Mekan kartı ekranda en az **%50** görünür halde kesintisiz **1 sn** kalırsa. Hızla kaydırılıp geçilen ya da üstüne başka sayfa açılan kart sayılmaz (IAB görüntülenme ölçütü).
- Aynı liste ekranı ziyaretinde bir mekan **bir kez** sayılır. Aşağı-yukarı kaydırmak tekrar saydırmaz. Ekran kapatılıp yeniden açılırsa yeniden sayılır.
- **detay:** Mekan detay sayfası her açıldığında bir olay.
- Şu an gönderen ekranlar: kategori listesi (`kaynak=kategori`) ve tip listesi (otopark/müze/mesire/plaj, `kaynak=tip`). Diğer listeler (arama, ana sayfa, harita) aynı uçla sonra eklenecek, `kaynak` değeri farklı olacak.
- Gönderim toplu yapılır: 20 olay birikince, en geç 15 sn'de bir ve uygulama arka plana geçerken. İstek başına en fazla 100 olay.
- Uygulama kapatılırsa gönderilmemiş son olaylar kaybolabilir (cihazda kalıcı kuyruk yok). Sayaçlar bu yüzden "en az" değeridir.

## 3. Sunucuda işleme

### Doğrulama

- `olaylar` dizi değilse ya da 100'den fazlaysa → 400.
- Her olay: `mekan_id` pozitif int, `tip` ∈ {`liste`, `detay`}, `kaynak` `^[a-z_]{1,20}$`, `kaynak_id` ≤ 32 karakter, `sira` 0–10000. Geçersiz olay atlanır, istek reddedilmez.
- `mekan_id`'ler tek sorguyla (`WHERE id IN (...) AND post_status = 'publish'`) kontrol edilir. Bulunmayanlar atlanır.
- **Sayımda sunucu zamanı kullanın.** `zaman` yalnız bilgi amaçlı. 24 saatten eski ya da ileri tarihliyse olay atlanabilir.

### Tekilleştirme (sayaç şişmesin diye)

Aynı cihaz + mekan + tip + kaynak için **30 dk** içinde tek sayım. Redis'te:

```
SET gv:{tip}:{kaynak}:{cihaz_id}:{mekan_id} 1 NX EX 1800   → OK değilse atla
```

Günlük tekil cihaz sayısı için ayrıca:

```
SET gvd:{gun}:{tip}:{cihaz_id}:{mekan_id} 1 NX EX 93600    → OK ise tekil +1
```

### Saklama: günlük özet tablo

Ham olay saklamak gerekmiyor. Raporlama için günlük özet yeterli:

```sql
CREATE TABLE yzd_mekan_goruntulenme (
  post_id   INT UNSIGNED NOT NULL,
  gun       DATE NOT NULL,               -- Europe/Istanbul
  tip       ENUM('liste','detay') NOT NULL,
  kaynak    VARCHAR(20) NOT NULL DEFAULT '',  -- detay için ''
  adet      INT UNSIGNED NOT NULL DEFAULT 0,  -- 30 dk tekilleştirilmiş görüntülenme
  tekil     INT UNSIGNED NOT NULL DEFAULT 0,  -- o gün tekil cihaz
  one_cikan INT UNSIGNED NOT NULL DEFAULT 0,  -- adet'in pin kartından gelen kısmı
  PRIMARY KEY (post_id, gun, tip, kaynak),
  KEY idx_gun (gun)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

İstek başına tek toplu yazma (aynı anahtardaki olaylar PHP'de önceden toplanır):

```sql
INSERT INTO yzd_mekan_goruntulenme (post_id, gun, tip, kaynak, adet, tekil, one_cikan)
VALUES (?, ?, ?, ?, ?, ?, ?), (...)
ON DUPLICATE KEY UPDATE
  adet = adet + VALUES(adet),
  tekil = tekil + VALUES(tekil),
  one_cikan = one_cikan + VALUES(one_cikan);
```

### Taslak (api/rest)

`cihaz_id`'yi, diğer cihaz token'lı uçların (`/bildirimler/okundu` gibi) kullandığı auth katmanından alın.

```php
public function goruntulenme(): void
{
    $body = Request::json();                       // mevcut yardımcı neyse
    $olaylar = $body['olaylar'] ?? null;
    if (!is_array($olaylar) || count($olaylar) === 0 || count($olaylar) > 100) {
        Response::error('gecersiz_govde', 400);
    }
    $cihazId = $this->auth->cihazId();             // mevcut cihaz auth'u

    // 1) Geçerli olayları süz
    $ok = [];
    foreach ($olaylar as $o) {
        $id  = (int) ($o['mekan_id'] ?? 0);
        $tip = (string) ($o['tip'] ?? '');
        $kay = $tip === 'liste' ? (string) ($o['kaynak'] ?? '') : '';
        if ($id <= 0 || !in_array($tip, ['liste', 'detay'], true)) { continue; }
        if ($tip === 'liste' && !preg_match('/^[a-z_]{1,20}$/', $kay)) { continue; }
        $ok[] = [$id, $tip, $kay, !empty($o['one_cikan'])];
    }

    // 2) Yayındaki mekanlar (tek sorgu)
    $ids = array_values(array_unique(array_column($ok, 0)));
    $var = $ids ? array_flip(Database::column(
        "SELECT id FROM {$this->config['prefix']}posts WHERE id IN (" .
        implode(',', array_fill(0, count($ids), '?')) . ") AND post_status = 'publish'",
        $ids
    )) : [];

    // 3) Tekilleştir + topla
    $gun = (new DateTime('now', new DateTimeZone('Europe/Istanbul')))->format('Y-m-d');
    $agg = [];
    $kabul = 0;
    foreach ($ok as [$id, $tip, $kay, $pin]) {
        if (!isset($var[$id])) { continue; }
        if (!Redis::setNx("gv:$tip:$kay:$cihazId:$id", 1800)) { continue; }
        $k = "$id|$tip|$kay";
        $agg[$k] ??= [$id, $gun, $tip, $kay, 0, 0, 0];
        $agg[$k][4]++;
        if (Redis::setNx("gvd:$gun:$tip:$cihazId:$id", 93600)) { $agg[$k][5]++; }
        if ($pin) { $agg[$k][6]++; }
        $kabul++;
    }

    // 4) Tek INSERT ... ON DUPLICATE KEY UPDATE (yukarıdaki SQL)
    if ($agg) { $this->yazGoruntulenme(array_values($agg)); }

    Response::json(['kabul' => $kabul, 'atlanan' => count($olaylar) - $kabul]);
}
```

`Request::json`, `Database::column`, `Redis::setNx`, `$this->auth->cihazId()` yer tutucudur. Projedeki karşılıklarıyla değiştirin.

### Hız sınırı

Cihaz başına dakikada 30 istek yeterli. Aşımda `429` + `Retry-After` dönün. Uygulama bunu destekliyor.

## 4. Raporlama örnekleri

```sql
-- Son 30 gün, mekan bazında liste görünme / detay ve tıklama oranı
SELECT post_id,
       SUM(IF(tip='liste', adet, 0)) AS listede,
       SUM(IF(tip='detay', adet, 0)) AS detay,
       ROUND(100 * SUM(IF(tip='detay', adet, 0)) / NULLIF(SUM(IF(tip='liste', adet, 0)), 0), 1) AS ctr_yuzde
FROM yzd_mekan_goruntulenme
WHERE gun >= CURDATE() - INTERVAL 30 DAY
GROUP BY post_id
ORDER BY listede DESC;
```

Not: `detay` her kaynaktan gelir (arama, harita, favori, ana sayfa). Bu yüzden oran yalnız kategori listesinin tıklama oranı değildir.

## 5. Gizlilik

- Gövdede kişisel veri yok. Yalnız mekan id'si, liste bilgisi ve rastgele oturum kimliği var.
- Cihaz kimliği yalnız Redis tekilleştirme anahtarında, 26 saat süreyle tutulur. Özet tabloda cihaz bilgisi yok.
- Aydınlatma metninde "uygulama kullanım istatistikleri" maddesi yoksa hukuk ekibiyle kontrol edin.

## 6. Kabul kriterleri

- Geçerli gövde → 200 ve `kabul + atlanan = olaylar.length`.
- Bilinmeyen `mekan_id` → 200, `atlanan` artar, **404 değil**.
- 101 olay ya da `olaylar` yok → 400.
- Aynı cihaz aynı mekanı 30 dk içinde iki kez gönderirse `adet` bir artar.
- Gün içinde aynı cihaz 3 kez (30 dk arayla) detay açarsa `adet=3`, `tekil=1`.
- İstek başına tek INSERT. Uç ES/Redis detay önbelleğine dokunmaz.
- Sözleşme: uç yolu, alan adları ve `tip` değerleri uygulamada sabit. Değişecekse uygulama ekibine bildirin.
