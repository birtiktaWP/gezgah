# Gezgah API — Flutter Entegrasyon Rehberi

Bu doküman, Gezgah mobil uygulamasını geliştiren Flutter asistanı içindir.
API'ye nasıl bağlanılacağını, kimlik doğrulamayı, veri saklamayı, istekleri ve
en performanslı kullanımı anlatır.

---

## 0. Temel bilgiler

- **Base URL:** `https://api.gezgah.com/rest`
- Endpoint yolları base URL'in **sonuna** eklenir:
  `https://api.gezgah.com/rest/mekanlar`
- **Format:** JSON (istek ve yanıt). `Content-Type: application/json`.
- **Kodlama:** UTF-8 (Türkçe karakterler doğru gelir).
- **Auth:** Token tabanlı. `Authorization: Bearer <token>` header'ı.
- Mobil app kullanıcıları `yzd_users` tablosundadır.

### Standart yanıt zarfı

Her yanıt aynı zarf yapısındadır:

```json
{
  "success": true,
  "data": { },
  "meta": { "page": 1, "limit": 20, "total": 311, "pages": 16 },
  "error": null
}
```

Hata durumunda:

```json
{
  "success": false,
  "data": null,
  "error": { "message": "Açıklama", "details": { } }
}
```

- `success`: HTTP 2xx ise `true`.
- `data`: asıl içerik (obje veya liste).
- `meta`: sadece listeleme/sayfalama yanıtlarında bulunur.
- `error.details`: doğrulama hatalarında alan bazlı mesajlar (opsiyonel).

### HTTP durum kodları

| Kod | Anlamı |
|-----|--------|
| 200 | Başarılı |
| 201 | Oluşturuldu (register, favori ekle) |
| 401 | Kimlik doğrulama gerekli / token geçersiz |
| 403 | Hesap aktif değil |
| 404 | Kaynak bulunamadı |
| 409 | Çakışma (e-posta zaten kayıtlı) |
| 422 | Doğrulama hatası |
| 405 | Yöntem desteklenmiyor |

---

## 1. Önerilen paketler

```yaml
dependencies:
  dio: ^5.4.0                     # HTTP istemcisi (interceptor, retry, cancel)
  flutter_secure_storage: ^9.0.0  # token güvenli saklama
  cached_network_image: ^3.3.0    # görsel cache
  connectivity_plus: ^6.0.0       # offline kontrol (opsiyonel)
```

> **Neden Dio?** Interceptor ile token'ı otomatik ekleme, istek iptali
> (`CancelToken`), zaman aşımı, yeniden deneme ve merkezi hata yönetimi sağlar.
> Bu performans ve bakım için `http` paketinden daha avantajlıdır.

---

## 2. API istemcisi (tek noktadan yapılandırma)

```dart
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Api {
  Api._();
  static final Api instance = Api._();

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';

  late final Dio dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.gezgah.com/rest',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      contentType: 'application/json',
      // Sunucu hata kodlarında exception fırlatma; biz envelope'a bakacağız.
      validateStatus: (status) => status != null && status < 500,
      headers: {'Accept': 'application/json'},
    ),
  )..interceptors.add(_AuthInterceptor());

  Future<String?> get token => _storage.read(key: _tokenKey);
  Future<void> saveToken(String t) => _storage.write(key: _tokenKey, value: t);
  Future<void> clearToken() => _storage.delete(key: _tokenKey);
}

/// Her isteğe token ekler.
class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await Api.instance.token;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
```

> **Performans:** `Dio` örneği **tek (singleton)** olmalı. Her istekte yeni
> istemci oluşturmak bağlantı havuzunu (keep-alive) bozar ve yavaşlatır.

---

## 3. Veri saklama stratejisi

| Veri | Nerede | Neden |
|------|--------|-------|
| **Token** | `flutter_secure_storage` | Hassas; şifreli depo (Keychain/Keystore) |
| Kullanıcı profili (id, ad, e-posta) | `flutter_secure_storage` veya state | Token ile birlikte |
| Mekan/kategori listeleri (cache) | Bellek + opsiyonel disk (Hive/sqflite) | Tekrar tekrar çekmemek için |
| Görseller | `cached_network_image` (otomatik) | Disk cache, tekrar indirmeyi önler |
| Geçici UI durumu | State management (Riverpod/Bloc) | — |

> Token'ı **asla** `SharedPreferences`'ta düz metin saklama. Güvenli depo kullan.

---

## 4. Kimlik doğrulama akışı

