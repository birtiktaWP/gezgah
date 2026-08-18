# Gezi Rotası — İstatistik Sayaçları (Görüntülenme & Gösterim)

Her rota için iki sayaç tutulur ve listeleme/detay uçlarında döner:

| Alan | Anlamı | Ne zaman artar |
|---|---|---|
| `goruntulenme` | Detay görüntülenme (rota detayı açıldı) | `GET /uye/rotalar/{id}` çağrıldığında, **rotayı sahibi dışında** biri açarsa +1 |
| `gosterim` | Listede gösterim / impression (rota bir listede göründü) | Keşfet ve takip akışı uçlarında dönen her rota için (sahibin kendi rotası hariç) +1 |

> Sahip kendi rotasını açtığında/listelediğinde sayaçlar **artmaz** (şişirme engellenir).

Taban URL: `https://api.gezgah.com/rest`
Ortak başlıklar: `X-App-Key`, `Authorization: Bearer <token>`.

---

## Sayaçların döndüğü uçlar

Tüm rota özeti çıktılarında (`rotaOzet`) artık şu iki alan var:

```json
{
  "id": 10,
  "baslik": "Boğaz Turu",
  "begeni_sayisi": 12,
  "goruntulenme": 340,
  "gosterim": 1580,
  "durak_sayisi": 5,
  "created_at": "2026-08-18 10:00:00"
}
```

Bu alanlar şu uçlarda gelir:
- `GET /uye/rotalar` — üyenin kendi rotaları (kendi istatistiklerini görür)
- `GET /rotalar` — keşfet (herkese açık akış) → **çağrı, listelenen rotaların `gosterim` sayacını artırır**
- `GET /uye/rotalar/takip-akisi` — takip akışı → **`gosterim` artar**
- `GET /uye/rotalar/{id}` — rota detayı → **`goruntulenme` artar** (sahibi değilse)

### Detay örneği
`GET /uye/rotalar/10`
```json
{
  "success": true,
  "data": {
    "rota": {
      "id": 10,
      "baslik": "Boğaz Turu",
      "goruntulenme": 341,
      "gosterim": 1580,
      "begeni_sayisi": 12,
      "duraklar": [ ... ]
    }
  }
}
```

---

## Sayaç davranışı (özet)

- `goruntulenme`: detay açılışı başına +1. Aynı kullanıcı tekrar tekrar açarsa her açılış sayılır (tekilleştirme yok — ham görüntülenme).
- `gosterim`: liste isteği başına, o istekte dönen her rota için +1. Yani rota 20'lik bir sayfada göründüyse o istekte +1 alır (sayfa başına, satır başına 1 kez).
- Her iki artış da **fail-safe**: DB hatası olsa bile ana yanıt etkilenmez.

---

## Rakamları Nasıl Yükseltiriz? (mobil/ürün önerileri)

### Gösterim (`gosterim`) — daha çok listede görünür kıl
1. **Keşfet akışında öne çıkar**: Rotayı `gorunurluk = "herkese_acik"` yap. Gizli rotalar keşfette/takipte listelenmez, gösterim almaz.
2. **Takipçi kazan**: Takip akışı (`/uye/rotalar/takip-akisi`) takipçilerin ana beslemesi. Rota sahibinin takipçisi arttıkça her yeni rota daha çok kişinin akışında görünür → gösterim artar. (Takip: `POST /uye/takip`)
3. **Kapak görseli ekle**: Kapaklı rotalar listede daha çok tıklanır; uygulama öneri/derleme bölümlerinde öne çıkarılabilir. (`POST /uye/rotalar/{id}/kapak`)
4. **Filtre uyumu**: Rotaya `restoran/mesire/plaj` tipinde duraklar ve ilçe bilgisi ekle; kullanıcılar `?tip=` / `?ilce=` ile filtreleyince listeye girer.
5. **Sayfa/keşfet sekmelerini besle**: Uygulamada keşfet sekmesi açıldığında ve sonsuz kaydırmada (`page` arttıkça) her sayfa isteği gösterim üretir; kaydırmayı akıcı yaparak daha çok sayfa yükletmek gösterimi artırır.

### Görüntülenme (`goruntulenme`) — detay açılışını artır
1. **Çekici başlık + kapak**: Listede tıklamayı artıran ilk şey başlık ve kapak görselidir. Net başlık ve kaliteli kapak detay açılışını yükseltir.
2. **Paylaşım linki**: Rota detayının harici linkini (uygulama deep-link / web) paylaşıma aç; dışarıdan gelen her açılış görüntülenme sayar.
3. **Beğeni/yorum sosyal sinyali**: `begeni_sayisi` yüksek rotalar listede daha ilgi çeker → daha çok açılır. Beğeni çağrısını kolaylaştır (`POST /uye/rotalar/{id}/begen`).
4. **Zengin durak içeriği**: Çok duraklı, ürün/yemek seçili ve `rota_fiyat` dolu rotalar daha bilgilendirici görünür; kullanıcıyı detayı açmaya teşvik eder.
5. **Bildirimler**: Takip edilen kişi yeni rota paylaşınca takipçilere bildirim gönder (mobil push) → detay açılışı artar.

> Not: Sayaçlar ham (tekilleştirilmemiş) tutulur. İleride "tekil görüntüleyen" metriği istenirse ayrı bir `app_rota_goruntulenme (rota_id, uye_id/cihaz, gun)` tablosu eklenebilir; bu sürümde toplam sayaç yeterli kabul edildi.

---

## Teknik Notlar (backend)
- Kolonlar: `app_gezi_rotalari.goruntulenme INT DEFAULT 0`, `app_gezi_rotalari.gosterim INT DEFAULT 0`.
- Artış SQL'i atomiktir: `UPDATE ... SET goruntulenme = goruntulenme + 1 WHERE id = ?` (yarış koşulu yok).
- Gösterim toplu artışla verilir: `UPDATE ... SET gosterim = gosterim + 1 WHERE id IN (...)` (liste başına tek sorgu).
