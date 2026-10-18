# Mekan Videoları — Backend / Mobil API Entegrasyonu

ERP > Mekan Düzenle > Galeri > **Videolar** canlıda. Videolar ERP'den yükleniyor. Bu doküman, videoların mobil API'de (`api.gezgah.com/rest`) nasıl sunulacağını anlatıyor.

## 1. Veri nerede?

| Ne | Yer |
|---|---|
| Video + kapak dosyaları | `/home/gezgah/public_html/pro/uploads/videos/` → `https://pro.gezgah.com/uploads/videos/<dosya>` |
| Liste (sıralı) | `yzd_postmetas` · `meta_key = 'mekan_videolar'` · `meta_value` = JSON dizi |
| Yazan | `erp-api.gezgah.com/controllers/VideoController.php` |

Videolar `files` tablosuna **yazılmıyor**. Bu yüzden mevcut `galeri` alanı (`repo->gallery()`) değişmiyor; mobil uygulama videoyu görsel sanmıyor.

### Meta şeması (`mekan_videolar`)

```json
[
  {
    "f": "gezgah_v_fb5e91a4ce30f26e.mp4",
    "p": "gezgah_v_fb5e91a4ce30f26e.jpg",
    "t": "Teras gün batımı",
    "mime": "video/mp4",
    "size": 5242912,
    "dur": 12.3,
    "w": 1080,
    "h": 1920,
    "at": "2026-10-03 01:38:25"
  }
]
```

