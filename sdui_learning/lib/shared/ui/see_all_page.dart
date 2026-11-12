import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'checkout_page.dart';
import 'product_detail_sheet.dart';

/// Product model shared between the Diwali SDUI home and [SeeAllPage].
class SeeAllProduct {
  const SeeAllProduct({
    required this.id,
    required this.brand,
    required this.title,
    required this.price,
    required this.originalPrice,
    required this.discount,
    required this.imageUrl,
    this.categories = const ['diwali'],
  });

  final String id;
  final String brand;
  final String title;
  final int price;
  final int originalPrice;
  final String discount;
  final String imageUrl;
  final List<String> categories;

  int get savings => (originalPrice - price).clamp(0, originalPrice);

  /// Parses an SDUI `product_card` props map into a [SeeAllProduct].
  static SeeAllProduct? fromCardProps(
    Map<String, dynamic> props, {
    required String id,
  }) {
    final title = (props['title'] as String? ?? '').trim();
    if (title.isEmpty) return null;
    final price = _parseRupees(props['price']);
    if (price <= 0) return null;
    final parsedOriginal = _parseRupees(props['originalPrice']);
    final originalPrice = parsedOriginal > price ? parsedOriginal : price;
    var discount = (props['discount'] as String? ?? '').trim();
    if (discount.isEmpty && originalPrice > price) {
      final pct = (((originalPrice - price) * 100) / originalPrice).round();
      if (pct > 0) discount = '$pct% off';
    }
    return SeeAllProduct(
      id: id,
      brand: (props['brand'] as String? ?? 'Festive').trim(),
      title: title,
      price: price,
      originalPrice: originalPrice,
      discount: discount,
      imageUrl: (props['imageUrl'] as String? ?? '').trim(),
    );
  }

  static int _parseRupees(Object? raw) {
    if (raw is num) return raw.toInt();
    if (raw is String) {
      final cleaned = raw.replaceAll(',', '');
      final match = RegExp(r'\d+').firstMatch(cleaned);
      if (match != null) return int.tryParse(match.group(0)!) ?? 0;
    }
    return 0;
  }
}

/// Shared catalog for Diwali / Gifts / Decor / Fashion filtering and [SeeAllPage].
const List<SeeAllProduct> diwaliCatalogProducts = [
  // Gifts
  SeeAllProduct(
    id: 'g1',
    title: 'Gold tone watch',
    brand: 'Titan Festive',
    imageUrl: 'diwali/products/gold_tone_watch.jpg',
    price: 999,
    originalPrice: 1999,
    discount: '50% off',
    categories: ['gifts', 'diwali'],
  ),
  SeeAllProduct(
    id: 'g2',
    title: 'Velvet potli bag',
    brand: 'Craft Villa',
    imageUrl: 'diwali/products/potli_bag.jpg',
    price: 599,
    originalPrice: 1199,
    discount: '50% off',
    categories: ['gifts', 'fashion', 'diwali'],
  ),
  SeeAllProduct(
    id: 'g3',
    title: 'Brass diya gift set',
    brand: 'Pooja Essentials',
    imageUrl: 'diwali/products/brass_diya_set.jpg',
    price: 1299,
    originalPrice: 2599,
    discount: '50% off',
    categories: ['gifts', 'decor', 'diwali'],
  ),
  SeeAllProduct(
    id: 'g4',
    title: 'Fairy light gift pack',
    brand: 'Lumina',
    imageUrl: 'diwali/products/fairy_light_set.jpg',
    price: 399,
    originalPrice: 799,
    discount: '50% off',
    categories: ['gifts', 'decor', 'diwali'],
  ),
  SeeAllProduct(
    id: 'g5',
    title: 'Silver plated thali',
    brand: 'Royal Silver',
    imageUrl: 'diwali/categories/gift_sets.jpg',
    price: 1499,
    originalPrice: 2999,
    discount: '50% off',
    categories: ['gifts'],
  ),
  SeeAllProduct(
    id: 'g6',
    title: 'Festive dry fruit hamper',
    brand: 'Nuts & More',
    imageUrl: 'diwali/categories/jewellery.jpg',
    price: 899,
    originalPrice: 1799,
    discount: '50% off',
    categories: ['gifts'],
  ),

  // Decor
  SeeAllProduct(
    id: 'd1',
    title: 'Fairy light set',
    brand: 'Lumina',
    imageUrl: 'diwali/products/fairy_light_set.jpg',
    price: 399,
    originalPrice: 799,
    discount: '50% off',
    categories: ['decor', 'diwali'],
  ),
  SeeAllProduct(
    id: 'd2',
    title: 'Handcrafted terracotta diyas',
    brand: 'Mitti Craft',
    imageUrl: 'diwali/categories/diyas.jpg',
    price: 299,
    originalPrice: 599,
    discount: '50% off',
    categories: ['decor'],
  ),
  SeeAllProduct(
    id: 'd3',
    title: 'Brass diya set',
    brand: 'Pooja Essentials',
    imageUrl: 'diwali/products/brass_diya_set.jpg',
    price: 1299,
    originalPrice: 2599,
    discount: '50% off',
    categories: ['decor', 'diwali'],
  ),
  SeeAllProduct(
    id: 'd4',
    title: 'LED warm curtain lights',
    brand: 'Lumina',
    imageUrl: 'diwali/categories/lights.jpg',
    price: 699,
    originalPrice: 1399,
    discount: '50% off',
    categories: ['decor'],
  ),
  SeeAllProduct(
    id: 'd5',
    title: 'Decorative golden toran',
    brand: 'Festive Aura',
    imageUrl: 'diwali/categories/lights.jpg',
    price: 449,
    originalPrice: 899,
    discount: '50% off',
    categories: ['decor'],
  ),

  // Fashion
  SeeAllProduct(
    id: 'f1',
    title: 'Silk festive kurta',
    brand: 'Manyavar',
    imageUrl: 'diwali/products/silk_festive_kurta.jpg',
    price: 799,
    originalPrice: 1599,
    discount: '50% off',
    categories: ['fashion', 'diwali'],
  ),
  SeeAllProduct(
    id: 'f2',
    title: 'Embroidered kurta',
    brand: 'FabIndia',
    imageUrl: 'diwali/products/embroidered_kurta.jpg',
    price: 899,
    originalPrice: 1799,
    discount: '50% off',
    categories: ['fashion', 'diwali'],
  ),
  SeeAllProduct(
    id: 'f3',
    title: 'Nehru festive jacket',
    brand: 'Raymond',
    imageUrl: 'diwali/products/nehru_jacket.jpg',
    price: 1499,
    originalPrice: 2999,
    discount: '50% off',
    categories: ['fashion', 'diwali'],
  ),
  SeeAllProduct(
    id: 'f4',
    title: 'Chanderi festive saree',
    brand: 'Virasat',
    imageUrl: 'diwali/categories/sarees.jpg',
    price: 1699,
    originalPrice: 3399,
    discount: '50% off',
    categories: ['fashion'],
  ),
  SeeAllProduct(
    id: 'f5',
    title: 'Cotton straight kurta',
    brand: 'Anouk',
    imageUrl: 'diwali/categories/kurtas.jpg',
    price: 499,
    originalPrice: 999,
    discount: '50% off',
    categories: ['fashion'],
  ),
];

