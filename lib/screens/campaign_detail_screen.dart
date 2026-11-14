import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/kampanya.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/kampanya_widgets.dart';
import 'campaign_qr_screen.dart';
import 'detail_screen.dart';

/// Kampanya detayı (`GET /kampanyalar/{id}`, KAMPANYALAR.md §2–3).
///
/// Üstte işletme görseli + oran rozeti; başlık, açıklama, kapsam / kalan
/// süre / kontenjan çipleri, işletme satırı (dokununca mekan detayı) ve ürün
/// bazlıysa ürünler (eski fiyat üstü çizili + indirimli fiyat). Altta sabit
/// "İşletmede QR okut" düğmesi (KAMPANYA_QR.md): okutucu açılır, işletmedeki
/// QR okutulunca onay kodu gelir; daha önce kullanıldıysa (`kullanimim`)
/// düğme yerine onay kodu büyük punto görünür.
/// Bitmiş kampanyada düğme pasif ve nedenini yazar.
class CampaignDetailScreen extends StatefulWidget {
  final int kampanyaId;

  /// Listeden gelinirse ilk çizim için özet (detay gelince yerini alır).
  final Kampanya? onizleme;
  final KampanyaMekan? mekan;

  const CampaignDetailScreen({
    super.key,
    required this.kampanyaId,
    this.onizleme,
    this.mekan,
  });

  @override
  State<CampaignDetailScreen> createState() => _CampaignDetailScreenState();
}

class _CampaignDetailScreenState extends State<CampaignDetailScreen> {
  Kampanya? _k;
  bool _loading = true;
  String? _error; // yükleme hatası (detay hiç gelmediyse)

