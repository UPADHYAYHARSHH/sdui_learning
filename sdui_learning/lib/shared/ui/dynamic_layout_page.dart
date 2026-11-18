import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/repositories/layout_repository.dart';
import '../sdui/actions/sdui_action_router.dart';
import '../sdui/layout/dynamic_layout_builder.dart';
import 'see_all_page.dart';

/// Streams a model-free layout tree from Firestore or local seed assets.
///
/// Diwali filters only mutate selected/visibility on the **server** JSON tree —
/// they never replace hero/product sections with hardcoded Dart catalogs.
class DynamicLayoutPage extends StatefulWidget {
  const DynamicLayoutPage({
    super.key,
    required this.repository,
    this.docId,
  });

  final LayoutRepository repository;
  final String? docId;

  @override
  State<DynamicLayoutPage> createState() => _DynamicLayoutPageState();
}

class _DynamicLayoutPageState extends State<DynamicLayoutPage> {
  StreamSubscription<LayoutLoadResult>? _sub;
  LayoutLoadResult? _result;
  Object? _error;
  DynamicLayoutBuilder _builder = DynamicLayoutBuilder();
  late final SduiActionRouter _actionRouter;

  String _selectedCategory = 'Diwali';
  int? _selectedMaxPrice;

  @override
  void initState() {
    super.initState();
    _actionRouter = SduiActionRouter(onPageAction: _handleAction);
    _listen();
  }