/// Full-screen "See all" product catalog with category, budget, and sort controls.
class SeeAllPage extends StatefulWidget {
  const SeeAllPage({
    super.key,
    this.title = 'All Picks',
    this.initialCategory = 'All',
    this.initialMaxPrice,
    this.products,
    this.categories = const ['All', 'Gifts', 'Decor', 'Fashion'],
  });

  final String title;
  final String initialCategory;
  final int? initialMaxPrice;
  final List<SeeAllProduct>? products;
  final List<String> categories;

  @override
  State<SeeAllPage> createState() => _SeeAllPageState();
}

class _SeeAllPageState extends State<SeeAllPage> {
  static const List<String> _sortOptions = [
    'Featured',
    'Price: Low to High',
    'Price: High to Low',
    'Best Discount',
  ];

  static const List<int?> _priceOptions = [null, 499, 999, 1999];

  late String _selectedCategory;
  int? _maxPrice;
  String _sortBy = 'Featured';
  final Map<String, int> _bagQuantities = {};

  List<SeeAllProduct> get _baseProducts =>
      widget.products ?? diwaliCatalogProducts;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.categories.isEmpty
        ? 'All'
        : _matchCategory(widget.initialCategory);
    _maxPrice = widget.initialMaxPrice;
  }

  String _matchCategory(String raw) {
    final normalized = raw.trim().toLowerCase();
    for (final cat in widget.categories) {
      if (cat.toLowerCase() == normalized) return cat;
    }
    return widget.categories.first;
  }

  List<SeeAllProduct> get _filteredProducts {
    final cat = _selectedCategory.toLowerCase();

    final list = _baseProducts.where((p) {
      if (widget.categories.isNotEmpty && cat != 'all') {
        if (!p.categories.contains(cat)) return false;
      }
      if (_maxPrice != null && p.price > _maxPrice!) return false;
      return true;
    }).toList();

    switch (_sortBy) {
      case 'Price: Low to High':
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'Price: High to Low':
        list.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'Best Discount':
        list.sort((a, b) => b.savings.compareTo(a.savings));
        break;
      default:
        break;
    }

    return list;
  }

  void _addToBag(SeeAllProduct product, {String? size}) {
    setState(() {
      _bagQuantities[product.id] = (_bagQuantities[product.id] ?? 0) + 1;
    });
    ShoppingBagStore.instance.addItem(
      CheckoutItem(
        id: 'seeall_${product.id}${size != null ? '_$size' : ''}',
        title: product.title,
        brand: product.brand,
        price: product.price,
        originalPrice: product.originalPrice,
        discount: product.discount,
        imageUrl: product.imageUrl,
        size: size,
      ),
    );
    final navigator = Navigator.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${product.title} added to bag'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'View Bag',
            onPressed: () {
              navigator.push(
                MaterialPageRoute(builder: (_) => const CheckoutPage()),
              );
            },
          ),
        ),
      );
  }

  void _resetFilters() {
    setState(() {
      _selectedCategory = widget.categories.isEmpty ? 'All' : 'All';
      _maxPrice = null;
      _sortBy = 'Featured';
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredProducts;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF14120F)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF14120F),
              ),
            ),
            Text(
              '${items.length} ${items.length == 1 ? 'item' : 'items'}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF5A554C),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildFiltersBar(),
          Expanded(
            child: items.isEmpty ? _buildEmptyState() : _buildProductGrid(items),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersBar() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.categories.length > 1)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  for (var i = 0; i < widget.categories.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    _buildCategoryChip(widget.categories[i]),
                  ],
                ],
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildSortChip(),
                const SizedBox(width: 8),
                for (final price in _priceOptions) ...[
                  _buildPriceChip(price),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String category) {
    final selected =
        _selectedCategory.toLowerCase() == category.toLowerCase();
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _selectedCategory = category),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF14120F) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.transparent : const Color(0xFFD8D2C6),
          ),
        ),
        child: Text(
          category,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF14120F),
          ),
        ),
      ),
    );
  }

  Widget _buildPriceChip(int? price) {
    final selected = _maxPrice == price;
    final label = price == null ? 'All Prices' : 'Under ₹$price';
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        setState(() {
          if (price == null) {
            _maxPrice = null;
          } else {
            _maxPrice = (_maxPrice == price) ? null : price;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF14120F) : const Color(0xFFF7F5F0),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFFE8B84B) : const Color(0xFFE2DDD2),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF14120F),
          ),
        ),
      ),
    );
  }

  Widget _buildSortChip() {
    final active = _sortBy != 'Featured';
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _showSortSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFC8321A) : const Color(0xFFF7F5F0),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? Colors.transparent : const Color(0xFFE2DDD2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.swap_vert_rounded,
              size: 16,
              color: active ? Colors.white : const Color(0xFF14120F),
            ),
            const SizedBox(width: 4),
            Text(
              active ? _sortBy : 'Sort',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : const Color(0xFF14120F),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductGrid(List<SeeAllProduct> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = (constraints.maxWidth / 210).floor().clamp(2, 5);
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.62,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => _buildProductCard(items[index]),
        );
      },
    );
  }

  Widget _buildProductCard(SeeAllProduct product) {
    final inBagCount = _bagQuantities[product.id] ?? 0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showProductDetail(product),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEBE6DC)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9E3D7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: buildProductDetailImage(product.imageUrl),
                    ),
                  ),
                ),
            const SizedBox(height: 8),
            Text(
              product.brand,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF5A554C),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              product.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF14120F),
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '₹${product.price}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF14120F),
                  ),
                ),
                if (product.originalPrice > product.price) ...[
                  const SizedBox(width: 6),
                  Text(
                    '₹${product.originalPrice}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: const Color(0xFF7A7265),
                      textStyle: const TextStyle(
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (product.discount.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                product.discount,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1B7A3A),
                ),
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 32,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: inBagCount > 0
                      ? const Color(0xFF14120F)
                      : Colors.white,
                  side: BorderSide(
                    color: inBagCount > 0
                        ? const Color(0xFF14120F)
                        : const Color(0xFFD8D2C6),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => _addToBag(product),
                child: Text(
                  inBagCount > 0 ? 'Added ($inBagCount)' : 'Add to bag',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: inBagCount > 0
                        ? Colors.white
                        : const Color(0xFF14120F),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 48,
              color: Color(0xFF9A9284),
            ),
            const SizedBox(height: 12),
            Text(
              'No items match your filters',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF14120F),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try switching category or clearing the price filter.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: const Color(0xFF5A554C),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF14120F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _resetFilters,
              child: const Text('Reset Filters'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSortSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Sort by',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF14120F),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                for (final option in _sortOptions)
                  ListTile(
                    title: Text(
                      option,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: _sortBy == option
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    trailing: _sortBy == option
                        ? const Icon(Icons.check, color: Color(0xFFC8321A))
                        : null,
                    onTap: () {
                      setState(() => _sortBy = option);
                      Navigator.of(context).pop();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showProductDetail(SeeAllProduct product) {
    final inBagCount = _bagQuantities[product.id] ?? 0;
    showProductDetailCard(
      context,
      ProductDetailData(
        title: product.title,
        brand: product.brand,
        priceText: '₹${product.price}',
        originalPriceText:
            product.originalPrice > product.price ? '₹${product.originalPrice}' : null,
        discountText: product.discount,
        imageUrl: product.imageUrl,
        sizes: inferProductSizes(product.title),
      ),
      actionLabel: inBagCount > 0 ? 'Add Another ($inBagCount in Bag)' : 'Add to Bag',
      actionColor: const Color(0xFF14120F),
      onActionPressed: (size) => _addToBag(product, size: size),
    );
  }
}
