import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sdui_learning/shared/data/repositories/layout_repository.dart';
import 'package:sdui_learning/shared/ui/category_listing_page.dart';
import 'package:sdui_learning/shared/ui/checkout_page.dart';
import 'package:sdui_learning/shared/ui/dynamic_layout_page.dart';
import 'package:sdui_learning/shared/ui/see_all_page.dart';

class _FirestoreLikeLayoutRepository extends LayoutRepository {
  _FirestoreLikeLayoutRepository() : super(firebaseReady: false);

  @override
  Stream<LayoutLoadResult> watch(String docId) {
    return Stream.value(
      const LayoutLoadResult(
        docId: 'diwali',
        fromCache: false,
        data: {
          'id': 'diwali',
          'title': 'Home · Diwali',
          'background': '#F7F5F0',
          'showAppBar': false,
          'root': {
            'type': 'column',
            'props': {'gap': 16, 'crossAxisAlignment': 'stretch'},
            'children': [
              {
                'type': 'row',
                'props': {'scroll': true, 'gap': 8},
                'children': [
                  {
                    'type': 'chip',
                    'props': {'label': 'Diwali', 'selected': true},
                  },
                  {
                    'type': 'chip',
                    'props': {'label': 'Gifts', 'selected': false},
                  },
                  {
                    'type': 'chip',
                    'props': {'label': 'Decor', 'selected': false},
                  },
                  {
                    'type': 'chip',
                    'props': {'label': 'Fashion', 'selected': false},
                  },
                ],
              },
              {
                'type': 'row',
                'props': {'gap': 8, 'expandChildren': true},
                'children': [
                  {
                    'type': 'container',
                    'props': {'color': '#FFFFFF', 'radius': 14, 'padding': 12},
                    'children': [
                      {
                        'type': 'text',
                        'props': {'value': 'Under\n₹499'},
                      },
                    ],
                  },
                  {
                    'type': 'container',
                    'props': {'color': '#FFFFFF', 'radius': 14, 'padding': 12},
                    'children': [
                      {
                        'type': 'text',
                        'props': {'value': 'Under\n₹999'},
                      },
                    ],
                  },
                  {
                    'type': 'container',
                    'props': {'color': '#FFFFFF', 'radius': 14, 'padding': 12},
                    'children': [
                      {
                        'type': 'text',
                        'props': {'value': 'Under\n₹1999'},
                      },
                    ],
                  },
                ],
              },
            ],
          },
        },
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUp(() {
    rootBundle.clear();
    ShoppingBagStore.instance.clear();
  });

  final layoutRepository = LayoutRepository(firebaseReady: false);

  Color? cardBgColor(WidgetTester tester, String text) {
    final textFinder = find.text(text);
    final containerFinder = find.ancestor(
      of: textFinder,
      matching: find.byType(Container),
    );
    for (final element in containerFinder.evaluate()) {
      final widget = element.widget as Container;
      final decoration = widget.decoration;
      if (decoration is BoxDecoration && decoration.color != null) {
        return decoration.color;
      }
    }
    return null;
  }

  Future<void> pumpLayout(
    WidgetTester tester,
    Widget child, {
    bool settle = true,
  }) async {
    await tester.pumpWidget(child);
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
        break;
      }
    }
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpBounded(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
  }

  testWidgets(
    'Diwali screen switches categories and selects only one price filter at a time',
    (tester) async {
      await pumpLayout(
        tester,
        MaterialApp(
          home: DynamicLayoutPage(
            repository: layoutRepository,
            docId: 'diwali',
          ),
        ),
      );

      // Initially none of the price cards are selected (white background).
      expect(cardBgColor(tester, 'Under\n₹499'), const Color(0xFFFFFFFF));
      expect(cardBgColor(tester, 'Under\n₹999'), const Color(0xFFFFFFFF));
      expect(cardBgColor(tester, 'Under\n₹1999'), const Color(0xFFFFFFFF));

      // Tap Under ₹999: ONLY Under ₹999 should be dark selected, NOT Under ₹1999.
      await tester.tap(find.text('Under\n₹999'));
      await tester.pumpAndSettle();

      expect(cardBgColor(tester, 'Under\n₹499'), const Color(0xFFFFFFFF));
      expect(cardBgColor(tester, 'Under\n₹999'), const Color(0xFF14120F));
      expect(cardBgColor(tester, 'Under\n₹1999'), const Color(0xFFFFFFFF));
      expect(find.text('Diwali picks · Under ₹999'), findsOneWidget);

      // Tap Under ₹1999: ONLY Under ₹1999 should be dark selected.
      await tester.tap(find.text('Under\n₹1999'));
      await tester.pumpAndSettle();

      expect(cardBgColor(tester, 'Under\n₹499'), const Color(0xFFFFFFFF));
      expect(cardBgColor(tester, 'Under\n₹999'), const Color(0xFFFFFFFF));
      expect(cardBgColor(tester, 'Under\n₹1999'), const Color(0xFF14120F));
      expect(find.text('Diwali picks · Under ₹1999'), findsOneWidget);

      // Tap Under ₹1999 again: toggles off.
      await tester.tap(find.text('Under\n₹1999'));
      await tester.pumpAndSettle();

      expect(cardBgColor(tester, 'Under\n₹1999'), const Color(0xFFFFFFFF));
      expect(find.text('Diwali picks'), findsOneWidget);

      // Tap Gifts chip -> switches banner and content.
      await tester.tap(find.text('Gifts'));
      await tester.pumpAndSettle();

      expect(find.text('FESTIVE GIFTS & HAMPERS'), findsOneWidget);
      expect(find.text('Gifts picks'), findsOneWidget);

      // Tap Decor chip -> switches banner and content.
      await tester.tap(find.text('Decor'));
      await tester.pumpAndSettle();

      expect(find.text('HOME & PUJA DECOR'), findsOneWidget);
      expect(find.text('Decor picks'), findsOneWidget);

      // Tap Fashion chip -> switches banner and content.
      await tester.tap(find.text('Fashion'));
      await tester.pumpAndSettle();

      expect(find.text('ETHNIC & FESTIVE WEAR'), findsOneWidget);
      expect(find.text('Fashion picks'), findsOneWidget);
    },
  );

  testWidgets(
    'Price cards without explicit price prop still select only one card when Under ₹999 is tapped',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DynamicLayoutPage(
            repository: _FirestoreLikeLayoutRepository(),
            docId: 'diwali',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Under\n₹999'));
      await tester.pumpAndSettle();

      expect(cardBgColor(tester, 'Under\n₹499'), const Color(0xFFFFFFFF));
      expect(cardBgColor(tester, 'Under\n₹999'), const Color(0xFF14120F));
      expect(cardBgColor(tester, 'Under\n₹1999'), const Color(0xFFFFFFFF));
    },
  );

  testWidgets(
    'Default Diwali screen See all links on Diwali picks and Festive gifts open SeeAllPage',
    (tester) async {
      await pumpLayout(
        tester,
        MaterialApp(
          home: DynamicLayoutPage(
            repository: layoutRepository,
            docId: 'diwali',
          ),
        ),
      );

      final seeAllLinks = find.text('See all');
      expect(seeAllLinks, findsNWidgets(2));

      // First See all -> Diwali picks
      await tester.ensureVisible(seeAllLinks.first);
      await tester.tap(seeAllLinks.first);
      await tester.pumpAndSettle();

      expect(find.byType(SeeAllPage), findsOneWidget);
      expect(find.text('Diwali picks'), findsOneWidget);
      expect(find.text('16 items'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Second See all -> Festive gifts
      await tester.ensureVisible(seeAllLinks.last);
      await tester.tap(seeAllLinks.last);
      await tester.pumpAndSettle();

      expect(find.byType(SeeAllPage), findsOneWidget);
      expect(find.text('Festive gifts'), findsOneWidget);
      expect(find.text('16 items'), findsOneWidget);
    },
  );

  testWidgets(
    'Tapping See all opens SeeAllPage with active category and price filters, bag, and sort (no search/cart AppBar icons)',
    (tester) async {
      await pumpLayout(
        tester,
        MaterialApp(
          home: DynamicLayoutPage(
            repository: layoutRepository,
            docId: 'diwali',
          ),
        ),
      );

      // Filter to Gifts + Under ₹999 before tapping See all.
      await tester.tap(find.text('Gifts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Under\n₹999'));
      await tester.pumpAndSettle();

      final seeAllFinder = find.text('See all').first;
      await tester.ensureVisible(seeAllFinder);
      await tester.tap(seeAllFinder);
      await tester.pumpAndSettle();

      expect(find.byType(SeeAllPage), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsNothing);
      expect(find.byIcon(Icons.shopping_bag_outlined), findsNothing);
      expect(find.text('Gifts picks · Under ₹999'), findsOneWidget);
      expect(find.text('4 items'), findsOneWidget);
      expect(find.text('Gold tone watch'), findsOneWidget);
      expect(find.text('Brass diya gift set'), findsNothing); // ₹1299 > 999

      // Add an item to bag and verify CTA updates.
      await tester.tap(find.text('Add to bag').first);
      await tester.pumpAndSettle();
      expect(find.text('Added (1)'), findsOneWidget);

      // Clear price filter via All Prices pill to reveal Brass diya gift set.
      await tester.tap(find.text('All Prices'));
      await tester.pumpAndSettle();
      expect(find.text('6 items'), findsOneWidget);

      // Open Sort sheet and sort by Price: Low to High.
      await tester.tap(find.text('Sort'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Price: Low to High'));
      await tester.pumpAndSettle();
      expect(find.text('Price: Low to High'), findsOneWidget);
    },
  );

  testWidgets(
    'Non-Diwali screen opens SeeAllPage with extracted SDUI product cards when See all is tapped',
    (tester) async {
      await pumpLayout(
        tester,
        MaterialApp(
          home: DynamicLayoutPage(
            repository: layoutRepository,
            docId: 'navratri',
          ),
        ),
      );

      final seeAllFinder = find.text('See all').first;
      await tester.ensureVisible(seeAllFinder);
      await tester.tap(seeAllFinder);
      await tester.pumpAndSettle();

      expect(find.byType(SeeAllPage), findsOneWidget);
      expect(find.text('Dandiya ready'), findsOneWidget);
      expect(find.text('Mirror work choli'), findsOneWidget);

      final gridScrollable = find.byType(Scrollable).last;
      await tester.scrollUntilVisible(
        find.text('Dandiya sticks'),
        250,
        scrollable: gridScrollable,
      );
      expect(find.text('Dandiya sticks'), findsOneWidget);
      expect(find.text('Kolhapuri sandals'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Batwa bag'),
        250,
        scrollable: gridScrollable,
      );
      expect(find.text('Batwa bag'), findsOneWidget);
    },
  );

  testWidgets(
    'Tapping product cards on SDUI home, SeeAllPage, and CategoryListingPage displays product details card',
    (tester) async {
      // 1. SDUI home (Diwali picks) non-apparel card opens product details card.
      await pumpLayout(
        tester,
        MaterialApp(
          home: DynamicLayoutPage(
            repository: layoutRepository,
            docId: 'diwali',
          ),
        ),
      );

      await tester.ensureVisible(find.text('Gold tone watch').first);
      await tester.tap(find.text('Gold tone watch').first);
      await tester.pumpAndSettle();

      expect(
        find.text('Fast delivery to 380015 · Easy 7-day returns'),
        findsOneWidget,
      );
      expect(find.text('Add to Bag'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      // 2. SDUI home apparel card (Fashion -> Silk festive kurta) opens details with sizes.
      await tester.ensureVisible(find.text('Fashion'));
      await tester.tap(find.text('Fashion'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Silk festive kurta').first);
      await tester.tap(find.text('Silk festive kurta').first);
      await tester.pumpAndSettle();

      expect(find.byType(CategoryListingPage), findsNothing);
      expect(find.text('Select Size'), findsOneWidget);
      expect(find.text('Add to Bag'), findsOneWidget);
      await tester.tap(find.text('Add to Bag'));
      await tester.pumpAndSettle();
      expect(
        find.text('Silk festive kurta (Size S) added to bag!'),
        findsOneWidget,
      );

      // 3. SeeAllPage product card opens details card and updates bag count.
      await tester.pumpWidget(
        const MaterialApp(home: SeeAllPage()),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Gold tone watch').first);
      await tester.tap(find.text('Gold tone watch').first);
      await tester.pumpAndSettle();

      expect(
        find.text('Fast delivery to 380015 · Easy 7-day returns'),
        findsOneWidget,
      );
      await tester.tap(find.text('Add to Bag'));
      await tester.pumpAndSettle();
      expect(find.text('Added (1)'), findsOneWidget);

      // 4. CategoryListingPage product card opens details card with size selection.
      await tester.pumpWidget(
        const MaterialApp(home: CategoryListingPage()),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Cotton straight kurta').first);
      await tester.tap(find.text('Cotton straight kurta').first);
      await tester.pumpAndSettle();

      expect(find.text('Select Size'), findsOneWidget);
      expect(
        find.text('Fast delivery to 380015 · Easy 7-day returns'),
        findsOneWidget,
      );
      await tester.tap(find.text('M'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to Bag'));
      await tester.pumpAndSettle();
      expect(
        find.text('Added Cotton straight kurta (Size M) to Bag!'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Tapping Bag opens CheckoutPage with product display, price breakdown, and dummy Place Order request',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: CategoryListingPage()),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Cotton straight kurta').first);
      await tester.tap(find.text('Cotton straight kurta').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('M'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to Bag'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bag'));
      await tester.pumpAndSettle();

      // Navigates to full CheckoutPage instead of a modal BottomSheet.
      expect(find.byType(CheckoutPage), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);

      // Product display details are visible.
      expect(find.text('Cotton straight kurta'), findsOneWidget);
      expect(find.text('Brand A'), findsOneWidget);
      expect(find.text('Size M'), findsOneWidget);
      expect(find.text('₹799'), findsWidgets);

      // Toggle PREPAID10 coupon and verify Price Breakdown updates.
      final promoSwitch = find.byType(Switch);
      await tester.scrollUntilVisible(
        promoSwitch,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(promoSwitch);
      await tester.pumpAndSettle();

      final breakdownFinder = find.text('Price Breakdown');
      await tester.scrollUntilVisible(
        breakdownFinder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(breakdownFinder, findsOneWidget);
      expect(find.text('Total MRP (1 item)'), findsOneWidget);
      expect(find.text('Discount on MRP'), findsOneWidget);
      expect(find.text('Coupon Discount (PREPAID10)'), findsOneWidget);
      expect(find.text('Delivery Fee'), findsOneWidget);
      expect(find.text('FREE'), findsOneWidget);
      expect(find.text('Total Payable'), findsOneWidget);
      expect(find.text('₹719'), findsWidgets);

      // Place order triggers dummy async request and confirmation screen.
      await tester.tap(find.text('Place Order'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Placing Order...'), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('Order Placed Successfully!'), findsOneWidget);
      expect(
        find.textContaining('Dummy Request Sent'),
        findsOneWidget,
      );
      expect(find.textContaining('/api/v1/orders'), findsOneWidget);

      final recordedOrder = ShoppingBagStore.instance.lastOrder;
      expect(recordedOrder, isNotNull);
      expect(recordedOrder!.totalPayable, 719);
      expect(recordedOrder.requestPayload['promoCode'], 'PREPAID10');
      expect(
        (recordedOrder.requestPayload['items'] as List).length,
        1,
      );

      // Continue Shopping returns to Categories with an empty bag.
      await tester.tap(find.text('Continue Shopping'));
      await tester.pumpAndSettle();
      expect(find.byType(CheckoutPage), findsNothing);
      expect(ShoppingBagStore.instance.totalQuantity, 0);
    },
  );

  testWidgets(
    'Adding product from SDUI Home (Diwali, Holi, Uttarayan, Navratri) opens CheckoutPage via Bag and places dummy order',
    (tester) async {
      await pumpLayout(
        tester,
        MaterialApp(
          home: DynamicLayoutPage(
            repository: layoutRepository,
            docId: 'diwali',
          ),
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Categories'), findsOneWidget);
      expect(find.text('Bag'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      await tester.ensureVisible(find.text('Fashion'));
      await tester.tap(find.text('Fashion'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Silk festive kurta').first);
      await tester.tap(find.text('Silk festive kurta').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add to Bag'));
      await tester.pumpAndSettle();
      expect(ShoppingBagStore.instance.totalQuantity, 1);

      await tester.tap(find.text('Bag'));
      await tester.pumpAndSettle();

      expect(find.byType(CheckoutPage), findsOneWidget);
      expect(find.text('Silk festive kurta'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Price Breakdown'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Price Breakdown'), findsOneWidget);
      expect(find.text('Place Order'), findsOneWidget);

      await tester.tap(find.text('Place Order'));
      await tester.pumpAndSettle();

      expect(find.text('Order Placed Successfully!'), findsOneWidget);
      expect(ShoppingBagStore.instance.totalQuantity, 0);
      expect(ShoppingBagStore.instance.lastOrder, isNotNull);

      await tester.tap(find.text('Continue Shopping'));
      await tester.pumpAndSettle();

      // Verify Holi renders static navbar and supports See all, details card, Bag, and Checkout.
      ShoppingBagStore.instance.clear();
      await pumpLayout(
        tester,
        MaterialApp(
          key: const ValueKey('holi_app'),
          home: DynamicLayoutPage(
            repository: layoutRepository,
            docId: 'holi',
          ),
        ),
        settle: false,
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Categories'), findsOneWidget);
      expect(find.text('Bag'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      await tester.ensureVisible(find.text('White cotton tee').first);
      await tester.tap(find.text('White cotton tee').first);
      await pumpBounded(tester);
      expect(find.text('Select Size'), findsOneWidget);
      await tester.tap(find.text('Add to Bag'));
      await pumpBounded(tester);
      expect(ShoppingBagStore.instance.totalQuantity, 1);

      final holiSeeAll = find.text('See all').first;
      await tester.ensureVisible(holiSeeAll);
      await tester.tap(holiSeeAll);
      await pumpBounded(tester);
      expect(find.byType(SeeAllPage), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SeeAllPage),
          matching: find.text('Holi must haves'),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(SeeAllPage),
          matching: find.byIcon(Icons.arrow_back),
        ),
      );
      await pumpBounded(tester);

      await tester.tap(find.text('Bag'));
      await pumpBounded(tester);
      expect(find.byType(CheckoutPage), findsOneWidget);
      expect(find.text('White cotton tee'), findsOneWidget);

      // Verify Uttarayan renders static navbar, combo_card details, SeeAllPage, and reaches Checkout.
      ShoppingBagStore.instance.clear();
      await pumpLayout(
        tester,
        MaterialApp(
          key: const ValueKey('uttarayan_app'),
          home: DynamicLayoutPage(
            repository: layoutRepository,
            docId: 'uttarayan',
          ),
        ),
        settle: false,
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Categories'), findsOneWidget);
      expect(find.text('Bag'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      await tester.ensureVisible(find.text('Starter combo').first);
      await tester.tap(find.text('Starter combo').first);
      await pumpBounded(tester);
      await tester.tap(find.text('Add to Bag'));
      await pumpBounded(tester);

      final uttarayanSeeAll = find.text('See all').first;
      await tester.ensureVisible(uttarayanSeeAll);
      await tester.tap(uttarayanSeeAll);
      await pumpBounded(tester);
      expect(find.byType(SeeAllPage), findsOneWidget);
      expect(find.text('5 items'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(SeeAllPage),
          matching: find.byIcon(Icons.arrow_back),
        ),
      );
      await pumpBounded(tester);

      await tester.tap(find.text('Bag'));
      await pumpBounded(tester);
      expect(find.byType(CheckoutPage), findsOneWidget);
      expect(find.text('Starter combo'), findsOneWidget);

      // Verify Navratri also renders the static navbar on Home.
      ShoppingBagStore.instance.clear();
      await pumpLayout(
        tester,
        MaterialApp(
          key: const ValueKey('navratri_app'),
          home: DynamicLayoutPage(
            repository: layoutRepository,
            docId: 'navratri',
          ),
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Categories'), findsOneWidget);
      expect(find.text('Bag'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    },
  );
}