### 4.1 Kayıt — `POST /auth/register`

İstek gövdesi:
```json
{ "name": "Ali", "lastname": "Veli", "email": "ali@example.com",
  "phone": "5550001122", "password": "sifre123", "gender": "1" }
```
Yanıt (201): `data.token` ve `data.user` döner.

### 4.2 Giriş — `POST /auth/login`

```json
{ "email": "ali@example.com", "password": "sifre123" }
```
Yanıt (200): `data.token`, `data.user`. Yanlış bilgide **401**.

```dart
Future<Map<String, dynamic>> login(String email, String password) async {
  final res = await Api.instance.dio.post(
    '/auth/login',
    data: {'email': email, 'password': password},
  );
  final body = res.data as Map<String, dynamic>;

  if (body['success'] == true) {
    final token = body['data']['token'] as String;
    await Api.instance.saveToken(token);          // token'ı güvenli sakla
    return body['data']['user'] as Map<String, dynamic>;
  }
  throw Exception(body['error']?['message'] ?? 'Giriş başarısız');
}
```

### 4.3 Mevcut kullanıcı — `GET /auth/me`

Açılışta token geçerli mi diye kontrol et:
```dart
Future<Map<String, dynamic>?> me() async {
  if (await Api.instance.token == null) return null;
  final res = await Api.instance.dio.get('/auth/me');
  final body = res.data as Map<String, dynamic>;
  if (body['success'] == true) return body['data']['user'];
  await Api.instance.clearToken(); // token geçersiz -> temizle
  return null;
}
```

### 4.4 Çıkış — `POST /auth/logout`

```dart
Future<void> logout() async {
  try { await Api.instance.dio.post('/auth/logout'); } catch (_) {}
  await Api.instance.clearToken();
}
```

> **Önemli:** Her `login`/`register` yeni bir token üretir ve eskisini
> geçersiz kılar (kullanıcı başına tek token). 401 alırsan kullanıcıyı
> giriş ekranına yönlendir.

---

## 5. Endpoint referansı

> `{base}` = `https://api.gezgah.com/rest`

### Mekanlar
- `GET {base}/mekanlar` — Query: `type` (`restoran`|`plaj`|`mesire`, vars. `restoran`), `kategori` (id), `bolge`, `q` (arama), `page`, `limit` (maks 100).
- `GET {base}/mekanlar/{id}` — Detay: adres, çalışma saatleri, özellikler, **galeri** dahil.

### Kategoriler
- `GET {base}/kategoriler` — Her kategoride `mekan_sayisi`.
- `GET {base}/kategoriler/{id}/mekanlar` — Sayfalı (`page`, `limit`).

### Etkinlikler
- `GET {base}/etkinlikler` — Query: `status` (vars. 1), `upcoming` (1 = bugünden sonrası), `boss`, `page`, `limit`.
- `GET {base}/etkinlikler/{id}`

### Favoriler (`user_id` = `yzd_users.id`)
- `GET {base}/favoriler?user_id={id}&type=restoran` — `type` opsiyonel filtre.
- `POST {base}/favoriler` — Body: `{ "user_id": 2, "post_id": 2 }`.
- `DELETE {base}/favoriler` — Body: `{ "user_id": 2, "post_id": 2 }`.

### Bildirimler
- `GET {base}/bildirimler` — `page`, `limit`.

### İlçeler / Bölgeler
- `GET {base}/ilceler?sehir=Istanbul` — Bölge filtresi için kullanılır.

### Örnek: mekan listeleme + sayfalama

```dart
Future<({List<dynamic> items, int total, int pages})> mekanlar({
  String type = 'restoran',
  int? kategori,
  String? q,
  int page = 1,
  int limit = 20,
  CancelToken? cancelToken,
}) async {
  final res = await Api.instance.dio.get(
    '/mekanlar',
    queryParameters: {
      'type': type,
      if (kategori != null) 'kategori': kategori,
      if (q != null && q.isNotEmpty) 'q': q,
      'page': page,
      'limit': limit,
    },
    cancelToken: cancelToken,
  );
  final body = res.data as Map<String, dynamic>;
  if (body['success'] != true) {
    throw Exception(body['error']?['message'] ?? 'Hata');
  }
  final meta = body['meta'] as Map<String, dynamic>;
  return (
    items: body['data'] as List<dynamic>,
    total: meta['total'] as int,
    pages: meta['pages'] as int,
  );
}
```

### Görsel URL'leri

