import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdui_learning/shared/data/repositories/layout_repository.dart';
import 'package:sdui_learning/shared/sdui/actions/sdui_action_router.dart';
import 'package:sdui_learning/shared/sdui/layout/dynamic_layout_builder.dart';
import 'package:sdui_learning/shared/sdui/layout/sdui_json.dart';
import 'package:sdui_learning/shared/ui/category_listing_page.dart';
import 'package:sdui_learning/shared/ui/checkout_page.dart';
import 'package:sdui_learning/shared/ui/dynamic_layout_page.dart';
import 'package:sdui_learning/shared/ui/see_all_page.dart';

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() ready, {
  int maxFrames = 50,
}) async {
  for (var i = 0; i < maxFrames; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    if (ready()) return;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ShoppingBagStore.instance.clear();
  });

  group('ShoppingBagStore', () {
    test('canonicalId is stable across entry points', () {
      expect(ShoppingBagStore.canonicalId('p1'), 'p1');
      expect(ShoppingBagStore.canonicalId('p1', size: 'M'), 'p1_M');
      expect(ShoppingBagStore.canonicalId('p1', size: ' M '), 'p1_M');
    });

    test('addItem merges quantity for the same canonical id', () {
      final store = ShoppingBagStore.instance;
      store.addItem(
        const CheckoutItem(
          id: 'silk_festive_kurta_M',
          title: 'Silk festive kurta',
          brand: 'Manyavar',
          price: 799,
          originalPrice: 1599,
          size: 'M',
        ),
      );
      store.addItem(
        const CheckoutItem(
          id: 'silk_festive_kurta_M',
          title: 'Silk festive kurta',
          brand: 'Manyavar',
          price: 799,
          originalPrice: 1599,
          size: 'M',
          quantity: 2,
        ),
      );

      expect(store.distinctCount, 1);
      expect(store.totalQuantity, 3);
      expect(store.quantityFor('silk_festive_kurta_M'), 3);
    });

    test('different sizes stay as separate line items', () {
      final store = ShoppingBagStore.instance;
      store.addItem(
        CheckoutItem(
          id: ShoppingBagStore.canonicalId('p1', size: 'S'),
          title: 'Kurta',
          brand: 'Fabindia',
          price: 799,
          size: 'S',
        ),
      );
      store.addItem(
        CheckoutItem(
          id: ShoppingBagStore.canonicalId('p1', size: 'L'),
          title: 'Kurta',
          brand: 'Fabindia',
          price: 799,
          size: 'L',
        ),
      );

      expect(store.distinctCount, 2);
      expect(store.totalQuantity, 2);
    });

    test('setQuantity 0 removes item and notifyListeners fires', () {
      final store = ShoppingBagStore.instance;
      var ticks = 0;
      void listener() => ticks++;
      store.addListener(listener);
      store.addItem(
        const CheckoutItem(
          id: 'x',
          title: 'Item',
          brand: 'Brand',
          price: 100,
        ),
      );
      expect(ticks, 1);
      store.setQuantity('x', 0);
      expect(store.items, isEmpty);
      expect(ticks, 2);
      store.removeListener(listener);
    });
  });

  group('CheckoutPriceSummary', () {
    CheckoutItem item(int price, {int qty = 1, int? mrp}) => CheckoutItem(
          id: 'i$price',
          title: 'Item $price',
          brand: 'Brand',
          price: price,
          originalPrice: mrp ?? price * 2,
          quantity: qty,
        );

    test('PREPAID10 applies on UPI but not on Cash on Delivery', () {
      final items = [item(1000)];
      final prepaid = CheckoutPriceSummary.calculate(
        items,
        promoApplied: true,
        paymentMethod: 'UPI (Instant)',
      );
      final cod = CheckoutPriceSummary.calculate(
        items,
        promoApplied: true,
        paymentMethod: 'Cash on Delivery',
      );

      expect(prepaid.promoDiscount, 100);
      expect(cod.promoDiscount, 0);
      expect(prepaid.totalPayable, 900);
      expect(cod.totalPayable, 1000);
    });

    test('delivery fee is 49 under ₹499 and free at/above ₹499', () {
      final paid = CheckoutPriceSummary.calculate(
        [item(400)],
        promoApplied: false,
      );
      final free = CheckoutPriceSummary.calculate(
        [item(499)],
        promoApplied: false,
      );
      expect(paid.deliveryFee, 49);
      expect(paid.totalPayable, 449);
      expect(free.deliveryFee, 0);
      expect(free.totalPayable, 499);
    });

    test('empty bag summary is zeroed', () {
      final summary = CheckoutPriceSummary.calculate(
        const [],
        promoApplied: true,
        paymentMethod: 'UPI (Instant)',
      );
      expect(summary.itemCount, 0);
      expect(summary.subtotal, 0);
      expect(summary.promoDiscount, 0);
      expect(summary.deliveryFee, 0);
      expect(summary.totalPayable, 0);
    });
  });

  group('SeeAllProduct parsing', () {
    test('fromCardProps reads categories and rupee strings', () {
      final product = SeeAllProduct.fromCardProps(
        {
          'id': 'gold_tone_watch',
          'brand': 'Titan Festive',
          'title': 'Gold tone watch',
          'price': '₹999',
          'originalPrice': '₹1,999',
          'discount': '50% off',
          'imageUrl': 'diwali/products/gold_tone_watch.jpg',
          'categories': ['gifts', 'diwali'],
        },
        id: 'gold_tone_watch',
      );

      expect(product, isNotNull);
      expect(product!.price, 999);
      expect(product.originalPrice, 1999);
      expect(product.categories, containsAll(['gifts', 'diwali']));
    });

    test('fromCardProps rejects empty title or zero price', () {
      expect(
        SeeAllProduct.fromCardProps({'title': '', 'price': '₹10'}, id: 'a'),
        isNull,
      );
      expect(
        SeeAllProduct.fromCardProps({'title': 'X', 'price': '₹0'}, id: 'b'),
        isNull,
      );
    });
  });

  group('LayoutRepository', () {
    test('offline watch loads exact seed docId', () async {
      final repo = LayoutRepository(firebaseReady: false);
      final result = await repo.watch('diwali').first;
      expect(result.docId, 'diwali');
      expect(result.fromCache, isTrue);
      expect(result.data['id'], 'diwali');
      expect(result.root, isNotNull);
      expect(result.schemaUnsupported, isFalse);
    });

    test('missing seed throws instead of silently swapping festivals', () async {
      final repo = LayoutRepository(firebaseReady: false);
      await expectLater(
        repo.watch('does_not_exist_screen').first,
        throwsA(isA<StateError>()),
      );
    });

    test('watchActive offline defaults to holi', () async {
      final repo = LayoutRepository(firebaseReady: false);
      final result = await repo.watchActive().first;
      expect(result.docId, LayoutRepository.defaultDocId);
      expect(result.fromCache, isTrue);
    });

    test('LayoutLoadResult meaningful change ignores key order', () {
      final a = LayoutLoadResult(
        docId: 'diwali',
        fromCache: false,
        data: {
          'title': 'Home',
          'root': {
            'type': 'column',
            'props': {'gap': 8},
          },
        },
      );
      final b = LayoutLoadResult(
        docId: 'diwali',
        fromCache: false,
        data: {
          'root': {
            'props': {'gap': 8},
            'type': 'column',
          },
          'title': 'Home',
        },
      );
      expect(a.isMeaningfullyDifferentFrom(b), isFalse);
      expect(SduiJson.hasMeaningfulChange(a.data, b.data), isFalse);
    });
  });

  group('SduiActionRouter', () {
    testWidgets('open_checkout opens CheckoutPage', (tester) async {
      const router = SduiActionRouter();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () =>
                    router.dispatch(context, 'open_checkout', const {}),
                child: const Text('Bag'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Bag'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(CheckoutPage), findsOneWidget);
    });

    testWidgets('open_profile shows coming soon snackbar', (tester) async {
      const router = SduiActionRouter();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () =>
                    router.dispatch(context, 'open_profile', const {}),
                child: const Text('Profile'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Profile'));
      await tester.pump();
      expect(find.textContaining('coming soon'), findsOneWidget);
    });

    testWidgets('open_search opens search sheet', (tester) async {
      const router = SduiActionRouter();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => router.openSearch(context, {
                  'searchHint': 'Search diyas',
                }),
                child: const Text('Search'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Search'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Search'), findsWidgets);
      expect(find.text('Search diyas'), findsOneWidget);
    });

    testWidgets('navigate_back pops when possible', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      const router = SduiActionRouter();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: Scaffold(
            body: ElevatedButton(
              onPressed: () {
                navKey.currentState!.push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      body: Builder(
                        builder: (ctx) => ElevatedButton(
                          onPressed: () => router.dispatch(
                            ctx,
                            'navigate_back',
                            const {},
                          ),
                          child: const Text('GoBack'),
                        ),
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('GoBack'), findsOneWidget);
      expect(navKey.currentState!.canPop(), isTrue);
      await tester.tap(find.text('GoBack'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(navKey.currentState!.canPop(), isFalse);
      expect(find.text('Open'), findsOneWidget);
    });
  });

  group('CategoryListingPage filters', () {
    testWidgets('Filter chip opens Filters sheet not Sort', (tester) async {
      final binding = tester.view;
      binding.physicalSize = const Size(800, 1400);
      binding.devicePixelRatio = 1.0;
      addTearDown(binding.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(home: CategoryListingPage()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Filter'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Clear all filters'), findsOneWidget);
      expect(find.text('Sort by'), findsNothing);
    });

    testWidgets('Brand filter narrows product list', (tester) async {
      final binding = tester.view;
      binding.physicalSize = const Size(800, 1400);
      binding.devicePixelRatio = 1.0;
      addTearDown(binding.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(home: CategoryListingPage()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('8 products'), findsOneWidget);

      await tester.tap(find.text('Size'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('XS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Size: XS'), findsOneWidget);

      await tester.tap(find.text('Brand'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // Prefer the sheet option, not the product-card brand label.
      await tester.tap(find.text('Fabindia').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('1 products'), findsOneWidget);
      expect(find.text('Cotton straight kurta'), findsOneWidget);
      expect(find.text('Embroidered kurta set'), findsNothing);
    });
  });

  group('DynamicLayoutPage resilience', () {
    testWidgets('unsupported schemaVersion shows Retry UI', (tester) async {
      final repo = _UnsupportedSchemaRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: DynamicLayoutPage(repository: repo, docId: 'diwali'),
        ),
      );
      await _pumpUntil(
        tester,
        () => find.text('Retry').evaluate().isNotEmpty,
      );

      expect(find.text('Retry'), findsOneWidget);
      expect(find.textContaining('schema'), findsOneWidget);
    });

    testWidgets('Live chip appears when showAppBar is false', (tester) async {
      final repo = _StaticFestivalRepository(
        docId: 'diwali',
        title: 'Home · Diwali',
        showAppBar: false,
        withSearchHint: false,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DynamicLayoutPage(repository: repo, docId: 'diwali'),
        ),
      );
      await _pumpUntil(
        tester,
        () => find.textContaining('Offline · diwali').evaluate().isNotEmpty ||
            find.textContaining('Live · diwali').evaluate().isNotEmpty,
      );
      expect(
        find.textContaining('diwali'),
        findsWidgets,
      );
    });

    testWidgets('search action opens local search sheet', (tester) async {
      final repo = _StaticFestivalRepository(
        docId: 'diwali',
        title: 'Home · Diwali',
        showAppBar: false,
        withSearchHint: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DynamicLayoutPage(repository: repo, docId: 'diwali'),
        ),
      );
      await _pumpUntil(
        tester,
        () => find.text('Search diyas, kurtas, gifts').evaluate().isNotEmpty,
      );

      await tester.tap(find.text('Search diyas, kurtas, gifts'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('DynamicLayoutBuilder catalog', () {
    testWidgets('visible:false hides product_card', (tester) async {
      final builder = DynamicLayoutBuilder();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: builder.build({
              'type': 'column',
              'children': [
                {
                  'type': 'product_card',
                  'props': {
                    'brand': 'Shown',
                    'title': 'Visible item',
                    'price': '₹100',
                    'visible': true,
                  },
                },
                {
                  'type': 'product_card',
                  'props': {
                    'brand': 'Hidden',
                    'title': 'Invisible item',
                    'price': '₹100',
                    'visible': false,
                  },
                },
              ],
            }),
          ),
        ),
      );
      expect(find.text('Visible item'), findsOneWidget);
      expect(find.text('Invisible item'), findsNothing);
    });

    testWidgets('unknown type is invisible by default', (tester) async {
      final builder = DynamicLayoutBuilder();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: builder.build({
              'type': 'totally_unknown_widget',
              'props': {'value': 'nope'},
            }),
          ),
        ),
      );
      expect(find.text('nope'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('failUnknownVisibly shows diagnostic in debug path', (
      tester,
    ) async {
      final builder = DynamicLayoutBuilder(failUnknownVisibly: true);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: builder.build({
              'type': 'totally_unknown_widget',
              'props': {},
            }),
          ),
        ),
      );
      expect(find.textContaining('unknown'), findsOneWidget);
    });

    testWidgets('bottom_nav Bag opens checkout via action router', (
      tester,
    ) async {
      final builder = DynamicLayoutBuilder();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const SizedBox.shrink(),
            bottomNavigationBar: builder.build(const {
              'type': 'bottom_nav',
              'props': {
                'activeIndex': 0,
                'items': ['Home', 'Categories', 'Bag', 'Profile'],
              },
            }),
          ),
        ),
      );
      await tester.tap(find.text('Bag'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(CheckoutPage), findsOneWidget);
    });
  });

  group('Festival JSON smoke parse', () {
    for (final id in ['diwali', 'holi', 'navratri', 'uttarayan']) {
      test('$id seed is well-formed for the live builder', () async {
        final raw = await rootBundle.loadString('assets/sdui/$id.json');
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final root = map['root'];
        expect(map['schemaVersion'], 1);
        expect(root, isA<Map>());
        expect((root as Map)['type'], isNotEmpty);

        // Walk nodes and ensure every node has a type string.
        void walk(Object? node) {
          if (node is! Map) return;
          expect(node['type'], isNotNull, reason: '$id node missing type');
          if (node['child'] != null) walk(node['child']);
          final children = node['children'];
          if (children is List) {
            for (final child in children) {
              walk(child);
            }
          }
        }

        walk(root);
      });
    }
  });

  group('SDUI honesty', () {
    testWidgets('SeeAllPage with empty products shows empty catalog state', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SeeAllPage(
            title: 'Empty',
            products: [],
            categories: ['All'],
          ),
        ),
      );
      expect(find.text('No products from this screen'), findsOneWidget);
      expect(find.textContaining('no product cards'), findsOneWidget);
    });

    testWidgets('SeeAllPage renders only passed SDUI products', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SeeAllPage(
            title: 'From SDUI',
            products: const [
              SeeAllProduct(
                id: 'only1',
                brand: 'Brand',
                title: 'Only SDUI Card',
                price: 499,
                originalPrice: 999,
                discount: '50% off',
                imageUrl: '',
                categories: ['gifts'],
              ),
            ],
            categories: const ['All'],
          ),
        ),
      );
      expect(find.text('Only SDUI Card'), findsOneWidget);
      expect(find.text('Gold tone watch'), findsNothing);
    });

    testWidgets('COD disables PREPAID10 switch with prepaid-only copy', (
      tester,
    ) async {
      ShoppingBagStore.instance.addItem(
        const CheckoutItem(
          id: 'p1',
          title: 'Test',
          brand: 'Brand',
          price: 800,
          originalPrice: 1000,
        ),
      );
      ShoppingBagStore.instance.setPromoApplied(true);

      await tester.pumpWidget(const MaterialApp(home: CheckoutPage()));
      await tester.pump();

      await tester.tap(find.text('Cash on Delivery'));
      await tester.pump();

      expect(
        find.textContaining('Prepaid only'),
        findsOneWidget,
      );
      final summary = CheckoutPriceSummary.calculate(
        ShoppingBagStore.instance.items,
        promoApplied: ShoppingBagStore.instance.promoApplied,
        paymentMethod: 'Cash on Delivery',
      );
      expect(summary.promoDiscount, 0);
    });
  });

  group('watchActive switch (fake stream)', () {
    testWidgets('DynamicLayoutPage follows repository emissions', (
      tester,
    ) async {
      final repo = _SwitchableLayoutRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: DynamicLayoutPage(repository: repo, docId: 'active'),
        ),
      );
      await _pumpUntil(
        tester,
        () => find.text('Festival One').evaluate().isNotEmpty,
      );
      expect(find.text('Festival One'), findsOneWidget);

      repo.emitFestival(
        docId: 'two',
        title: 'Festival Two',
      );
      await _pumpUntil(
        tester,
        () => find.text('Festival Two').evaluate().isNotEmpty,
      );
      expect(find.text('Festival Two'), findsOneWidget);
      expect(find.text('Festival One'), findsNothing);
    });
  });
}