| Alan | Açıklama |
|---|---|
| `f` | Video dosya adı. Her zaman `^gezgah_v_[a-f0-9]{16}\.(mp4\|mov\|webm)$` |
| `p` | Kapak (poster) dosya adı (`.jpg/.png/.webp`) ya da `null` |
| `t` | Başlık (≤120 karakter, HTML'siz). Boş olabilir |
| `mime` | `video/mp4`, `video/quicktime` ya da `video/webm` |
| `size` | Bayt |
| `dur`, `w`, `h` | Süre (sn), genişlik, yükseklik. Tarayıcıdan okunur, **yalnız gösterim amaçlı**. `dur` null, `w/h` 0 olabilir |
| `at` | Yüklenme zamanı (Europe/Istanbul) |

Dizi sırası = ERP'deki gösterim sırası. Sınırlar: mekan başına en fazla 6 video, video başına 80 MB.

## 2. Önerilen API çıktısı

`GET /mekanlar/{id}` yanıtına `videolar` alanı eklenmeli. Biçim, ERP'nin `VideoController::payload()` çıktısıyla birebir aynı:

```json
"videolar": [
  {
    "file": "gezgah_v_fb5e91a4ce30f26e.mp4",
    "url": "https://pro.gezgah.com/uploads/videos/gezgah_v_fb5e91a4ce30f26e.mp4",
    "poster": "https://pro.gezgah.com/uploads/videos/gezgah_v_fb5e91a4ce30f26e.jpg",
    "title": "Teras gün batımı",
    "mime": "video/mp4",
    "size": 5242912,
    "duration": 12.3,
    "width": 1080,
    "height": 1920,
    "createdAt": "2026-10-03 01:38:25"
  }
]
```

- Video yoksa `[]` döner, `null` dönmez.
- `url` ve `poster` mutlak URL'dir. `poster` null olabilir; o zaman uygulama ilk kareyi ya da bir yer tutucu göstermeli.

## 3. Uygulama (api/rest)

`src/Controllers/MekanController.php → show()`. Bu alanı **telefon gibi TAZE okuyun**, yani ES/Redis detay önbelleğine koymayın. Böylece ERP'deki ekleme, silme ve sıralama anında görünür, ayrıca önbellek temizlemeye gerek kalmaz.

```php
// show() içinde, Response::json'dan hemen önce (etkinlikler satırının yanına):
$data['videolar'] = $this->mekanVideolar($id);
```

```php
/** ERP'den yüklenen mekan videoları (mekan_videolar meta'sı) — taze okunur. */
private function mekanVideolar(int $postId): array
{
    $raw = Database::scalar(
        "SELECT meta_value FROM {$this->config['prefix']}postmetas WHERE post_id = ? AND meta_key = 'mekan_videolar' LIMIT 1",
        [$postId]
    );
    $arr = json_decode((string) ($raw ?: ''), true);
    if (!is_array($arr)) { return []; }

    $base = 'https://pro.gezgah.com/uploads/videos/';
    $safe = '/^gezgah_v_[a-f0-9]{16}\.(mp4|mov|webm|jpg|png|webp)$/';
    $out  = [];
    foreach ($arr as $v) {
        if (!is_array($v) || !preg_match($safe, (string) ($v['f'] ?? ''))) { continue; }
        $p = (string) ($v['p'] ?? '');
        $out[] = [
            'file'      => $v['f'],
            'url'       => $base . rawurlencode($v['f']),
            'poster'    => ($p !== '' && preg_match($safe, $p)) ? $base . rawurlencode($p) : null,
            'title'     => (string) ($v['t'] ?? ''),
            'mime'      => (string) ($v['mime'] ?? ''),
            'size'      => (int) ($v['size'] ?? 0),
            'duration'  => isset($v['dur']) ? (float) $v['dur'] : null,
            'width'     => (int) ($v['w'] ?? 0),
            'height'    => (int) ($v['h'] ?? 0),
            'createdAt' => (string) ($v['at'] ?? ''),
        ];
    }
    return $out;
}
```

İsteğe bağlı: liste uçlarında (`/mekanlar`, arama, harita) yalnız `video_var: bool` işareti eklenebilir. Tam listeyi yalnız detayda verin.

## 4. Mobil uygulama notları

- **Oynatma:** MP4 (H.264/AAC) iOS ve Android'de sorunsuz oynar. `video/quicktime` (MOV, HEVC olabilir) bazı Android cihazlarda oynamayabilir, WebM de iOS'ta sorun çıkarabilir. `mime` alanına bakarak uyumsuz olanlar gizlenebilir. ERP'de "MP4 önerilen" uyarısı var.
- **Dikey/yatay:** `width < height` ise dikey (9:16) oynatıcı kullanın. `w/h` 0 ise 16:9 varsayın.
- **Kapak:** Listede `poster` gösterin, videoyu yalnız dokunulunca yükleyin. Dosyalar 80 MB'a kadar çıkabilir, otomatik oynatma veri harcar.
- **Önbellek:** Dosyalar `Cache-Control: public, max-age=2592000` ile sunulur. Ad rastgele ve değişmez olduğu için URL kalıcı olarak cache'lenebilir.
- **Akış (streaming):** Apache Range isteklerini destekler, yani ileri sarma çalışır. HLS/transcode yok, sunucuda ffmpeg yok.

## 5. ERP uçları (referans)

Hepsi ERP oturumu (cookie) ister. Yetkiler: okuma `mekan/read`, yazma `mekan/edit`, silme `mekan/delete`.

| Uç | Gövde | Not |
|---|---|---|
| `GET /listing/videos?postId=` | — | `{videos, limits}` |
| `POST /listing/video-upload` | multipart: `postId`, `video`, `title?`, `poster?` (data URI), `duration?`, `width?`, `height?` | finfo + dosya imzası (ftyp/EBML) kontrolü |
| `POST /listing/video-update` | `{postId, file, title}` | başlık |
| `POST /listing/video-reorder` | `{postId, files:[...]}` | sıra |
| `POST /listing/video-delete` | `{postId, file}` | listeden ve diskten siler |

Yazma işlemleri `logs` tablosuna `mekan_video_ekle` / `mekan_video_sil` olarak düşer ve ES dokümanı tazelenir (`EsIndexer::indexPost`).

## 6. Güvenlik

- Dosya adı sunucuda rastgele üretilir. Kullanıcının verdiği ad diske hiç yazılmaz, path traversal mümkün değil.
- `uploads/videos/.htaccess` içinde PHP/CGI çalışmaz, dizin listelenmez ve `nosniff` vardır.
- `erp-api` PHP sınırları: `upload_max_filesize`/`post_max_size` 100M, `max_execution_time`/`max_input_time` 300.
- Cloudflare'in ücretsiz/pro planında istek gövdesi sınırı 100 MB. 80 MB sınırı bu yüzden seçildi.
