import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../data/api.dart';
import '../data/auth_service.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/legal_sheet.dart';
import 'login_screen.dart';

/// Geliştirme sırasında IAP akışını ekranda izlemek için debug konsolunu açar.
/// Yayına çıkarken `false` yap (TestFlight/Release'te de görünür, kDebugMode'a
/// bağlı değildir — çünkü TestFlight release moddadır).
const bool kIapDebug = false;

/// Gezgah Plus satın alma (paywall) sayfasını **alttan açılan sheet** olarak
/// gösterir. Kullanıcı Plus üyesi olursa (satın alma / geri yükleme başarılı)
/// `true` ile kapanır (UYELIK_PLUS.md §4).
Future<bool?> openPlus(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => const PlusScreen(),
  );
}

/// Gezgah Plus paywall — özellikleri (avatar / gezi rotaları / Kedy) tanıtır,
/// yıllık ₺199.99 aboneliği `in_app_purchase` ile satar ve makbuzu
/// `POST /uye/plus/dogrula` ile backend'e doğrulatır (UYELIK_PLUS.md §4).
class PlusScreen extends StatefulWidget {
  const PlusScreen({super.key});

  @override
  State<PlusScreen> createState() => _PlusScreenState();
}

class _PlusScreenState extends State<PlusScreen> {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  PlusDurum _durum = const PlusDurum();
  ProductDetails? _product; // store'dan çekilen ürün (fiyat store para birimiyle)
  bool _loading = true;
  bool _busy = false; // satın alma/doğrulama sürüyor
  bool _storeAvailable = true;
  String? _storeNotice; // ürün/mağaza sorunlarını kullanıcıya açıklayan not

  // IAP debug günlüğü (geliştirme). En yeni satırlar sona eklenir.
  final List<String> _debug = [];

  /// Debug konsoluna zaman damgalı satır ekler (kIapDebug açıkken görünür).
  void _log(String msg) {
    // ignore: avoid_print
    print('[IAP] $msg');
    if (!kIapDebug) return;
    final now = DateTime.now();
    final ts =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    if (mounted) {
      setState(() => _debug.add('$ts  $msg'));
    } else {
      _debug.add('$ts  $msg');
    }
  }

