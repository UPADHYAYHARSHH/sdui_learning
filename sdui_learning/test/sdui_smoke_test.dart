import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdui_learning/shared/data/repositories/layout_repository.dart';
import 'package:sdui_learning/shared/sdui/actions/sdui_action_router.dart';
import 'package:sdui_learning/shared/sdui/layout/dynamic_layout_builder.dart';
import 'package:sdui_learning/shared/ui/category_listing_page.dart';
import 'package:sdui_learning/shared/ui/dynamic_layout_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('festival seed JSONs parse and expose a root tree', () async {
    for (final id in ['diwali', 'holi', 'navratri', 'uttarayan']) {
      final raw = await rootBundle.loadString('assets/sdui/$id.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      expect(map['root'], isA<Map>(), reason: '$id missing root');
      expect(map['schemaVersion'], 1, reason: '$id schemaVersion');
      final result = LayoutLoadResult(
        docId: id,
        data: map,
        fromCache: true,
      );
      expect(result.schemaUnsupported, isFalse);
      expect(result.root, isNotNull);
    }
  });

  test('schemaVersion above app support is flagged unsupported', () {
    final result = LayoutLoadResult(
      docId: 'diwali',
      fromCache: true,
      data: {
        'schemaVersion': LayoutRepository.supportedSchemaVersion + 1,
        'root': {'type': 'column', 'children': []},
      },
    );
    expect(result.schemaUnsupported, isTrue);
  });

  testWidgets('unknown SDUI action does not open CategoryListingPage', (
    tester,
  ) async {
    const router = SduiActionRouter();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () => router.dispatch(
                  context,
                  'totally_unknown_action',
                  const {},
                ),
                child: const Text('Go'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Go'));
    await tester.pump();
    expect(find.byType(CategoryListingPage), findsNothing);
    expect(find.textContaining('coming soon'), findsOneWidget);
  });

  testWidgets('open_category passes title into CategoryListingPage', (
    tester,
  ) async {
    const router = SduiActionRouter();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () => router.dispatch(
                  context,
                  'open_category',
                  const {
                    'category': 'Diyas',
                    'sectionTitle': 'Decor · Diyas',
                  },
                ),
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CategoryListingPage), findsOneWidget);
    expect(find.text('Decor · Diyas'), findsOneWidget);
  });

  testWidgets('Diwali filter keeps server product titles (no catalog overwrite)', (
    tester,
  ) async {
    final repo = LayoutRepository(firebaseReady: false);
    await tester.pumpWidget(
      MaterialApp(
        home: DynamicLayoutPage(repository: repo, docId: 'diwali'),
      ),
    );
    // Avoid pumpAndSettle — festival GIFs schedule frames forever.
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
      if (find.text('Silk festive kurta').evaluate().isNotEmpty) break;
    }

    expect(find.text('Silk festive kurta'), findsWidgets);
    expect(find.text('Manyavar'), findsWidgets);

    await tester.tap(find.text('Under\n₹999'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Still the server title — not replaced by hardcoded catalog names.
    expect(find.text('Silk festive kurta'), findsWidgets);
    expect(find.text('Manyavar'), findsWidgets);
    expect(find.textContaining('Under ₹999'), findsWidgets);
  });

  testWidgets('DynamicLayoutBuilder renders product_card from map', (
    tester,
  ) async {
    final builder = DynamicLayoutBuilder();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: builder.build({
            'type': 'product_card',
            'props': {
              'brand': 'Titan Festive',
              'title': 'Gold tone watch',
              'price': '₹999',
              'originalPrice': '₹1999',
              'discount': '50% off',
              'imageUrl': 'diwali/products/gold_tone_watch.jpg',
            },
          }),
        ),
      ),
    );
    expect(find.text('Gold tone watch'), findsOneWidget);
    expect(find.text('Titan Festive'), findsOneWidget);
  });
}
