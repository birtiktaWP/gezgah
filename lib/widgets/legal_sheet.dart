import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/legal_texts.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';

/// Yasal metni alttan açılan bağımsız bir sheet'te gösterir.
///
/// [slug] verilirse metin `GET /sozlesmeler/{slug}` ile sunucudan çekilir
/// (SOZLESMELER.md). Ağ hatası/404 durumunda uygulamaya gömülü metne
/// ([kLegalTexts]) düşülür — sözleşme onay kapısı bu metinlere bağlı olduğu
/// için ekran hiçbir koşulda boş kalmamalı.
void showLegalSheet(BuildContext context, String title, {String? slug}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LegalSheet(title: title, slug: slug),
  );
}

class _LegalSheet extends StatefulWidget {
  final String title;
  final String? slug;
  const _LegalSheet({required this.title, this.slug});

  @override
  State<_LegalSheet> createState() => _LegalSheetState();
}

class _LegalSheetState extends State<_LegalSheet> {
  /// Sunucudan gelen metin (yoksa gömülü metne düşülür).
  Sozlesme? _remote;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final slug = widget.slug;
    if (slug != null && slug.isNotEmpty) _load(slug);
  }

  Future<void> _load(String slug) async {
    setState(() => _loading = true);
    final s = await SozlesmeRepository.instance.metin(slug);
    if (!mounted) return;
    setState(() {
      _remote = s;
      _loading = false;
    });
  }

  /// Gösterilecek bölümler: önce sunucu gövdesi, yoksa gömülü metin.
  List<LegalSection> get _sections {
    final r = _remote;
    if (r != null && r.icerik.trim().isNotEmpty) {
      return parseLegalBody(r.icerik);
    }
    return kLegalTexts[widget.title] ?? const [];
  }

  String get _title {
    final r = _remote;
    return (r != null && r.baslik.isNotEmpty) ? r.baslik : widget.title;
  }

  @override
  Widget build(BuildContext context) {
    final sections = _sections;
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.bg,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(_title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.ink),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.line),
          Expanded(
            child: _loading && sections.isEmpty
                ? const Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: AppColors.primary),
                    ),
                  )
                : sections.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('Bu metin şu an görüntülenemiyor.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 14, color: AppColors.muted)),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(22, 18, 22,
                            28 + MediaQuery.of(context).padding.bottom),
                        itemCount: sections.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 20),
                        itemBuilder: (_, i) => _section(sections[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _section(LegalSection s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (s.heading != null) ...[
          Text(s.heading!,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink)),
          const SizedBox(height: 10),
        ],
        for (var i = 0; i < s.paragraphs.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _paragraph(s.paragraphs[i]),
        ],
      ],
    );
  }

  /// `**...**` işaretli kısımları kalın gösteren basit paragraf oluşturucu.
  Widget _paragraph(String text) {
    const base =
        TextStyle(fontSize: 13.5, height: 1.55, color: AppColors.muted);
    final spans = <TextSpan>[];
    final parts = text.split('**');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      spans.add(TextSpan(
        text: parts[i],
        style: i.isOdd
            ? const TextStyle(
                fontWeight: FontWeight.w600, color: AppColors.ink)
            : null,
      ));
    }
    return RichText(text: TextSpan(style: base, children: spans));
  }
}