  @override
  void initState() {
    super.initState();
    _log('Paywall açıldı · platform=${Platform.operatingSystem}');
    // Satın alma güncellemelerini dinle (satın al + geri yükle aynı akış).
    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onDone: () {
        _log('purchaseStream kapandı (onDone)');
        _sub?.cancel();
      },
      onError: (e) => _log('purchaseStream HATA: $e'),
    );
    _init();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    // 1) Backend'ten güncel durum + ürün bilgisi (fiyat/store id).
    _log('Backend /uye/plus/durum çağrılıyor…');
    final durum = await PlusRepository.instance.durum();
    _log('durum: aktif=${durum.aktif} · store id=ios:${durum.urun.iosId}/'
        'android:${durum.urun.androidId} · fiyat=${durum.urun.fiyat}');
    // 2) Store'dan ürün ayrıntısı (yerel para birimiyle biçimli fiyat).
    ProductDetails? product;
    var available = true;
    String? notice;
    try {
      available = await _iap.isAvailable();
      _log('InAppPurchase.isAvailable() = $available');
      if (!available) {
        notice = 'Bu cihazda uygulama içi satın alma kullanılamıyor.';
      } else {
        final id = _productId(durum);
        _log('queryProductDetails({"$id"}) çağrılıyor…');
        final resp = await _iap.queryProductDetails({id});
        _log('yanıt: bulunan=${resp.productDetails.length} · '
            'bulunamayan=${resp.notFoundIDs} · '
            'error=${resp.error?.code}/${resp.error?.message}');
        if (resp.error != null) {
          notice = 'Mağaza yanıtı alınamadı: ${resp.error!.message}';
        } else if (resp.productDetails.isEmpty) {
          // Ürün mağazada tanımlı/onaylı değil ya da sandbox oturumu yok.
          notice = 'Abonelik ürünü ("$id") mağazada bulunamadı. Mağaza '
              'kurulumu (ürün onayı / sandbox oturumu) tamamlanınca etkinleşir.';
        } else {
          product = resp.productDetails.first;
          _log('ürün OK: id=${product.id} · title=${product.title} · '
              'price=${product.price} (${product.rawPrice} ${product.currencyCode})');
        }
      }
    } catch (e, st) {
      available = false;
      notice = 'Mağazaya bağlanılamadı: $e';
      _log('queryProductDetails İSTİSNA: $e');
      _log('stack: ${st.toString().split('\n').take(3).join(' | ')}');
    }
    if (!mounted) return;
    setState(() {
      _durum = durum;
      _product = product;
      _storeAvailable = available;
      _storeNotice = product == null ? notice : null;
      _loading = false;
    });
  }

  /// Platforma göre store ürün kimliği (backend `urun`'dan; yoksa varsayılan).
  String _productId(PlusDurum d) =>
      Platform.isIOS ? d.urun.iosId : d.urun.androidId;

  /// Gösterilecek fiyat: store fiyatı (yerel para) → backend fiyatı → sabit.
  String get _priceLabel {
    if (_product != null) return _product!.price;
    return '₺${_durum.urun.fiyat}';
  }

  // ---- Satın alma akışı -----------------------------------------------------

  Future<void> _buy() async {
    _log('“Satın Al” tıklandı · girişli=${AuthService.instance.isLoggedIn} · '
        'ürün=${_product?.id ?? "null"}');
    if (_busy) {
      _log('iptal: zaten işlem sürüyor (_busy)');
      return;
    }
    // Önce giriş şartı (Plus üyeye bağlanır).
    if (!AuthService.instance.isLoggedIn) {
      _log('giriş yok → login açılıyor');
      final ok = await openLogin(context);
      if (ok != true || !AuthService.instance.isLoggedIn) {
        _log('login iptal/başarısız → satın alma durdu');
        return;
      }
    }
    if (!_storeAvailable) {
      _log('durdu: mağaza kullanılamıyor');
      _snack('Mağazaya ulaşılamıyor. Lütfen daha sonra tekrar dene.');
      return;
    }
    final product = _product;
    if (product == null) {
      _log('durdu: ürün null');
      _snack('Ürün bilgisi alınamadı. Lütfen daha sonra tekrar dene.');
      return;
    }
    setState(() => _busy = true);
    try {
      final param = PurchaseParam(productDetails: product);
      _log('buyNonConsumable çağrılıyor (id=${product.id})…');
      // Abonelik → non-consumable olarak başlatılır.
      final started = await _iap.buyNonConsumable(purchaseParam: param);
      _log('buyNonConsumable döndü: started=$started '
          '(sonuç purchaseStream ile gelecek)');
      // Sonuç purchaseStream üzerinden _onPurchaseUpdates'e düşer.
    } catch (e) {
      _log('buyNonConsumable İSTİSNA: $e');
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Satın alma başlatılamadı: $e');
    }
  }

  Future<void> _restore() async {
    _log('“Geri Yükle” tıklandı');
    if (_busy) return;
    if (!AuthService.instance.isLoggedIn) {
      final ok = await openLogin(context);
      if (ok != true || !AuthService.instance.isLoggedIn) return;
    }
    setState(() => _busy = true);
    try {
      _log('restorePurchases çağrılıyor…');
      await _iap.restorePurchases();
      // Geri yüklenen satın almalar purchaseStream'e düşer. Kısa bir süre sonra
      // hiçbir şey gelmezse "bulunamadı" mesajı ver.
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted &&
            _busy &&
            !(AuthService.instance.user.value?.isPlus ?? false)) {
          _log('restore: 4sn içinde satın alma gelmedi');
          setState(() => _busy = false);
          _snack('Geri yüklenecek aktif abonelik bulunamadı.');
        }
      });
    } catch (e) {
      _log('restorePurchases İSTİSNA: $e');
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Geri yükleme yapılamadı: $e');
    }
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    _log('purchaseStream: ${purchases.length} güncelleme geldi');
    for (final p in purchases) {
      _log('durum=${p.status.name} · id=${p.productID} · '
          'pendingComplete=${p.pendingCompletePurchase} · err=${p.error?.message ?? "-"}');
      switch (p.status) {
        case PurchaseStatus.pending:
          if (mounted) setState(() => _busy = true);
          break;
        case PurchaseStatus.error:
          if (mounted) {
            setState(() => _busy = false);
            _snack('Satın alma tamamlanamadı: '
                '${p.error?.message ?? "bilinmeyen hata"}');
          }
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          break;
        case PurchaseStatus.canceled:
          _log('kullanıcı iptal etti');
          if (mounted) setState(() => _busy = false);
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // completePurchase YALNIZCA backend doğrulaması başarılıysa çağrılır
          // (MOBIL_IAP_PLUS.md §5). Aksi halde kullanıcı tekrar deneyebilir /
          // geri yükleyebilir; iOS tekrar sorar, Android ~3 günde iade eder.
          final ok = await _verify(p);
          if (ok && p.pendingCompletePurchase) {
            _log('doğrulama OK → completePurchase çağrılıyor');
            await _iap.completePurchase(p);
          } else if (!ok) {
            _log('doğrulama BAŞARISIZ → completePurchase ÇAĞRILMADI');
          }
          break;
      }
    }
  }

  /// Makbuzu backend'e doğrulatır; başarıda Plus aktif olur, başarı modalı
  /// gösterilir ve `true` döner. Doğrulama başarısızsa `false` (satın alma
  /// tamamlanmaz).
  Future<bool> _verify(PurchaseDetails p) async {
    try {
      final token = p.verificationData.serverVerificationData;
      final pref = token.length > 8 ? token.substring(0, 8) : token;
      // 'MII...' → base64 makbuz (StoreKit 1, doğru). 'eyJ...' → JWS (StoreKit 2).
      _log('POST /uye/plus/dogrula · platform=${Platform.operatingSystem} · '
          'token.len=${token.length} · önek="$pref…" · '
          'source=${p.verificationData.source}');
      if (Platform.isIOS) {
        await AuthService.instance.plusDogrula(platform: 'ios', receipt: token);
      } else {
        await AuthService.instance.plusDogrula(
          platform: 'android',
          purchaseToken: token,
          productId: p.productID,
        );
      }
      _log('doğrulama BAŞARILI · plus aktif');
      if (!mounted) return true;
      setState(() => _busy = false);
      _showSuccess();
      return true;
    } on PlusException catch (e) {
      _log('doğrulama PlusException: ${e.message} (detail=${e.detail})');
      if (!mounted) return false;
      setState(() => _busy = false);
      _snack('Doğrulama başarısız: ${e.message}'
          '${e.detail != null ? " [${e.detail}]" : ""}');
      return false;
    } catch (e) {
      _log('doğrulama İSTİSNA: $e');
      if (!mounted) return false;
      setState(() => _busy = false);
      _snack('Satın alma doğrulanamadı: $e');
      return false;
    }
  }

  /// Bilgi/hata mesajını **sheet'in üzerinde görünür** bir dialog ile gösterir.
  /// (SnackBar bottom sheet'in arkasında kalıp görünmediği için kullanılmaz.)
  void _snack(String msg) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        content: Text(msg, style: const TextStyle(fontSize: 14, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  /// Başarılı satın alma modalı; kapatınca ekran `true` ile kapanır.
  Future<void> _showSuccess() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFEAF8EF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.workspace_premium,
                  size: 38, color: AppColors.open),
            ),
            const SizedBox(height: 16),
            const Text('Gezgah Plus aktif!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text(
              'Artık avatar yükleyebilir, gezi rotaları oluşturabilir ve '
              'Kedy ile sohbet edebilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: AppColors.muted),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Harika',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  // ---- UI -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: AppColors.pageBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _topBar(),
                Expanded(child: _content()),
                _bottomBar(),
              ],
            ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: AppColors.ink),
          ),
          const Spacer(),
          TextButton(
            onPressed: _busy ? null : _restore,
            child: const Text('Geri Yükle',
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    final active = AuthService.instance.user.value?.isPlus ?? _durum.aktif;
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
      children: [
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary2, AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.workspace_premium,
                color: Colors.white, size: 44),
          ),
        ),
        const SizedBox(height: 18),
        const Center(
          child: Text('Gezgah Plus',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text(
            'Gezgah\u2019ı sonuna kadar kullan',
            style: TextStyle(fontSize: 14, color: AppColors.muted),
          ),
        ),
        const SizedBox(height: 26),
        if (active) _activeCard() else ..._featureCards(),
        if (kIapDebug) _debugPanel(),
      ],
    );
  }

  /// Geliştirme debug konsolu: IAP akışının tüm adımlarını ekranda gösterir.
  Widget _debugPanel() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1020),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 6),
            child: Row(
              children: [
                const Icon(Icons.bug_report_outlined,
                    size: 18, color: Color(0xFF7DB7FF)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('IAP Debug',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ),
                IconButton(
                  tooltip: 'Kopyala',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    Clipboard.setData(
                        ClipboardData(text: _debug.join('\n')));
                    _snack('Debug günlüğü panoya kopyalandı.');
                  },
                  icon: const Icon(Icons.copy,
                      size: 16, color: Colors.white70),
                ),
                IconButton(
                  tooltip: 'Temizle',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _debug.clear()),
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: Colors.white70),
                ),
                IconButton(
                  tooltip: 'Ürünü yeniden sorgula',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    setState(() => _loading = true);
                    _init();
                  },
                  icon: const Icon(Icons.refresh,
                      size: 18, color: Colors.white70),
                ),
              ],
            ),
          ),
          Container(
            constraints: const BoxConstraints(maxHeight: 240),
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: _debug.isEmpty
                ? const Text('— henüz kayıt yok —',
                    style: TextStyle(fontSize: 11.5, color: Colors.white38))
                : SingleChildScrollView(
                    reverse: true,
                    child: SelectableText(
                      _debug.join('\n'),
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.5,
                        color: Color(0xFFB9C4E0),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _activeCard() {
    final bitis = _durum.bitis ?? AuthService.instance.user.value?.plus.bitis;
    final kalan = _durum.kalanGun;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.listTile,
      ),
      child: Column(
        children: [
          const Icon(Icons.verified, color: AppColors.open, size: 40),
          const SizedBox(height: 12),
          const Text('Plus üyeliğin aktif',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          if (bitis != null && bitis.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              kalan != null
                  ? '$kalan gün kaldı · $bitis tarihine kadar geçerli'
                  : '$bitis tarihine kadar geçerli',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _featureCards() {
    const items = [
      (
        Icons.face_retouching_natural,
        'Avatar Yükle',
        'Profiline kişisel bir fotoğraf ekle.'
      ),
      (
        Icons.route,
        'Gezi Rotaları',
        'Sıralı mekan listeleri oluştur, her durağa notunu ekle.'
      ),
      (
        Icons.auto_awesome,
        'Kedy Yapay Zeka',
        'Mekan önerileri al, rezervasyon yap, menüleri sor.'
      ),
    ];
    return [
      for (final it in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppShadows.listTile,
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(it.$1, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(it.$2,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(it.$3,
                          style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: AppColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  Widget _bottomBar() {
    final active = AuthService.instance.user.value?.isPlus ?? _durum.aktif;
    return Container(
      padding: EdgeInsets.fromLTRB(
          22, 14, 22, 16 + MediaQuery.of(context).viewPadding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, -4)),
        ],
      ),
      child: active
          ? SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Kapat',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(_priceLabel,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    const Text('/ yıl',
                        style: TextStyle(fontSize: 14, color: AppColors.muted)),
                  ],
                ),
                if (_storeNotice != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0x14E0533D),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 18, color: AppColors.closing),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_storeNotice!,
                              style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: AppColors.closing)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: (_busy || _product == null) ? null : _buy,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.4, color: Colors.white),
                          )
                        : const Text('Satın Al',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Abonelik yıllık yenilenir ve dönem sonunda otomatik olarak '
                  'yenilenir. İstediğin zaman mağaza hesabından iptal '
                  'edebilirsin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                _legalLinks(),
              ],
            ),
    );
  }

  /// Abonelik zorunluluğu: Kullanım Koşulları + Gizlilik Politikası linkleri.
  Widget _legalLinks() {
    const linkStyle = TextStyle(
        fontSize: 11,
        color: AppColors.primary,
        fontWeight: FontWeight.w600,
        decoration: TextDecoration.underline);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => showLegalSheet(context, 'Kullanıcı Sözleşmesi'),
          child: const Text('Kullanım Koşulları', style: linkStyle),
        ),
        const Text('  ·  ',
            style: TextStyle(fontSize: 11, color: AppColors.muted)),
        GestureDetector(
          onTap: () => showLegalSheet(context, 'Gizlilik Politikası'),
          child: const Text('Gizlilik Politikası', style: linkStyle),
        ),
      ],
    );
  }
}