  @override
  void didUpdateWidget(covariant DynamicLayoutPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.docId != widget.docId ||
        oldWidget.repository != widget.repository) {
      _result = null;
      _error = null;
      _selectedCategory = 'Diwali';
      _selectedMaxPrice = null;
      _listen();
    }
  }

  void _listen() {
    _sub?.cancel();
    final targetDoc = widget.docId;
    final isExplicit =
        targetDoc != null && targetDoc.isNotEmpty && targetDoc != 'active';
    debugPrint(
      '[SDUI][Layout] UI subscribing to ${isExplicit ? 'screens/$targetDoc' : 'config/active (dynamic festival)'}',
    );

    final stream = isExplicit
        ? widget.repository.watch(targetDoc)
        : widget.repository.watchActive();

    _sub = stream.listen(
      (result) {
        if (!mounted) return;

        if (result.schemaUnsupported) {
          setState(() {
            _error = StateError(
              'This screen needs app schema v${result.schemaVersion}. '
              'Supported: v${LayoutRepository.supportedSchemaVersion}.',
            );
            _result = null;
          });
          return;
        }

        final root = result.root;
        if ((root == null || root.isEmpty) && _result?.root != null) {
          debugPrint(
            '[SDUI][Layout] Ignoring empty root; keeping previous layout',
          );
          return;
        }

        if (_result != null && !_result!.isMeaningfullyDifferentFrom(result)) {
          debugPrint(
            '[SDUI][Layout] No meaningful JSON change — skip rebuild',
          );
          return;
        }

        setState(() {
          _result = result;
          _updateBuilder(result.components);
          _error = null;
        });
      },
      onError: (Object e, StackTrace st) {
        debugPrint('[SDUI][Layout] UI error: $e\n$st');
        if (!mounted) return;
        if (_result != null) {
          debugPrint(
            '[SDUI][Layout] Keeping previous layout after stream error',
          );
          return;
        }
        setState(() => _error = e);
      },
    );
  }

  void _updateBuilder([Map<String, Map<String, dynamic>>? components]) {
    _builder = DynamicLayoutBuilder(
      components: components ?? _result?.components,
      onAction: _handleAction,
      actionRouter: _actionRouter,
      failUnknownVisibly: kDebugMode,
    );
  }

  void _handleAction(String action, Map<String, dynamic> data) {
    if (action == 'select_category') {
      final category =
          (data['category'] as String? ?? data['label'] as String? ?? 'Diwali')
              .trim();
      setState(() => _selectedCategory = category);
      debugPrint('[SDUI][Interaction] Switched category to: $_selectedCategory');
    } else if (action == 'filter_price') {
      final price = (data['price'] as num?)?.toInt() ??
          (data['maxPrice'] as num?)?.toInt();
      setState(() {
        if (_selectedMaxPrice == price) {
          _selectedMaxPrice = null;
        } else {
          _selectedMaxPrice = price;
        }
      });
    } else if (action == 'see_all' || action == 'open_see_all') {
      _openSeeAll(data);
    } else if (action == 'open_search') {
      _actionRouter.openSearch(context, {
        ...data,
        'searchHint': _searchHintFor(_selectedCategory),
        'products': _extractSduiProducts(
          _result?.root,
          festivalId: _result?.docId,
        ),
      });
    }
  }

  bool _isDiwaliScreen(LayoutLoadResult result) {
    final screenId =
        (result.data['id']?.toString() ?? result.docId).toLowerCase();
    return screenId == 'diwali' || _hasDiwaliFilters(result.root);
  }

  void _openSeeAll(Map<String, dynamic> data) {
    if (!mounted) return;
    final result = _result;

    final rawTitle = (data['sectionTitle'] as String?)?.trim();
    final categoryFromData = (data['category'] as String?)?.trim();
    final festivalId =
        (result?.data['id']?.toString() ?? result?.docId ?? 'diwali')
            .toLowerCase();
    final extracted =
        _extractSduiProducts(result?.root, festivalId: festivalId);
    final festivalCategories =
        _extractSduiCategories(result?.root, extracted, festivalId);

    // Active category from live state or action payload
    final rawCategory = _selectedCategory.trim().isNotEmpty
        ? _selectedCategory.trim()
        : ((categoryFromData != null && categoryFromData.isNotEmpty)
            ? categoryFromData
            : festivalId);

    final isDefaultFestCategory =
        rawCategory.toLowerCase() == festivalId ||
        rawCategory.toLowerCase() == 'all';

    final initialCategory =
        isDefaultFestCategory ? 'All' : rawCategory;

    var title = !isDefaultFestCategory
        ? '$rawCategory picks'
        : ((rawTitle != null && rawTitle.isNotEmpty)
            ? rawTitle
            : (result?.title.trim().isNotEmpty ?? false
                ? '${result!.title.trim()} Picks'
                : 'All Picks'));

    if (_selectedMaxPrice != null) {
      title = '$title · Under ₹$_selectedMaxPrice';
    }

    final themeColor = _parseColor(
      (result?.data['theme'] as Map?)?['primary']?.toString(),
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SeeAllPage(
          title: title,
          initialCategory: initialCategory,
          initialMaxPrice: _selectedMaxPrice,
          products: extracted,
          categories: festivalCategories,
          themeColor: themeColor,
        ),
      ),
    );
  }

  List<String> _extractSduiCategories(
    Map<String, dynamic>? root,
    List<SeeAllProduct> products,
    String festivalId,
  ) {
    if (festivalId == 'diwali') {
      return const ['All', 'Gifts', 'Decor', 'Fashion'];
    }

    final categoriesSet = <String>{};

    // 1. Gather all categories present on extracted festival products
    for (final p in products) {
      for (final cat in p.categories) {
        final lower = cat.toLowerCase().trim();
        if (lower.isNotEmpty &&
            lower != 'all' &&
            lower != festivalId) {
          categoriesSet.add(_capitalizeCategory(cat));
        }
      }
    }

    // 2. Scan the SDUI layout tree for category chips or action categories
    if (root != null) {
      void scan(Object? node) {
        if (node is! Map) return;
        final props = node['props'];
        if (props is Map) {
          final action = props['action']?.toString();
          if (action == 'select_category' ||
              action == 'filter_category' ||
              action == 'open_category') {
            final c = props['category']?.toString() ?? props['label']?.toString();
            if (c != null &&
                c.trim().isNotEmpty &&
                c.trim().toLowerCase() != festivalId &&
                c.trim().toLowerCase() != 'all') {
              categoriesSet.add(_capitalizeCategory(c.trim()));
            }
          }
        }
        if (node['child'] is Map) scan(node['child']);
        final children = node['children'];
        if (children is List) {
          for (final ch in children) {
            scan(ch);
          }
        }
      }

      scan(root);
    }

    if (categoriesSet.isEmpty) {
      return const ['All'];
    }

    return ['All', ...categoriesSet];
  }

  static String _capitalizeCategory(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  List<SeeAllProduct> _extractSduiProducts(
    Map<String, dynamic>? root, {
    String? festivalId,
  }) {
    if (root == null) return const [];
    final found = <SeeAllProduct>[];
    final seenTitles = <String>{};

    void visit(Object? node) {
      if (node is! Map) return;
      final type = node['type']?.toString();
      if ((type == 'product_card' || type == 'combo_card') &&
          node['props'] is Map) {
        final props = Map<String, dynamic>.from(node['props'] as Map);
        if (type == 'combo_card' &&
            (props['brand'] == null || '${props['brand']}'.trim().isEmpty)) {
          props['brand'] = 'Festive Combo';
        }
        final parsed = SeeAllProduct.fromCardProps(
          props,
          id: props['id']?.toString() ?? 'sdui_${found.length}',
          festivalId: festivalId,
        );
        if (parsed != null && seenTitles.add(parsed.title.toLowerCase())) {
          found.add(parsed);
        }
      }
      if (node['child'] is Map) visit(node['child']);
      final children = node['children'];
      if (children is List) {
        for (final child in children) {
          visit(child);
        }
      }
    }

    visit(root);
    return found;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _result == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Festival Shopping')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded, size: 40),
                const SizedBox(height: 12),
                Text(
                  '$_error',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _error = null;
                      _result = null;
                    });
                    _listen();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_result == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    _updateBuilder();

    final result = _result!;
    final showAppBar = result.data['showAppBar'] == true;
    final bg = _parseColor(result.backgroundHex) ?? const Color(0xFFF7F5F0);
    final themeColors = _themeFromJson(result.data['theme']);
    final bottomNavRaw = result.data['bottomNav'];
    final bottomNavWidget = bottomNavRaw is Map
        ? _builder.build(Map<String, dynamic>.from(bottomNavRaw))
        : (result.data['showBottomNav'] == false
            ? null
            : _builder.build(const {
                'type': 'bottom_nav',
                'props': {
                  'activeIndex': 0,
                  'items': ['Home', 'Categories', 'Bag', 'Profile'],
                },
              }));

    final canPop = Navigator.of(context).canPop();
    final isDiwaliScreen = _isDiwaliScreen(result);
    final dynamicRoot = isDiwaliScreen
        ? _applyDynamicFilters(
            result.root,
            _selectedCategory,
            _selectedMaxPrice,
          )
        : result.root;

    final statusLabel =
        result.fromCache ? 'Offline · ${result.docId}' : 'Live · ${result.docId}';

    Widget body = Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: _builder.build(dynamicRoot),
              ),
            );
          },
        ),
        if (!showAppBar)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            right: 12,
            child: IgnorePointer(
              child: _StatusChip(label: statusLabel),
            ),
          ),
        if (!showAppBar && canPop)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 12,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.black.withValues(alpha: 0.4),
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 20,
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
      ],
    );

    if (themeColors != null) {
      body = Theme(
        data: Theme.of(context).copyWith(colorScheme: themeColors),
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: showAppBar
          ? AppBar(
              backgroundColor: bg,
              title: Text(result.title),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(child: _StatusChip(label: statusLabel)),
                ),
              ],
            )
          : null,
      bottomNavigationBar: bottomNavWidget,
      body: body,
    );
  }

  // --- In-place filter (never replaces server sections) ---

  bool _hasDiwaliFilters(Map<String, dynamic>? root) {
    if (root == null) return false;
    var hasCategoryChip = false;
    var hasPriceFilter = false;
    void walk(Object? node) {
      if (node is! Map) return;
      final type = (node['type']?.toString() ?? '').toLowerCase();
      final props = node['props'];
      if (props is Map) {
        final action = (props['action']?.toString() ?? '').toLowerCase();
        if (type == 'chip' &&
            (action == 'select_category' ||
                action.isEmpty && props['label'] != null)) {
          hasCategoryChip = true;
        }
        if (action == 'filter_price' ||
            (type == 'container' && _isPriceFilterCard(node))) {
          hasPriceFilter = true;
        }
      }
      if (node['child'] is Map) walk(node['child']);
      final children = node['children'];
      if (children is List) {
        for (final child in children) {
          walk(child);
        }
      }
    }

    walk(root);
    return hasCategoryChip && hasPriceFilter;
  }

  Map<String, dynamic>? _applyDynamicFilters(
    Map<String, dynamic>? root,
    String category,
    int? maxPrice,
  ) {
    if (root == null) return null;
    final cloned = jsonDecode(jsonEncode(root)) as Map<String, dynamic>;
    _visit(cloned, (node) {
      final type = (node['type'] as String? ?? '').toLowerCase();
      final props = node['props'];
      if (props is! Map) return;
      final propsMap = Map<String, dynamic>.from(props);

      if (type.contains('header')) {
        propsMap['searchHint'] = _searchHintFor(category);
        propsMap['action'] = 'open_search';
        node['props'] = propsMap;
        return;
      }

      if (type == 'chip') {
        final label = propsMap['label']?.toString() ?? '';
        propsMap['selected'] = label.toLowerCase() == category.toLowerCase();
        propsMap['action'] = 'select_category';
        propsMap['category'] = label;
        node['props'] = propsMap;
        return;
      }

      if (type == 'container' && _isPriceFilterCard(node)) {
        final price = _extractCardPrice(node);
        final isSelected = price != null && maxPrice == price;
        propsMap['action'] = 'filter_price';
        propsMap['price'] = price;
        propsMap['color'] = isSelected ? '#14120F' : '#FFFFFF';
        propsMap['borderColor'] = isSelected ? '#E8B84B' : '#E8E4DA';
        propsMap['borderWidth'] = isSelected ? 2 : 1;
        _setCardTextColor(node, isSelected ? '#FFFFFF' : '#14120F');
        node['props'] = propsMap;
        return;
      }

      if (type == 'product_card' || type == 'combo_card') {
        final visible = _productMatches(propsMap, category, maxPrice);
        propsMap['visible'] = visible;
        node['props'] = propsMap;
        return;
      }

      if (type == 'text') {
        final value = propsMap['value']?.toString() ?? '';
        if (value == 'Diwali picks' ||
            value == 'Festive gifts' ||
            value.endsWith(' picks') ||
            value.startsWith('Trending in')) {
          final base = value.contains(' · Under')
              ? value.split(' · Under').first
              : value;
          propsMap['value'] = maxPrice != null ? '$base · Under ₹$maxPrice' : base;
          node['props'] = propsMap;
        }
      }
    });
    return cloned;
  }

  void _visit(Map<String, dynamic> node, void Function(Map<String, dynamic>) fn) {
    fn(node);
    if (node['child'] is Map) {
      final childMap = Map<String, dynamic>.from(node['child'] as Map);
      _visit(childMap, fn);
      node['child'] = childMap;
    }
    final children = node['children'];
    if (children is List) {
      for (var i = 0; i < children.length; i++) {
        final child = children[i];
        if (child is Map) {
          final map = Map<String, dynamic>.from(child);
          _visit(map, fn);
          children[i] = map;
        }
      }
    }
  }

  bool _productMatches(
    Map<String, dynamic> props,
    String category,
    int? maxPrice,
  ) {
    final cat = category.toLowerCase();
    if (cat != 'diwali' && cat != 'all') {
      final rawCats = props['categories'] ?? props['category'];
      final cats = <String>[];
      if (rawCats is List) {
        cats.addAll(rawCats.map((e) => e.toString().toLowerCase()));
      } else if (rawCats != null) {
        cats.add(rawCats.toString().toLowerCase());
      }
      if (cats.isNotEmpty && !cats.contains(cat)) return false;
    }

    if (maxPrice != null) {
      final price = _parseRupees(props['price']);
      if (price > 0 && price > maxPrice) return false;
    }
    return true;
  }

  bool _isPriceFilterCard(Map node) {
    final raw = jsonEncode(node);
    return raw.contains('Under') && raw.contains('₹');
  }

  int? _extractCardPrice(Map card) {
    final props = card['props'];
    if (props is Map && props['price'] != null) {
      return (props['price'] as num).toInt();
    }
    final text = _extractFirstText(card);
    if (text != null) {
      final cleaned = text.replaceAll(',', '');
      final match = RegExp(r'\d+').firstMatch(cleaned);
      if (match != null) return int.tryParse(match.group(0)!);
    }
    return null;
  }

  String? _extractFirstText(Map node) {
    if (node['type'] == 'text') {
      final props = node['props'];
      if (props is Map) {
        return props['value']?.toString() ?? props['text']?.toString();
      }
    }
    final children = node['children'];
    if (children is List) {
      for (final child in children) {
        if (child is Map) {
          final found = _extractFirstText(child);
          if (found != null && found.isNotEmpty) return found;
        }
      }
    }
    return null;
  }

  void _setCardTextColor(Map card, String hexColor) {
    final children = card['children'];
    if (children is! List) return;
    for (final child in children) {
      if (child is Map) {
        if (child['type'] == 'text') {
          child['props'] ??= {};
          child['props']['color'] = hexColor;
        }
        _setCardTextColor(child, hexColor);
      }
    }
  }

  String _searchHintFor(String category) {
    switch (category.toLowerCase()) {
      case 'gifts':
        return 'Search hampers, gift sets, jewellery';
      case 'decor':
        return 'Search diyas, fairy lights, torans';
      case 'fashion':
        return 'Search kurtas, sarees, ethnic wear';
      default:
        return 'Search diyas, kurtas, gifts';
    }
  }

  int _parseRupees(Object? raw) {
    if (raw is num) return raw.toInt();
    if (raw is String) {
      final cleaned = raw.replaceAll(',', '');
      final match = RegExp(r'\d+').firstMatch(cleaned);
      if (match != null) return int.tryParse(match.group(0)!) ?? 0;
    }
    return 0;
  }

  ColorScheme? _themeFromJson(Object? raw) {
    if (raw is! Map) return null;
    Color? parse(Object? v) {
      if (v is! String) return null;
      var cleaned = v.replaceFirst('#', '');
      if (cleaned.length == 6) cleaned = 'FF$cleaned';
      if (cleaned.length != 8) return null;
      final n = int.tryParse(cleaned, radix: 16);
      return n == null ? null : Color(n);
    }

    final primary = parse(raw['primary']);
    final background = parse(raw['background']);
    final surface = parse(raw['surface']);
    final onPrimary = parse(raw['onPrimary']);
    final onBackground = parse(raw['onBackground']);
    if (primary == null) return null;
    return ColorScheme.light(
      primary: primary,
      secondary: parse(raw['secondary']) ?? primary,
      surface: surface ?? background ?? Colors.white,
      onPrimary: onPrimary ?? Colors.white,
      onSurface: onBackground ?? const Color(0xFF14120F),
    );
  }

  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var cleaned = hex.replaceFirst('#', '');
    if (cleaned.length == 6) cleaned = 'FF$cleaned';
    if (cleaned.length != 8) return null;
    final parsed = int.tryParse(cleaned, radix: 16);
    if (parsed == null) return null;
    return Color(parsed);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xFFE8B84B),
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
