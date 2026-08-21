import 'package:flutter/material.dart';

import '../data/legal_texts.dart';
import '../theme/app_theme.dart';

/// Yasal metni (Kullanıcı Sözleşmesi / Gizlilik Politikası vb.) alttan açılan
/// bağımsız bir sheet'te gösterir. Paywall ve diğer ekranlarda kullanılır.
void showLegalSheet(BuildContext context, String title) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LegalSheet(title: title),
  );
}

class _LegalSheet extends StatelessWidget {
  final String title;
  const _LegalSheet({required this.title});

  @override
  Widget build(BuildContext context) {
    final sections = kLegalTexts[title];
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
                  child: Text(title,
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
            child: (sections == null || sections.isEmpty)
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('Bu metin yakında eklenecek.',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(fontSize: 14, color: AppColors.muted)),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                        22, 18, 22, 28 + MediaQuery.of(context).padding.bottom),
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
