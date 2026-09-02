import 'package:flutter/material.dart';

import '../data/consent_service.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import 'legal_sheet.dart';

/// Sözleşme onay paneli — üye ilk girişinden sonra (veya bir metnin sürümü
/// değiştiğinde) gösterilir. Onaylanmadan uygulama kullanılamaz: panel
/// kapatılamaz (barrier/geri tuşu kapalı), yalnız onayla kapanır.
///
/// Gösterilecek metinler `ConsentService.pending` üzerinden gelir
/// (`GET /sozlesmeler?tip=zorunlu`; uçlar yayında değilse gömülü yedek).
Future<void> showConsentSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (_) => const PopScope(
      canPop: false, // geri tuşuyla atlatılamaz
      child: _ConsentSheet(),
    ),
  );
}

class _ConsentSheet extends StatefulWidget {
  const _ConsentSheet();

  @override
  State<_ConsentSheet> createState() => _ConsentSheetState();
}

class _ConsentSheetState extends State<_ConsentSheet> {
  /// Tümünü tek kutuda onaylamak yerine her sözleşme ayrı onaylanır.
  final Set<String> _checked = {};
  bool _saving = false;

  List<Sozlesme> get _docs => ConsentService.instance.pending;

  bool get _allChecked =>
      _docs.isNotEmpty && _docs.every((d) => _checked.contains(d.slug));

  Future<void> _accept() async {
    if (!_allChecked || _saving) return;
    setState(() => _saving = true);
    await ConsentService.instance.accept(_docs);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 8, 22, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sözleşmeler ve Onaylar',
                    style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink)),
                SizedBox(height: 8),
                Text(
                  'Gezgah\u2019ı kullanmaya başlamadan önce aşağıdaki metinleri '
                  'incelemen ve onaylaman gerekiyor. Metni açmak için başlığa '
                  'dokunabilirsin.',
                  style: TextStyle(
                      fontSize: 13.5, height: 1.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.line),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(22, 6, 22, 12),
              itemCount: _docs.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.line),
              itemBuilder: (_, i) => _row(_docs[i]),
            ),
          ),
          const Divider(height: 1, color: AppColors.line),
          Padding(
            padding: EdgeInsets.fromLTRB(22, 12, 22, 16 + bottom),
            child: Column(
              children: [
                // Hepsini işaretle kısayolu.
                GestureDetector(
                  onTap: () => setState(() {
                    if (_allChecked) {
                      _checked.clear();
                    } else {
                      _checked.addAll(_docs.map((d) => d.slug));
                    }
                  }),
                  child: Row(
                    children: [
                      _box(_allChecked),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('Tümünü okudum ve onaylıyorum',
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _allChecked && !_saving ? _accept : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.primary.withValues(alpha: 0.35),
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.2, color: Colors.white),
                          )
                        : const Text('Onayla ve Devam Et',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(Sozlesme doc) {
    final checked = _checked.contains(doc.slug);
    // Gömülü yedek kayıtlarda slug "local:<başlık>" olur → API'ye gitmesin.
    final slug = doc.slug.startsWith('local:') ? null : doc.slug;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() {
              if (checked) {
                _checked.remove(doc.slug);
              } else {
                _checked.add(doc.slug);
              }
            }),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
              child: _box(checked),
            ),
          ),
          const SizedBox(width: 8),
          // Başlığa dokununca metin ayrı sheet'te açılır.
          Expanded(
            child: GestureDetector(
              onTap: () => showLegalSheet(context, doc.baslik, slug: slug),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(doc.baslik,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink)),
                          if (doc.ozet.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(doc.ozet,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    height: 1.35,
                                    color: AppColors.muted)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Oku',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                    const Icon(Icons.chevron_right,
                        size: 18, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _box(bool checked) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: checked ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: checked ? AppColors.primary : const Color(0xFFC8C8D4),
            width: 1.6),
      ),
      child: checked
          ? const Icon(Icons.check, size: 15, color: Colors.white)
          : null,
    );
  }
}
