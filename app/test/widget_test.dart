import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gezgah/theme/app_theme.dart';
import 'package:gezgah/widgets/common.dart';

void main() {
  testWidgets('Gezgah logosu (SVG) render edilir', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: Center(child: GezgahWordmark()),
        ),
      ),
    );
    expect(find.byType(SvgPicture), findsOneWidget);
  });
}