Mekan detayındaki `galeri[].url` ve `thumbnail` alanları sunucu kökünden
göreli yol içerir (ör. `/uploads/...`). Eksiksiz URL için gerekiyorsa
`https://api.gezgah.com` ile birleştir ve listede **thumbnail**, detayda tam
boy görseli kullan:

```dart
CachedNetworkImage(imageUrl: 'https://api.gezgah.com${item['thumbnail']}');
```

---

## 6. En performanslı kullanım (öncelik sırasına göre)

1. **Tek Dio örneği + keep-alive.** Singleton istemci bağlantıyı yeniden
   kullanır; her ekranda yeni istemci açma.

2. **Sayfalama (pagination) ve sonsuz liste.** Mekan/kategori listelerinde
   `limit` ile küçük sayfalar çek (ör. 20). Tamamını tek seferde isteme.
   Kullanıcı listeyi kaydırdıkça `page` artır.

3. **Arama için debounce.** `q` ile aramada her tuş vuruşunda istek atma;
   ~350 ms bekle ve önceki isteği `CancelToken` ile iptal et.

   ```dart
   Timer? _debounce;
   CancelToken? _searchCancel;
   void onSearchChanged(String text) {
     _debounce?.cancel();
     _debounce = Timer(const Duration(milliseconds: 350), () {
       _searchCancel?.cancel('yeni arama');
       _searchCancel = CancelToken();
       mekanlar(q: text, cancelToken: _searchCancel);
     });
   }
   ```

4. **Önbellekleme (cache).** Kategoriler ve ilçeler nadiren değişir; bir kez
   çekip bellekte/diskte (Hive) tut, TTL (ör. 1 saat) ile yenile. Aynı veriyi
   tekrar tekrar isteme.

5. **Görsel cache.** `cached_network_image` kullan; listede `thumbnail`,
   detayda tam görsel. Bu ağ trafiğini ve yeniden indirmeyi ciddi azaltır.

6. **Paralel bağımsız istekler.** Açılış ekranında kategoriler + öne çıkan
   mekanlar + bildirimler gibi **birbirinden bağımsız** çağrıları
   `Future.wait` ile aynı anda yap:

   ```dart
   final results = await Future.wait([
     fetchKategoriler(),
     mekanlar(limit: 10),
     fetchBildirimler(),
   ]);
   ```

7. **Gereksiz `me()` çağrısından kaçın.** Kullanıcı profilini girişte alıp
   sakla; her ekranda tekrar `me()` çağırma. Sadece uygulama açılışında
   token doğrulaması için kullan.

8. **Zaman aşımı + nazik hata yönetimi.** `connectTimeout`/`receiveTimeout`
   ayarla. Ağ hatasında kullanıcıya tekrar dene seçeneği sun; çökme yapma.

9. **gzip.** `Accept-Encoding: gzip` çoğu istemcide otomatiktir; Dio bunu
   yönetir. Sunucu destekliyorsa yanıtlar sıkıştırılır.

10. **Sadece gerekeni çek.** Liste ekranında detay endpoint'ini çağırma;
    liste yanıtındaki özet alanlar (ad, telefon, bölge, koordinat) yeterli.
    Detayı yalnızca kullanıcı bir mekana girince (`/mekanlar/{id}`) çek.

---

## 7. Merkezi hata yönetimi (öneri)

```dart
class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => message;
}

T unwrap<T>(Response res) {
  final body = res.data as Map<String, dynamic>;
  if (body['success'] == true) return body['data'] as T;
  throw ApiException(res.statusCode ?? 0, body['error']?['message'] ?? 'Bilinmeyen hata');
}
```

`401` yakalandığında: token'ı temizle ve giriş ekranına yönlendir.

---

## 8. Hızlı özet (asistan için kontrol listesi)

- [ ] Base URL: `https://api.gezgah.com/rest`
- [ ] Tek Dio singleton + AuthInterceptor (Bearer token).
- [ ] Token `flutter_secure_storage`'da.
- [ ] Giriş/kayıt → token sakla; açılışta `me()` ile doğrula.
- [ ] Tüm yanıtlarda `success`/`data`/`error` zarfını kontrol et.
- [ ] Listeler sayfalı (`page`, `limit`); aramada debounce + CancelToken.
- [ ] Kategoriler/ilçeler cache'li; görseller `cached_network_image`.
- [ ] Bağımsız çağrılar `Future.wait` ile paralel.
- [ ] Liste ekranında özet, detayda `/{id}` endpoint'i.
- [ ] 401 → token temizle, login'e yönlendir.