  @override
  void initState() {
    super.initState();
    _k = widget.onizleme;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final k = await KampanyaRepository.instance.detay(widget.kampanyaId);
      if (!mounted) return;
      setState(() {
        _k = k;
        _loading = false;
      });
    } on KampanyaException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
        if (e.bulunamadi) _k = null;
      });
    }
  }

  KampanyaMekan? get _mekan => _k?.mekan ?? widget.mekan;

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  /// Kampanya yalnız işletmede QR okutularak kullanılır (KAMPANYA_QR.md).
  /// Okutucu girişi kendisi ister; başarıda onay ekranı açılır, dönüşte bu
  /// sayfa onay koduyla güncellenir.
  Future<void> _scan() async {
    final k = _k;
    if (k == null) return;
    final s = await openKampanyaQr(context);
    if (!mounted || s == null) return;
    if (s.kampanya?.id == k.id) {
      setState(() => _k = _k!.withKullanim(s.kullanim));
    } else {
      // Başka bir kampanyanın QR'ı okutuldu: bu sayfanın durumu tazelensin.
      _load();
    }
  }

  void _openMekan() {
    final m = _mekan;
    if (m == null || m.id <= 0) return;
    Navigator.push(
      context,
      detailRoute(builder: (_) => DetailScreen(place: m.toPlace())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final k = _k;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          if (k == null)
            _emptyState()
          else
            ListView(
              padding: EdgeInsets.only(
                bottom: 150 + MediaQuery.of(context).padding.bottom,
              ),
              children: [
                _hero(k),
                Transform.translate(
                  offset: const Offset(0, -22),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
                    child: _body(k),
                  ),
                ),
              ],
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.topLeft,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chevron_left,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (k != null)
            Align(alignment: Alignment.bottomCenter, child: _bottomBar(k)),
        ],
      ),
    );
  }

  Widget _emptyState() {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.primary,
          ),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_offer_outlined,
                size: 34,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Kampanya bulunamadı.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: _load, child: const Text('Tekrar dene')),
          ],
        ),
      ),
    );
  }

  Widget _hero(Kampanya k) {
    final m = _mekan;
    final img = m?.thumbWide ?? '';
    return SizedBox(
      height: 250,
      child: Stack(
        fit: StackFit.expand,
        children: [
          img.isNotEmpty
              ? NetImage(img)
              : const ColoredBox(
                  color: AppColors.primarySoft,
                  child: Icon(
                    Icons.local_offer_outlined,
                    size: 56,
                    color: AppColors.primary,
                  ),
                ),
          Positioned(
            right: 16,
            bottom: 36,
            child: KampanyaRozet(k.oran, fontSize: 22),
          ),
        ],
      ),
    );
  }

  Widget _body(Kampanya k) {
    final chips = <(IconData, String)>[
      (
        k.urunBazli ? Icons.restaurant_menu : Icons.menu_book_outlined,
        k.kapsam,
      ),
      if (k.aktif && k.kalanSure() != null)
        (Icons.schedule_outlined, k.kalanSure()!),
      if (k.aktif && k.kontenjan() != null)
        (Icons.people_outline, k.kontenjan()!),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!k.aktif) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F6),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              k.pasifNedeni,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Text(
          k.gosterilenBaslik,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
            height: 1.25,
          ),
        ),
        if (k.aciklama.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            k.aciklama,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.muted,
            ),
          ),
        ],
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (icon, text) in chips)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 15, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      text,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (_mekan != null) ...[const SizedBox(height: 18), _mekanRow()],
        if (k.urunBazli && k.urunler.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            'İndirimli ürünler',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          for (final u in k.urunler) _urunRow(u),
        ] else if (!k.urunBazli) ...[
          const SizedBox(height: 18),
          Text(
            'İndirim, işletmenin menüsündeki tüm ürünlerde %${k.oran} olarak '
            'uygulanır.',
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.muted,
            ),
          ),
        ],
        const SizedBox(height: 20),
        const Text(
          'Nasıl kullanılır?',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'İşletmeye git, ödeme sırasında kasadan kampanya QR’ını iste ve '
          '"İşletmede QR okut" ile okut. Çıkan onay kodunu kasada göster. Her '
          'kampanyayı bir kez kullanabilirsin.',
          style: TextStyle(fontSize: 13, height: 1.45, color: AppColors.muted),
        ),
      ],
    );
  }

  Widget _mekanRow() {
    final m = _mekan!;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: _openMekan,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 46,
                  height: 46,
                  child: m.thumbSquare.isNotEmpty
                      ? NetImage(m.thumbSquare)
                      : const ColoredBox(
                          color: AppColors.primarySoft,
                          child: Icon(
                            Icons.storefront_outlined,
                            color: AppColors.primary,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.ad.isNotEmpty ? m.ad : 'Mekan',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    if (m.konum.isNotEmpty)
                      Text(
                        m.konum,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.muted,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }

  static String _tl(num v) {
    final s = v == v.roundToDouble()
        ? v.round().toString()
        : v.toStringAsFixed(2).replaceAll('.', ',');
    return '$s ₺';
  }

  Widget _urunRow(KampanyaUrun u) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 54,
              height: 54,
              child: u.gorsel.isNotEmpty
                  ? NetImage(u.gorsel)
                  : const ColoredBox(
                      color: AppColors.primarySoft,
                      child: Icon(
                        Icons.restaurant_outlined,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  u.ad,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                if (u.kategori.isNotEmpty)
                  Text(
                    u.kategori,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (u.indirimliFiyat != null && u.fiyat != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _tl(u.fiyat!),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: AppColors.muted,
                  ),
                ),
                Text(
                  _tl(u.indirimliFiyat!),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.closing,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ---- alttaki düğme / kod -------------------------------------------------

  Widget _bottomBar(Kampanya k) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final u = k.kullanimim;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: u != null ? _codeView(u) : _useButton(k),
    );
  }

  /// "QR okut" düğmesi (KAMPANYA_QR.md): kampanya yalnız işletmedeki QR
  /// okutularak kullanılır. Bitmiş kampanyada pasif, nedenini yazar.
  Widget _useButton(Kampanya k) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 54,
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: k.aktif ? _scan : null,
            icon: k.aktif
                ? const Icon(Icons.qr_code_scanner_rounded, size: 22)
                : const SizedBox.shrink(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFE6E6EE),
              disabledForegroundColor: AppColors.muted,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            label: Text(
              k.aktif ? 'İşletmede QR okut' : k.pasifNedeni,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        if (k.aktif) ...[
          const SizedBox(height: 8),
          const Text(
            'Kasadaki ekranda gösterilen kampanya QR’ını okut.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ],
    );
  }

  Widget _codeView(KampanyaKullanim u) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Bu kodu kasada göster',
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 6),
        Semantics(
          label: 'Kampanya kodu ${u.kod.split('').join(' ')}',
          child: GestureDetector(
            onLongPress: () {
              Clipboard.setData(ClipboardData(text: u.kod));
              _snack('Kod kopyalandı');
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary, width: 1.4),
              ),
              alignment: Alignment.center,
              child: Text(
                u.kod,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 6,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ),
        if (u.tarih != null) ...[
          const SizedBox(height: 6),
          Text(
            'Alındı: ${_tarih(u.tarih!)}',
            style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
          ),
        ],
      ],
    );
  }

  static String _tarih(DateTime d) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.day)}.${p(d.month)}.${d.year} ${p(d.hour)}:${p(d.minute)}';
  }
}
