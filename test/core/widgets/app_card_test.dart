import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ophir/core/theme_v1/app_spacing.dart';
import 'package:ophir/core/theme_v1/app_theme.dart';
import 'package:ophir/core/widgets/app_card.dart';

void main() {
  group('AppCard', () {
    Future<void> pump(WidgetTester tester, Widget card) {
      return tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Center(child: SizedBox(width: 200, child: card)),
          ),
        ),
      );
    }

    EdgeInsetsGeometry cardPadding(WidgetTester tester) {
      return tester
          .widget<Padding>(
            find
                .descendant(
                  of: find.byType(AppCard),
                  matching: find.byType(Padding),
                )
                .first,
          )
          .padding;
    }

    testWidgets('renders child with default card insets', (tester) async {
      await pump(tester, const AppCard(child: Text('Content')));

      expect(find.text('Content'), findsOneWidget);
      expect(cardPadding(tester), AppSpacing.cardInsets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('applies custom padding', (tester) async {
      await pump(
        tester,
        const AppCard(padding: AppSpacing.listTileInsets, child: Text('X')),
      );

      expect(cardPadding(tester), AppSpacing.listTileInsets);
    });

    testWidgets('long content wraps inside a narrow card without overflow', (
      tester,
    ) async {
      await pump(tester, AppCard(child: Text('Long content ' * 20)));

      expect(tester.takeException(), isNull);
    });

    testWidgets('hosts ink for tappable descendants', (tester) async {
      var taps = 0;
      await pump(
        tester,
        AppCard(
          child: InkWell(onTap: () => taps += 1, child: const Text('Tap')),
        ),
      );

      await tester.tap(find.text('Tap'));
      await tester.pump();

      expect(taps, 1);
      expect(tester.takeException(), isNull);
    });
  });
}
