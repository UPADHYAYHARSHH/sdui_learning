import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/repositories/layout_repository.dart';
import '../sdui/layout/dynamic_layout_builder.dart';
import 'see_all_page.dart';

/// Streams a model-free layout tree from Firestore or local seed assets.
///
/// Supports interactive SDUI filtering:
/// - Category switching: Diwali, Gifts, Decor, Fashion
/// - Budget filter: Under ₹499, Under ₹999, Under ₹1999
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

  String _selectedCategory = 'Diwali';
  int? _selectedMaxPrice;

  @override
  void initState() {
    super.initState();
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
    );
  }

  void _handleAction(String action, Map<String, dynamic> data) {
    if (action == 'select_category') {
      final category = (data['category'] as String? ??
              data['label'] as String? ??
              'Diwali')
          .trim();
      setState(() {
        _selectedCategory = category;
      });
      debugPrint('[SDUI][Interaction] Switched category to: $_selectedCategory');
    } else if (action == 'filter_price') {
      final price = (data['price'] as num?)?.toInt() ??
          (data['maxPrice'] as num?)?.toInt();
      setState(() {
        if (_selectedMaxPrice == price) {
          _selectedMaxPrice = null; // Toggle off if already selected
          debugPrint('[SDUI][Interaction] Cleared price filter');
        } else {
          _selectedMaxPrice = price;
          debugPrint(
            '[SDUI][Interaction] Filtered price to under: ₹$_selectedMaxPrice',
          );
        }
      });
    } else if (action == 'see_all' || action == 'open_see_all') {
      _openSeeAll(data);
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
    final isDiwali = result != null && _isDiwaliScreen(result);

    final rawTitle = (data['sectionTitle'] as String?)?.trim();
    final categoryFromData = (data['category'] as String?)?.trim();

    if (isDiwali) {
      final rawCategory =
          (categoryFromData != null && categoryFromData.isNotEmpty)
              ? categoryFromData
              : _selectedCategory;
      final initialCategory =
          rawCategory.toLowerCase() == 'diwali' ? 'All' : rawCategory;
      final title = (rawTitle != null && rawTitle.isNotEmpty)
          ? rawTitle
          : (rawCategory.toLowerCase() == 'diwali'
              ? 'Diwali picks'
              : '$rawCategory picks');
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SeeAllPage(
            title: title,
            initialCategory: initialCategory,
            initialMaxPrice: _selectedMaxPrice,
            products: diwaliCatalogProducts,
          ),
        ),
      );
      return;
    }

    final extracted = _extractSduiProducts(result?.root);
    final products = extracted.isNotEmpty ? extracted : diwaliCatalogProducts;
    final screenTitle = result?.title.trim();
    final title = (rawTitle != null && rawTitle.isNotEmpty)
        ? rawTitle
        : (screenTitle != null && screenTitle.isNotEmpty
            ? '$screenTitle Picks'
            : 'All Picks');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SeeAllPage(
          title: title,
          initialCategory: 'All',
          products: products,
          categories: extracted.isNotEmpty
              ? const ['All']
              : const ['All', 'Gifts', 'Decor', 'Fashion'],
        ),
      ),
    );
  }

  List<SeeAllProduct> _extractSduiProducts(Map<String, dynamic>? root) {
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
          id: 'sdui_${found.length}',
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
        appBar: AppBar(title: const Text('Dynamic Layout')),
        body: Center(child: Text('$_error')),
      );
    }

    if (_result == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    _updateBuilder();

    final result = _result!;
    final showAppBar = result.data['showAppBar'] == true;
    final bg = _parseColor(result.backgroundHex) ?? const Color(0xFFF7F5F0);
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

    // Dynamically apply category and price filters to the Diwali SDUI layout tree
    final dynamicRoot = isDiwaliScreen
        ? _applyDynamicFilters(
            result.root,
            _selectedCategory,
            _selectedMaxPrice,
          )
        : result.root;

    return Scaffold(
      backgroundColor: bg,
      appBar: showAppBar
          ? AppBar(
              backgroundColor: bg,
              title: Text(result.title),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: Text(
                      result.fromCache
                          ? 'Offline · map SDUI'
                          : 'Live · map SDUI',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: const Color(0xFFE8B84B),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ),
              ],
            )
          : null,
      bottomNavigationBar: bottomNavWidget,
      body: Stack(
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
      ),
    );
  }

  // --- Dynamic Layout Filtering Engine ---

  bool _hasDiwaliFilters(Map<String, dynamic>? root) {
    if (root == null) return false;
    final raw = jsonEncode(root);
    return raw.contains('"Gifts"') &&
        raw.contains('"Decor"') &&
        raw.contains('"Fashion"');
  }

  Map<String, dynamic>? _applyDynamicFilters(
    Map<String, dynamic>? root,
    String category,
    int? maxPrice,
  ) {
    if (root == null) return null;
    final cloned = jsonDecode(jsonEncode(root)) as Map<String, dynamic>;
    final children = cloned['children'];
    if (children is! List) return cloned;

    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      if (child is! Map) continue;
      final childMap = Map<String, dynamic>.from(child);
      final type = (childMap['type'] as String? ?? '').toLowerCase();

      // 1. Header (diwali_header / festive_header)
      if (type.contains('header')) {
        final props = Map<String, dynamic>.from(childMap['props'] ?? {});
        props['searchHint'] = _searchHintFor(category);
        childMap['props'] = props;
        children[i] = childMap;
      }

      // 2. Category Chips Row (Diwali, Gifts, Decor, Fashion)
      else if (type == 'row' && _isChipsRow(childMap)) {
        final rowChildren = childMap['children'] as List?;
        if (rowChildren != null) {
          for (final chip in rowChildren) {
            if (chip is Map) {
              final chipProps = Map<String, dynamic>.from(chip['props'] ?? {});
              final label = chipProps['label']?.toString() ?? '';
              chipProps['selected'] =
                  label.toLowerCase() == category.toLowerCase();
              chipProps['action'] = 'select_category';
              chipProps['category'] = label;
              chip['props'] = chipProps;
            }
          }
        }
        children[i] = childMap;
      }

      // 3. Hero Promo Banner
      else if (type == 'container' && _isHeroBanner(childMap)) {
        children[i] = _buildHeroBanner(category);
      }

      // 4. Price filter cards row (Under ₹499, Under ₹999, Under ₹1999)
      else if (type == 'row' && _isPriceFilterRow(childMap)) {
        final rowChildren = childMap['children'] as List?;
        if (rowChildren != null) {
          for (final card in rowChildren) {
            if (card is Map) {
              final cardProps = Map<String, dynamic>.from(card['props'] ?? {});
              final price = _extractCardPrice(card);
              final isSelected = (price != null && maxPrice == price);
              cardProps['action'] = 'filter_price';
              cardProps['price'] = price;
              if (isSelected) {
                cardProps['color'] = '#14120F';
                cardProps['borderColor'] = '#E8B84B';
                cardProps['borderWidth'] = 2;
                _setCardTextColor(card, '#FFFFFF');
              } else {
                cardProps['color'] = '#FFFFFF';
                cardProps['borderColor'] = '#E8E4DA';
                cardProps['borderWidth'] = 1;
                _setCardTextColor(card, '#14120F');
              }
              card['props'] = cardProps;
            }
          }
        }
        children[i] = childMap;
      }

      // 5. Shop by category container
      else if (_isShopByCategoryContainer(childMap)) {
        children[i] = _buildShopByCategory(category);
      }

      // 6. Product sections (Picks & Grid)
      else if (type == 'column' && _isProductSection(childMap)) {
        final isGrid = _hasGridChild(childMap);
        if (!isGrid) {
          children[i] = _buildPicksSection(category, maxPrice);
        } else {
          children[i] = _buildGridSection(category, maxPrice);
        }
      }
    }

    return cloned;
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

  bool _isChipsRow(Map childMap) {
    final children = childMap['children'];
    if (children is! List || children.isEmpty) return false;
    return children.any((c) => c is Map && c['type'] == 'chip');
  }

  bool _isHeroBanner(Map childMap) {
    final props = childMap['props'];
    if (props is! Map) return false;
    final bgImage = props['bgImage']?.toString() ?? '';
    final height = (props['height'] as num?)?.toDouble() ?? 0;
    final raw = jsonEncode(childMap);
    return bgImage.contains('banner') ||
        (height >= 160 && height <= 190) ||
        raw.contains('DIWALI SALE') ||
        raw.contains('Light up the home');
  }

  Map<String, dynamic> _buildHeroBanner(String category) {
    String tag;
    String title;
    String bgImage;
    String color;

    switch (category.toLowerCase()) {
      case 'gifts':
        tag = 'FESTIVE GIFTS & HAMPERS';
        title = 'Thoughtful gifts for loved ones\nStarting ₹399';
        bgImage = 'diwali/banners/promo_gifts.jpg';
        color = '#8A331E';
        break;
      case 'decor':
        tag = 'HOME & PUJA DECOR';
        title = 'Brighten every festive corner\nUp to 50% off';
        bgImage = 'diwali/banners/promo_decor.jpg';
        color = '#A8521A';
        break;
      case 'fashion':
        tag = 'ETHNIC & FESTIVE WEAR';
        title = 'Kurtas, Sarees & Ethnic Sets\nUp to 60% off';
        bgImage = 'diwali/banners/hero.jpg';
        color = '#9A2B14';
        break;
      default:
        tag = 'DIWALI SALE';
        title = 'Light up the home\nUp to 60% off';
        bgImage = 'diwali/banners/hero.jpg';
        color = '#B4440A';
        break;
    }

    return {
      'type': 'container',
      'props': {
        'margin': {'left': 16, 'right': 16},
        'radius': 16,
        'color': color,
        'bgImage': bgImage,
        'imageDim': true,
        'fit': 'cover',
        'height': 170,
        'padding': 20,
        'alignment': 'bottomLeft',
      },
      'children': [
        {
          'type': 'column',
          'props': {
            'mainAxisAlignment': 'end',
            'crossAxisAlignment': 'start',
            'gap': 6,
          },
          'children': [
            {
              'type': 'text',
              'props': {
                'value': tag,
                'fontSize': 12,
                'bold': true,
                'color': '#FFFFFF',
              },
            },
            {
              'type': 'text',
              'props': {
                'value': title,
                'fontSize': 24,
                'bold': true,
                'height': 1.1,
                'color': '#FFFFFF',
              },
            },
          ],
        },
      ],
    };
  }

  bool _isPriceFilterRow(Map childMap) {
    final raw = jsonEncode(childMap);
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
      if (match != null) {
        return int.tryParse(match.group(0)!);
      }
    }
    final raw = jsonEncode(card).replaceAll(',', '');
    if (raw.contains('1999')) return 1999;
    if (raw.contains('999')) return 999;
    if (raw.contains('599')) return 599;
    if (raw.contains('499')) return 499;
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
    if (children is List) {
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
  }

  bool _isShopByCategoryContainer(Map childMap) {
    final raw = jsonEncode(childMap);
    return raw.contains('Shop by category') || raw.contains('by category');
  }

  Map<String, dynamic> _buildShopByCategory(String category) {
    final List<Map<String, String>> tiles;
    switch (category.toLowerCase()) {
      case 'gifts':
        tiles = [
          {'title': 'Gift sets', 'image': 'diwali/categories/gift_sets.jpg'},
          {'title': 'Jewellery', 'image': 'diwali/categories/jewellery.jpg'},
          {'title': 'Diyas', 'image': 'diwali/categories/diyas.jpg'},
          {'title': 'Watches', 'image': 'diwali/categories/gift_sets.jpg'},
        ];
        break;
      case 'decor':
        tiles = [
          {'title': 'Diyas', 'image': 'diwali/categories/diyas.jpg'},
          {'title': 'Lights', 'image': 'diwali/categories/lights.jpg'},
          {'title': 'Torans', 'image': 'diwali/categories/diyas.jpg'},
          {'title': 'Idols', 'image': 'diwali/categories/gift_sets.jpg'},
        ];
        break;
      case 'fashion':
        tiles = [
          {'title': 'Kurtas', 'image': 'diwali/categories/kurtas.jpg'},
          {'title': 'Sarees', 'image': 'diwali/categories/sarees.jpg'},
          {'title': 'Menswear', 'image': 'diwali/categories/menswear.jpg'},
          {'title': 'Kids', 'image': 'diwali/categories/kids.jpg'},
        ];
        break;
      default:
        tiles = [
          {'title': 'Kurtas', 'image': 'diwali/categories/kurtas.jpg'},
          {'title': 'Sarees', 'image': 'diwali/categories/sarees.jpg'},
          {'title': 'Diyas', 'image': 'diwali/categories/diyas.jpg'},
          {'title': 'Gift sets', 'image': 'diwali/categories/gift_sets.jpg'},
          {'title': 'Jewellery', 'image': 'diwali/categories/jewellery.jpg'},
          {'title': 'Lights', 'image': 'diwali/categories/lights.jpg'},
          {'title': 'Menswear', 'image': 'diwali/categories/menswear.jpg'},
          {'title': 'Kids', 'image': 'diwali/categories/kids.jpg'},
        ];
        break;
    }

    final sectionTitle = category.toLowerCase() == 'diwali'
        ? 'Shop by category'
        : 'Shop $category by category';

    return {
      'type': 'container',
      'props': {
        'margin': {'left': 16, 'right': 16},
        'color': '#FFFFFF',
        'radius': 14,
        'padding': 12,
      },
      'children': [
        {
          'type': 'column',
          'props': {
            'crossAxisAlignment': 'stretch',
            'gap': 10,
          },
          'children': [
            {
              'type': 'text',
              'props': {
                'value': sectionTitle,
                'fontSize': 16,
                'bold': true,
                'color': '#14120F',
              },
            },
            {
              'type': 'grid',
              'props': {
                'crossAxisCount': 4,
                'gap': 8,
                'childAspectRatio': 0.72,
              },
              'children': tiles.map((tile) {
                return {
                  'type': 'column',
                  'props': {
                    'gap': 4,
                    'crossAxisAlignment': 'center',
                    'action': 'open_category',
                  },
                  'children': [
                    {
                      'type': 'image',
                      'props': {
                        'imageUrl': tile['image'],
                        'height': 64,
                        'radius': 10,
                        'fit': 'cover',
                      },
                    },
                    {
                      'type': 'text',
                      'props': {
                        'value': tile['title'],
                        'fontSize': 12,
                        'bold': true,
                        'align': 'center',
                        'color': '#14120F',
                      },
                    },
                  ],
                };
              }).toList(),
            },
          ],
        },
      ],
    };
  }

  bool _isProductSection(Map childMap) {
    final raw = jsonEncode(childMap);
    return raw.contains('product_card') ||
        raw.contains('picks') ||
        raw.contains('gifts');
  }

  bool _hasGridChild(Map childMap) {
    final raw = jsonEncode(childMap);
    return raw.contains('"type":"grid"') || raw.contains('"type": "grid"');
  }

  List<SeeAllProduct> _getFilteredProducts(
    String category,
    int? maxPrice,
  ) {
    final cat = category.toLowerCase();
    return diwaliCatalogProducts.where((p) {
      final inCat = cat == 'diwali' || p.categories.contains(cat);
      if (!inCat) return false;
      if (maxPrice != null && p.price > maxPrice) return false;
      return true;
    }).toList();
  }

  Map<String, dynamic> _sectionHeaderRow(String title, String category) {
    return {
      'type': 'row',
      'props': {
        'mainAxisAlignment': 'spaceBetween',
        'crossAxisAlignment': 'center',
      },
      'children': [
        {
          'type': 'text',
          'props': {
            'value': title,
            'fontSize': 16,
            'bold': true,
            'color': '#14120F',
          },
        },
        {
          'type': 'text',
          'props': {
            'value': 'See all',
            'fontSize': 12,
            'bold': true,
            'color': '#5A554C',
            'action': 'see_all',
            'sectionTitle': title,
            'category': category,
          },
        },
      ],
    };
  }

  Map<String, dynamic> _productCardNode(
    SeeAllProduct item, {
    double? width,
    required double imageHeight,
  }) {
    return {
      'type': 'product_card',
      'props': {
        if (width != null) 'width': width,
        'imageHeight': imageHeight,
        'imageUrl': item.imageUrl,
        'brand': item.brand,
        'title': item.title,
        'price': '₹${item.price}',
        'originalPrice': '₹${item.originalPrice}',
        'discount': item.discount,
      },
    };
  }

  Map<String, dynamic> _buildPicksSection(String category, int? maxPrice) {
    final allMatches = _getFilteredProducts(category, maxPrice);
    final picks = allMatches.take(4).toList();

    final title = maxPrice != null
        ? '$category picks · Under ₹$maxPrice'
        : (category.toLowerCase() == 'diwali' ? 'Diwali picks' : '$category picks');

    if (picks.isEmpty) {
      return {
        'type': 'column',
        'props': {
          'padding': {'left': 16, 'right': 16},
          'gap': 8,
        },
        'children': [
          {
            'type': 'container',
            'props': {
              'color': '#FFFFFF',
              'radius': 14,
              'padding': 16,
              'alignment': 'center',
            },
            'children': [
              {
                'type': 'text',
                'props': {
                  'value': 'No $category items found under ₹$maxPrice',
                  'fontSize': 14,
                  'color': '#7A7265',
                  'align': 'center',
                },
              },
            ],
          },
        ],
      };
    }

    return {
      'type': 'column',
      'props': {
        'padding': {'left': 16, 'right': 16},
        'gap': 8,
      },
      'children': [
        _sectionHeaderRow(title, category),
        {
          'type': 'row',
          'props': {
            'scroll': true,
            'gap': 10,
          },
          'children': picks
              .map((item) => _productCardNode(item, width: 140, imageHeight: 120))
              .toList(),
        },
      ],
    };
  }

  Map<String, dynamic> _buildGridSection(String category, int? maxPrice) {
    final allMatches = _getFilteredProducts(category, maxPrice);
    // Use second half or full list for grid
    final gridItems =
        allMatches.length > 4 ? allMatches.skip(2).toList() : allMatches;

    final title = maxPrice != null
        ? 'Trending in $category · Under ₹$maxPrice'
        : (category.toLowerCase() == 'diwali'
            ? 'Festive gifts'
            : 'Trending in $category');

    if (gridItems.isEmpty) {
      return {
        'type': 'column',
        'props': {
          'padding': {'left': 16, 'right': 16},
          'gap': 8,
        },
        'children': const [],
      };
    }

    return {
      'type': 'column',
      'props': {
        'padding': {'left': 16, 'right': 16},
        'gap': 8,
      },
      'children': [
        _sectionHeaderRow(title, category),
        {
          'type': 'grid',
          'props': {
            'crossAxisCount': 2,
            'gap': 10,
            'childAspectRatio': 0.65,
          },
          'children': gridItems
              .map((item) => _productCardNode(item, imageHeight: 170))
              .toList(),
        },
      ],
    };
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
