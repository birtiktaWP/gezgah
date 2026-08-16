# Gezgah Plus — Mobil (Flutter) IAP Entegrasyon Kılavuzu

Bu doküman **mobil uygulamanın** Gezgah Plus (₺199.99/yıl) satın alma akışını anlatır.
Backend hazırdır ve makbuzu **store ile doğrular**; uygulama satın almayı yapar, makbuzu
backend'e gönderir, başarı durumunda **üye Plus olur** ve **başarı modalı** gösterilir.

- Taban URL: `https://api.gezgah.com/rest/`
- Ürün (product) id: **`plus`** (hem iOS hem Android; App Store Connect / Play Console'da tanımlı, 1 yıl).
- Tüm isteklerde başlıklar: `X-App-Key: ba9db8d2c420adbaeed122fe53c15e878fbcc67b55ba41cd` + `Authorization: Bearer <uye_token>`.

---

## 1. Akış Özeti

```
[Paywall] --buyNonConsumable--> [Store ödeme] --purchaseStream--> purchased/restored
   -> serverVerificationData  ->  POST /uye/plus/dogrula (backend Apple/Google'a doğrular)
   -> { durum: "plus_aktif" }  ->  completePurchase()  ->  BAŞARI MODALI + UI'yı Plus'a çevir
```

- Backend doğrulamadan Plus vermez (fail-safe). Doğrulama başarılıysa `app_uyeler.plus_expires_at`
  set edilir ve `uye.plus.aktif = true` olur.
- `completePurchase()` **yalnızca backend doğrulaması başarılı olduktan sonra** çağrılmalı
  (iOS aksi halde tekrar sorar; Android acknowledge edilmezse ~3 günde iade edilir).

---

## 2. Ön Koşullar

- Paket: `in_app_purchase` (pubspec).
- Kullanıcı **giriş yapmış üye** olmalı (`/uye/giris` → `token`). Plus üyeye bağlanır.
- HTTP istemcinde **X-App-Key + Bearer** interceptor'ı olmalı (aşağıda).
- Hesap kurulumları (kod değil):
  - **App Store Connect**: "Paid Apps" sözleşmesi aktif; `plus` subscription "Ready to Submit".
    Aksi halde `queryProductDetails` ürünü **boş** döner. Test: sandbox / TestFlight kullanıcısı.
  - **Google Play**: `plus` subscription yayında; test için lisanslı test hesabı.

---

## 3. API Uçları (mobil için ilgili olanlar)

### 3.1. Plus durumu
`GET /uye/plus/durum`
```json
{ "plus": {
  "aktif": true, "bitis": "2027-08-16 12:00:00", "kalan_gun": 365,
  "platform": "ios", "product_id": "plus",
  "urun": { "fiyat": "199.99", "para": "TRY", "periyot": "yillik", "ios": "plus", "android": "plus" },
  "ozellikler": ["avatar","gezi_rotalari","kedy"]
}}
```

### 3.2. Satın alma doğrulama
`POST /uye/plus/dogrula`
- iOS: `{ "platform": "ios", "receipt": "<serverVerificationData>" }`
- Android: `{ "platform": "android", "purchase_token": "<serverVerificationData>", "product_id": "plus" }`

Başarılı `200`:
```json
{ "durum": "plus_aktif", "plus": { "aktif": true, "bitis": "..." }, "uye": { ...guncel uye... } }
```
Hatalar: `402` (makbuz doğrulanamadı), `401` (üye değil/oturum yok), `422` (eksik alan).

> `uye` nesnesindeki `uye.plus.aktif = true` olur; UI'ı buna göre Plus moduna al.

---

## 4. HTTP İstemci (Dio) — interceptor

```dart
import 'dart:io';
import 'package:dio/dio.dart';

const kAppKey  = 'ba9db8d2c420adbaeed122fe53c15e878fbcc67b55ba41cd';
const kBaseUrl = 'https://api.gezgah.com/rest';

final dio = Dio(BaseOptions(baseUrl: kBaseUrl))
  ..interceptors.add(InterceptorsWrapper(
    onRequest: (o, h) {
      o.headers['X-App-Key'] = kAppKey;
      final t = TokenStore.token; // flutter_secure_storage'dan okunan üye token'ı
      if (t != null) o.headers['Authorization'] = 'Bearer $t';
      h.next(o);
    },
    onError: (e, h) {
      if (e.response?.statusCode == 401) {
        // oturum düştü -> login ekranına yönlendir
      }
      h.next(e);
    },
  ));
```

---

## 5. PlusPurchaseService (tam, kopyala-kullan)

```dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PlusPurchaseService {
  PlusPurchaseService(this.dio);
  final dynamic dio; // yukarıdaki Dio örneği

  static const String kProductId = 'plus';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  ProductDetails? _product;

  /// Satın alma bittiğinde UI'ya haber vermek için callback'ler.
  void Function()? onPlusActivated;         // -> başarı modalını aç + UI'yı Plus yap
  void Function(String message)? onError;   // -> hata mesajı göster
  void Function()? onPending;               // -> "işleniyor" göstergesi

  bool _verifying = false;

  /// Uygulama açılışında bir kez çağır.
  Future<void> init() async {
    final available = await _iap.isAvailable();
    if (!available) return;

    // iOS: gecikmeli/pending satın almaları da yakalamak için stream'i erken bağla.
    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (e) => onError?.call('Satın alma hatası: $e'),
    );

    final resp = await _iap.queryProductDetails({kProductId});
    if (resp.productDetails.isNotEmpty) {
      _product = resp.productDetails.first;
    }
  }

  void dispose() => _sub?.cancel();

  /// Fiyat metni (paywall'da göstermek için). Store yoksa backend fiyatına düş.
  String get fiyatMetni => _product?.price ?? '₺199,99 / yıl';

  /// Paywall'daki "Plus'a Geç" butonundan çağrılır.
  Future<void> satinAl() async {
    if (_product == null) {
      onError?.call('Ürün bilgisi alınamadı. Lütfen sonra tekrar deneyin.');
      return;
    }
    final param = PurchaseParam(productDetails: _product!);
    // Abonelik → nonConsumable.
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  /// "Satın alımları geri yükle".
  Future<void> geriYukle() => _iap.restorePurchases();

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> list) async {
    for (final p in list) {
      switch (p.status) {
        case PurchaseStatus.pending:
          onPending?.call();
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _dogrulaVeTamamla(p);
          break;

        case PurchaseStatus.error:
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          onError?.call(p.error?.message ?? 'Satın alma tamamlanamadı.');
          break;

        case PurchaseStatus.canceled:
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          break;
      }
    }
  }

  /// Makbuzu backend'e doğrulat; başarılıysa satın almayı tamamla + UI'yı Plus yap.
  Future<void> _dogrulaVeTamamla(PurchaseDetails p) async {
    if (_verifying) return;
    _verifying = true;
    try {
      final token = p.verificationData.serverVerificationData;
      final body = Platform.isIOS
          ? {'platform': 'ios', 'receipt': token}
          : {'platform': 'android', 'purchase_token': token, 'product_id': kProductId};

      final res = await dio.post('/uye/plus/dogrula', data: body);
      final durum = res.data?['data']?['durum'] ?? res.data?['durum'];

      if (durum == 'plus_aktif') {
        if (p.pendingCompletePurchase) await _iap.completePurchase(p);
        onPlusActivated?.call(); // -> başarı modalı + Plus UI
      } else {
        onError?.call('Satın alma doğrulanamadı. Destekle iletişime geçin.');
      }
    } catch (e) {
      // Doğrulanmazsa completePurchase ÇAĞIRMA; kullanıcı tekrar deneyebilir / restore edebilir.
      onError?.call('Doğrulama sırasında hata oluştu. Tekrar deneyin.');
    } finally {
      _verifying = false;
    }
  }
}
```

> Not: Backend yanıtı `{ "success": true, "data": { "durum": "plus_aktif", ... } }` zarfındadır;
> yukarıda hem `data.durum` hem düz `durum` denenir (istemci zarf çözümüne göre birini kullan).

---

## 6. Başarı Modalı (Plus aktif)

`onPlusActivated` tetiklendiğinde göster. Örnek:

```dart
Future<void> showPlusBasariModal(BuildContext context) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: const BoxDecoration(color: Color(0x1A16A34A), shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: Color(0xFF16A34A), size: 44),
          ),
          const SizedBox(height: 16),
          const Text('Gezgah Plus aktif! 🎉',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            'Artık avatar yükleyebilir, gezi rotaları oluşturabilir ve Kedy asistanını kullanabilirsin.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Harika, devam et'),
            ),
          ),
        ]),
      ),
    ),
  );
}
```

Bağlama (ör. paywall ekranında):
```dart
final plus = PlusPurchaseService(dio);

@override
void initState() {
  super.initState();
  plus
    ..onPending = () => setState(() => _loading = true)
    ..onError = (m) { setState(() => _loading = false); showSnack(m); }
    ..onPlusActivated = () async {
      setState(() => _loading = false);
      await context.read<AuthModel>().refreshUye(); // GET /uye/me -> uye.plus.aktif = true
      if (mounted) await showPlusBasariModal(context);
      if (mounted) Navigator.of(context).maybePop(); // paywall'ı kapat
    }
  ..init();
}

@override
void dispose() { plus.dispose(); super.dispose(); }
```

---

## 7. Özellik Kapıları (Plus gerekli)

Backend Plus istenen uçlarda `403 { "error": { "details": { "plus_gerekli": true } } }` döner:
- `POST /uye/avatar`, `POST /uye/rotalar` (ve yazma uçları), `POST /kedy`, `GET /kedy/gecmis`.

İstemci: `403` + `plus_gerekli` görünce **paywall**'a yönlendir. Menülerde Plus rozetleri için
`GET /uye/plus/durum` (veya `uye.plus.aktif`) kullan.

---

## 8. Kontrol Listesi

- [ ] `in_app_purchase` eklendi, `init()` açılışta çağrıldı.
- [ ] Dio interceptor: `X-App-Key` + `Authorization: Bearer`.
- [ ] Paywall fiyatı `_product.price` (yoksa ₺199,99/yıl).
- [ ] Satın alma → `purchaseStream` → `/uye/plus/dogrula` → başarıda `completePurchase`.
- [ ] `onPlusActivated` → `GET /uye/me` ile yenile + **başarı modalı**.
- [ ] "Satın alımları geri yükle" butonu → `restorePurchases()`.
- [ ] `403 plus_gerekli` → paywall yönlendirmesi.
- [ ] Store hesap kurulumları (sözleşme + ürün onayı) tamam.
```