class _StaticFestivalRepository extends LayoutRepository {
  _StaticFestivalRepository({
    required this.docId,
    required this.title,
    required this.showAppBar,
    required this.withSearchHint,
  }) : super(firebaseReady: false);

  final String docId;
  final String title;
  final bool showAppBar;
  final bool withSearchHint;

  @override
  Stream<LayoutLoadResult> watch(String id) async* {
    yield LayoutLoadResult(
      docId: docId,
      fromCache: true,
      data: {
        'id': docId,
        'schemaVersion': 1,
        'title': title,
        'showAppBar': showAppBar,
        'root': {
          'type': 'column',
          'props': {'gap': 12},
          'children': [
            if (withSearchHint)
              {
                'type': 'search_bar',
                'props': {
                  'hint': 'Search diyas, kurtas, gifts',
                  'action': 'open_search',
                },
              },
            {
              'type': 'text',
              'props': {'value': title, 'bold': true},
            },
            {
              'type': 'product_card',
              'props': {
                'brand': 'Manyavar',
                'title': 'Silk festive kurta',
                'price': '₹799',
                'originalPrice': '₹1599',
              },
            },
          ],
        },
      },
    );
  }

  @override
  Stream<LayoutLoadResult> watchActive() => watch(docId);
}

class _UnsupportedSchemaRepository extends LayoutRepository {
  _UnsupportedSchemaRepository() : super(firebaseReady: false);

