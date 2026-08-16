import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../data/api.dart';
import '../data/auth_service.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

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

  @override
  void initState() {
    super.initState();
    // Satın alma güncellemelerini dinle (satın al + geri yükle aynı akış).
    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onDone: () => _sub?.cancel(),
      onError: (_) {},
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
    final durum = await PlusRepository.instance.durum();
    // 2) Store'dan ürün ayrıntısı (yerel para birimiyle biçimli fiyat).
    ProductDetails? product;
    var available = true;
    try {
      available = await _iap.isAvailable();
      if (available) {
        final id = _productId(durum);
        final resp = await _iap.queryProductDetails({id});
        if (resp.productDetails.isNotEmpty) {
          product = resp.productDetails.first;
        }
      }
    } catch (_) {
      available = false;
    }
    if (!mounted) return;
    setState(() {
      _durum = durum;
      _product = product;
      _storeAvailable = available;
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
    if (_busy) return;
    // Önce giriş şartı (Plus üyeye bağlanır).
    if (!AuthService.instance.isLoggedIn) {
      final ok = await openLogin(context);
      if (ok != true || !AuthService.instance.isLoggedIn) return;
    }
    if (!_storeAvailable) {
      _snack('Mağazaya ulaşılamıyor. Lütfen daha sonra tekrar dene.');
      return;
    }
    final product = _product;
    if (product == null) {
      _snack('Ürün bilgisi alınamadı. Lütfen daha sonra tekrar dene.');
      return;
    }
    setState(() => _busy = true);
    try {
      final param = PurchaseParam(productDetails: product);
      // Abonelik → non-consumable olarak başlatılır.
      await _iap.buyNonConsumable(purchaseParam: param);
      // Sonuç purchaseStream üzerinden _onPurchaseUpdates'e düşer.
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Satın alma başlatılamadı. Lütfen tekrar dene.');
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    if (!AuthService.instance.isLoggedIn) {
      final ok = await openLogin(context);
      if (ok != true || !AuthService.instance.isLoggedIn) return;
    }
    setState(() => _busy = true);
    try {
      await _iap.restorePurchases();
      // Geri yüklenen satın almalar purchaseStream'e düşer. Kısa bir süre sonra
      // hiçbir şey gelmezse "bulunamadı" mesajı ver.
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted &&
            _busy &&
            !(AuthService.instance.user.value?.isPlus ?? false)) {
          setState(() => _busy = false);
          _snack('Geri yüklenecek aktif abonelik bulunamadı.');
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Geri yükleme yapılamadı. Lütfen tekrar dene.');
    }
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          if (mounted) setState(() => _busy = true);
          break;
        case PurchaseStatus.error:
          if (mounted) {
            setState(() => _busy = false);
            _snack('Satın alma tamamlanamadı. Lütfen tekrar dene.');
          }
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          break;
        case PurchaseStatus.canceled:
          if (mounted) setState(() => _busy = false);
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verify(p);
          if (p.pendingCompletePurchase) await _iap.completePurchase(p);
          break;
      }
    }
  }

  /// Makbuzu backend'e doğrulatır; başarıda Plus aktif olarak kapanır.
  Future<void> _verify(PurchaseDetails p) async {
    try {
      final token = p.verificationData.serverVerificationData;
      if (Platform.isIOS) {
        await AuthService.instance.plusDogrula(platform: 'ios', receipt: token);
      } else {
        await AuthService.instance.plusDogrula(
          platform: 'android',
          purchaseToken: token,
          productId: p.productID,
        );
      }
      if (!mounted) return;
      setState(() => _busy = false);
      _showSuccess();
    } on PlusException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Satın alma doğrulanamadı. Lütfen tekrar dene.');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
      ],
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
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _buy,
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
                  'Abonelik yıllık yenilenir. İstediğin zaman mağaza '
                  'hesabından iptal edebilirsin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
    );
  }
}
