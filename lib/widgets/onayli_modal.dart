import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Onaylı işletme (mavi tik) bilgi modalı. Mekan detayındaki ve rota
/// yorumlarındaki mavi tike dokununca gösterilir.
const Color kOnayliMavi = Color(0xFF3897F0);

void showOnayliIsletmeModal(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified, size: 64, color: kOnayliMavi),
            const SizedBox(height: 16),
            const Text('Onaylı İşletme',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink)),
            const SizedBox(height: 10),
            const Text(
              'Bu işletme Gezgah tarafından onaylanmıştır ve partnerlik '
              'anlaşması mevcuttur.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 13.5, height: 1.5, color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Tamam',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
