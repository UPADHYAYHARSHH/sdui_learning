import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../analytics/sdui_analytics.dart';
import '../../ui/category_listing_page.dart';
import '../../ui/checkout_page.dart';
import '../../ui/see_all_page.dart';

/// Routes SDUI `action` strings to app navigation / side-effects.
///
/// Unknown actions never silently open an unrelated screen — they log and
/// show a mild "Coming soon" snackbar instead.
class SduiActionRouter {
  const SduiActionRouter({this.onPageAction});

  /// Callback for page-owned interactions (filters, see-all with page state).
  final void Function(String action, Map<String, dynamic> data)? onPageAction;

  void dispatch(
    BuildContext context,
    String? action,
    Map<String, dynamic> props,
  ) {
    final normalized = (action ?? '').trim().toLowerCase();
    if (normalized.isEmpty) return;
    SduiAnalytics.action(normalized, params: {
      if (props['category'] != null) 'category': '${props['category']}',
      if (props['label'] != null) 'label': '${props['label']}',
      if (props['sectionTitle'] != null)
        'sectionTitle': '${props['sectionTitle']}',
    });

    switch (normalized) {
      case 'navigate_back':
      case 'back':
      case 'continue_shopping':
        if (onPageAction != null) {
          onPageAction!(normalized, props);
        } else if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        return;

      case 'copy_order_id':
      case 'copy':
        _copyOrderId(context, props);
        return;

      case 'see_all':
      case 'open_see_all':
        if (onPageAction != null) {
          onPageAction!('see_all', props);
        } else {
          final products = _productsFromProps(props);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SeeAllPage(
                title: (props['sectionTitle'] as String?) ?? 'All Picks',
                initialCategory: (props['category'] as String?) ?? 'All',
                products: products,
                categories: const ['All'],
              ),
            ),
          );
        }
        return;

      case 'filter_price':
      case 'select_category':
        onPageAction?.call(normalized, props);
        return;

      case 'open_category':
      case 'category_listing':
      case 'categories':
        _openCategoryListing(context, props);
        return;

      case 'open_checkout':
      case 'bag':
      case 'open_bag':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CheckoutPage()),
        );
        return;

      case 'open_profile':
      case 'profile':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile & addresses coming soon'),
            duration: Duration(seconds: 2),
          ),
        );
        return;

      case 'open_search':
      case 'toggle_search':
      case 'search':
        if (onPageAction != null) {
          onPageAction!(normalized, props);
        } else {
          openSearch(context, props);
        }
        return;

      case 'home':
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        return;

      default:
        debugPrint('[SDUI][Action] Unhandled action="$normalized" props=$props');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$action" coming soon'),
            duration: const Duration(seconds: 1),
          ),
        );
    }
  }

  void _copyOrderId(BuildContext context, Map<String, dynamic> props) {
    final text = props['orderId']?.toString() ??
        props['text']?.toString() ??
        props['value']?.toString() ??
        '';
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Order ID $text copied to clipboard'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF14120F),
      ),
    );
  }

  void _openCategoryListing(BuildContext context, Map<String, dynamic> props) {
    final category = (props['category'] as String? ??
            props['label'] as String? ??
            props['title'] as String? ??
            'Kurtas')
        .trim();
    final title = (props['sectionTitle'] as String? ?? category).trim();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryListingPage(
          title: title.isEmpty ? 'Women · Kurtas' : title,
          category: category.isEmpty ? null : category,
        ),
      ),
    );
  }

  void openSearch(BuildContext context, [Map<String, dynamic> props = const {}]) {
    _openLocalSearchSheet(context, props);
  }

  void _openLocalSearchSheet(BuildContext context, Map<String, dynamic> props) {
    final hint = (props['searchHint'] as String? ??
            props['hint'] as String? ??
            'Search products')
        .trim();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final controller = TextEditingController();
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Search',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: hint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (query) {
                  Navigator.pop(ctx);
                  final q = query.trim();
                  if (q.isEmpty) return;
                  final catalog = _productsFromProps(props);
                  final lower = q.toLowerCase();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SeeAllPage(
                        title: 'Results for "$q"',
                        initialCategory: 'All',
                        products: catalog
                            .where(
                              (p) =>
                                  p.title.toLowerCase().contains(lower) ||
                                  p.brand.toLowerCase().contains(lower),
                            )
                            .toList(),
                        categories: const ['All'],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Type a product or brand, then press search.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF5A554C),
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Products for see-all / search must come from the live SDUI tree (or empty).
  List<SeeAllProduct> _productsFromProps(Map<String, dynamic> props) {
    final raw = props['products'];
    if (raw is! List) return const [];
    return raw.whereType<SeeAllProduct>().toList(growable: false);
  }
}