  @override
  Stream<LayoutLoadResult> watch(String docId) async* {
    yield LayoutLoadResult(
      docId: docId,
      fromCache: false,
      data: {
        'schemaVersion': LayoutRepository.supportedSchemaVersion + 5,
        'title': 'Future Screen',
        'root': {
          'type': 'column',
          'children': [
            {
              'type': 'text',
              'props': {'value': 'Should not render'},
            },
          ],
        },
      },
    );
  }

  @override
  Stream<LayoutLoadResult> watchActive() => watch('diwali');
}

class _SwitchableLayoutRepository extends LayoutRepository {
  _SwitchableLayoutRepository() : super(firebaseReady: false);

  final _controller = StreamController<LayoutLoadResult>.broadcast();
  var _started = false;

  @override
  Stream<LayoutLoadResult> watchActive() {
    if (!_started) {
      _started = true;
      scheduleMicrotask(() {
        emitFestival(docId: 'one', title: 'Festival One');
      });
    }
    return _controller.stream;
  }

  @override
  Stream<LayoutLoadResult> watch(String docId) => watchActive();

  void emitFestival({required String docId, required String title}) {
    _controller.add(
      LayoutLoadResult(
        docId: docId,
        fromCache: false,
        data: {
          'id': docId,
          'schemaVersion': 1,
          'title': title,
          // Keep app bar off so body text is the single assertion target.
          'showAppBar': false,
          'root': {
            'type': 'column',
            'children': [
              {
                'type': 'text',
                'props': {'value': title, 'bold': true},
              },
            ],
          },
        },
      ),
    );
  }
}
