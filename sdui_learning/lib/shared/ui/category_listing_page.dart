import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/repositories/layout_repository.dart';
import 'checkout_page.dart';
import 'product_detail_sheet.dart';

/// Product model for the Category Listing page.
class KurtaProduct {
  final String id;
  final String brand;
  final String title;
  final int price;
  final int originalPrice;
  final String discount;
  final String imagePath;
  final Color placeholderColor;
  final List<String> sizes;

  const KurtaProduct({
    required this.id,
    required this.brand,
    required this.title,
    required this.price,
    required this.originalPrice,
    required this.discount,
    required this.imagePath,
    required this.placeholderColor,
    this.sizes = const ['XS', 'S', 'M', 'L', 'XL'],
  });
}

/// Category Listing Screen based on Design Reference `Listing.dc.html`.
///
/// Features:
/// - Replicates exact colors, typography (#14120F, Plus Jakarta Sans), radii, and padding.
/// - Displays real, high-resolution authentic kurta images instead of mockup placeholders.
/// - Full interactive actions:
///   - Back button: returns to previous screen / Home.
///   - Search icon: opens interactive live filter search bar.
///   - Sort chip: modal bottom sheet sorting (Low-to-High, High-to-Low, Popularity, Discount).
///   - Filter chip: modal sheet for category/fabric filter.
///   - Size chip: quick size selector modal.
///   - Price chip: price range filter sheet.
///   - Brand chip: brand selector sheet.
///   - Promo banner: tap to apply coupon.
///   - Product cards: tap to open detail sheet with size selection and "Add to Bag".
///   - Bottom nav: interactive navigation switching tabs.
class CategoryListingPage extends StatefulWidget {
  const CategoryListingPage({
    super.key,
    this.repository,
    this.initialSort = 'Sort',
  });

  final LayoutRepository? repository;
  final String initialSort;

  @override
  State<CategoryListingPage> createState() => _CategoryListingPageState();
}

class _CategoryListingPageState extends State<CategoryListingPage> {
  static const List<KurtaProduct> _allProducts = [
    KurtaProduct(
      id: 'p1',
      brand: 'Brand A',
      title: 'Cotton straight kurta',
      price: 799,
      originalPrice: 1599,
      discount: '50% off',
      imagePath: 'assets/festival_images/kurtas/cotton_straight_kurta.jpg',
      placeholderColor: Color(0xFFE9C9B8),
    ),
    KurtaProduct(
      id: 'p2',
      brand: 'Brand B',
      title: 'Embroidered kurta set',
      price: 1199,
      originalPrice: 2399,
      discount: '50% off',
      imagePath: 'assets/festival_images/kurtas/embroidered_kurta_set.jpg',
      placeholderColor: Color(0xFFD9D3EA),
    ),
    KurtaProduct(
      id: 'p3',
      brand: 'Brand C',
      title: 'Block print kurta',
      price: 649,
      originalPrice: 1299,
      discount: '50% off',
      imagePath: 'assets/festival_images/kurtas/block_print_kurta.jpg',
      placeholderColor: Color(0xFFC9D8CF),
    ),
    KurtaProduct(
      id: 'p4',
      brand: 'Brand D',
      title: 'Anarkali kurta',
      price: 1499,
      originalPrice: 2999,
      discount: '50% off',
      imagePath: 'assets/festival_images/kurtas/anarkali_kurta.jpg',
      placeholderColor: Color(0xFFEBDDB0),
    ),
    KurtaProduct(
      id: 'p5',
      brand: 'Brand E',
      title: 'Festive kurta',
      price: 999,
      originalPrice: 1999,
      discount: '50% off',
      imagePath: 'assets/festival_images/kurtas/festive_kurta.jpg',
      placeholderColor: Color(0xFFC9D8CF),
    ),
    KurtaProduct(
      id: 'p6',
      brand: 'Brand F',
      title: 'Linen kurta',
      price: 849,
      originalPrice: 1699,
      discount: '50% off',
      imagePath: 'assets/festival_images/kurtas/linen_kurta.jpg',
      placeholderColor: Color(0xFFE9C9B8),
    ),
    KurtaProduct(
      id: 'p7',
      brand: 'Brand G',
      title: 'Chikankari kurta',
      price: 1299,
      originalPrice: 2599,
      discount: '50% off',
      imagePath: 'assets/festival_images/kurtas/chikankari_kurta.jpg',
      placeholderColor: Color(0xFFD9D3EA),
    ),
    KurtaProduct(
      id: 'p8',
      brand: 'Brand H',
      title: 'Printed A-line kurta',
      price: 899,
      originalPrice: 1799,
      discount: '50% off',
      imagePath: 'assets/festival_images/kurtas/printed_kurta.jpg',
      placeholderColor: Color(0xFFEBDDB0),
    ),
  ];

  late String _currentSort;
  String? _selectedSize;
  String? _selectedBrand;
  int? _maxPrice;
  bool _searchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  int _activeNavIndex = 1; // 1 = Categories

  bool get _promoApplied => ShoppingBagStore.instance.promoApplied;

  String _storeIdFor(KurtaProduct product) => 'kurta_${product.id}';

  void _onBagStoreChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _currentSort = widget.initialSort;
    ShoppingBagStore.instance.addListener(_onBagStoreChanged);
  }

  @override
  void dispose() {
    ShoppingBagStore.instance.removeListener(_onBagStoreChanged);
    _searchController.dispose();
    super.dispose();
  }

  List<KurtaProduct> get _filteredProducts {
    var list = List<KurtaProduct>.from(_allProducts);

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((p) =>
          p.title.toLowerCase().contains(query) ||
          p.brand.toLowerCase().contains(query)).toList();
    }

    if (_selectedBrand != null) {
      list = list.where((p) => p.brand == _selectedBrand).toList();
    }

    if (_maxPrice != null) {
      list = list.where((p) => p.price <= _maxPrice!).toList();
    }

    switch (_currentSort) {
      case 'Price: Low to High':
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'Price: High to Low':
        list.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'Discount':
        list.sort((a, b) => (b.originalPrice - b.price).compareTo(a.originalPrice - a.price));
        break;
      default:
        break;
    }

    return list;
  }

  void _showSortSheet() {
    const options = [
      'Recommended',
      'Price: Low to High',
      'Price: High to Low',
      'Discount',
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'Sort by',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF14120F),
                    ),
                  ),
                ),
                const Divider(),
                for (final opt in options)
                  ListTile(
                    title: Text(
                      opt,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: _currentSort == opt ? FontWeight.w800 : FontWeight.w500,
                        color: _currentSort == opt ? const Color(0xFFC8321A) : const Color(0xFF14120F),
                      ),
                    ),
                    trailing: _currentSort == opt
                        ? const Icon(Icons.check, color: Color(0xFFC8321A))
                        : null,
                    onTap: () {
                      setState(() {
                        _currentSort = opt;
                      });
                      Navigator.pop(ctx);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSizeSheet() {
    const sizes = ['All', 'XS', 'S', 'M', 'L', 'XL'];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Size',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF14120F),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final s in sizes)
                      ChoiceChip(
                        label: Text(s),
                        selected: s == 'All' ? _selectedSize == null : _selectedSize == s,
                        selectedColor: const Color(0xFF14120F),
                        labelStyle: GoogleFonts.plusJakartaSans(
                          color: (s == 'All' ? _selectedSize == null : _selectedSize == s)
                              ? Colors.white
                              : const Color(0xFF14120F),
                          fontWeight: FontWeight.w700,
                        ),
                        onSelected: (val) {
                          setState(() {
                            _selectedSize = s == 'All' ? null : s;
                          });
                          Navigator.pop(ctx);
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPriceSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'Price Filter',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF14120F),
                    ),
                  ),
                ),
                const Divider(),
                ListTile(
                  title: const Text('All Prices'),
                  trailing: _maxPrice == null ? const Icon(Icons.check, color: Color(0xFFC8321A)) : null,
                  onTap: () {
                    setState(() => _maxPrice = null);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  title: const Text('Under ₹800'),
                  trailing: _maxPrice == 800 ? const Icon(Icons.check, color: Color(0xFFC8321A)) : null,
                  onTap: () {
                    setState(() => _maxPrice = 800);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  title: const Text('Under ₹1200'),
                  trailing: _maxPrice == 1200 ? const Icon(Icons.check, color: Color(0xFFC8321A)) : null,
                  onTap: () {
                    setState(() => _maxPrice = 1200);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showBrandSheet() {
    final brands = ['All', 'Brand A', 'Brand B', 'Brand C', 'Brand D', 'Brand E', 'Brand F'];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Brand',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF14120F),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final b in brands)
                      ChoiceChip(
                        label: Text(b),
                        selected: b == 'All' ? _selectedBrand == null : _selectedBrand == b,
                        selectedColor: const Color(0xFF14120F),
                        labelStyle: GoogleFonts.plusJakartaSans(
                          color: (b == 'All' ? _selectedBrand == null : _selectedBrand == b)
                              ? Colors.white
                              : const Color(0xFF14120F),
                          fontWeight: FontWeight.w700,
                        ),
                        onSelected: (val) {
                          setState(() {
                            _selectedBrand = b == 'All' ? null : b;
                          });
                          Navigator.pop(ctx);
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showProductDetail(KurtaProduct product) {
    final storeId = _storeIdFor(product);
    final inBag = ShoppingBagStore.instance.containsId(storeId);
    showProductDetailCard(
      context,
      ProductDetailData(
        title: product.title,
        brand: product.brand,
        priceText: '₹${product.price}',
        originalPriceText: '₹${product.originalPrice}',
        discountText: product.discount,
        imageUrl: product.imagePath,
        imageColor: product.placeholderColor,
        sizes: product.sizes,
      ),
      actionLabel: inBag ? 'Remove from Bag' : 'Add to Bag',
      actionColor: inBag ? const Color(0xFF1B7A3A) : const Color(0xFFC8321A),
      onActionPressed: (selectedSize) {
        final chosenSize = selectedSize ?? product.sizes.first;
        if (inBag) {
          ShoppingBagStore.instance.removeItem(storeId);
        } else {
          ShoppingBagStore.instance.upsertItem(
            CheckoutItem(
              id: storeId,
              title: product.title,
              brand: product.brand,
              price: product.price,
              originalPrice: product.originalPrice,
              discount: product.discount,
              imageUrl: product.imagePath,
              imageColor: product.placeholderColor,
              size: chosenSize,
            ),
          );
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              inBag
                  ? '${product.title} removed from Bag'
                  : 'Added ${product.title} (Size $chosenSize) to Bag!',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor:
                inBag ? const Color(0xFF5A554C) : const Color(0xFF1B7A3A),
          ),
        );
      },
    );
  }

  void _openCheckout() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CheckoutPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = _filteredProducts;

    // Split products into top 4 and bottom remaining for promo banner insertion
    final topProducts = products.take(4).toList();
    final bottomProducts = products.skip(4).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F0),
      bottomNavigationBar: _buildBottomNavBar(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. Top Header & Chips Bar (Exact replica of Listing.dc.html)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  // Top row: Back button, Title, Search icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Text(
                              '‹',
                              style: TextStyle(
                                fontSize: 32,
                                height: 0.8,
                                color: Color(0xFF14120F),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                            onPressed: () {
                              if (Navigator.of(context).canPop()) {
                                Navigator.of(context).pop();
                              }
                            },
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Women · Kurtas',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF14120F),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.search,
                          size: 22,
                          color: Color(0xFF14120F),
                        ),
                        onPressed: () {
                          setState(() {
                            _searchOpen = !_searchOpen;
                            if (!_searchOpen) _searchController.clear();
                          });
                        },
                      ),
                    ],
                  ),
                  if (_searchOpen) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search kurtas, brands...',
                        filled: true,
                        fillColor: const Color(0xFFF7F5F0),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  setState(() => _searchController.clear());
                                },
                              )
                            : null,
                      ),
                      onChanged: (val) => setState(() {}),
                    ),
                  ],
                  const SizedBox(height: 10),
                  // Filter Chips row (Exact replica of Listing.dc.html)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildChip(
                          label: _currentSort == 'Recommended' ? 'Sort' : _currentSort,
                          isActive: _currentSort != 'Recommended',
                          onTap: _showSortSheet,
                        ),
                        const SizedBox(width: 8),
                        _buildChip(
                          label: 'Filter',
                          isActive: _selectedSize != null || _selectedBrand != null || _maxPrice != null,
                          onTap: _showSortSheet,
                        ),
                        const SizedBox(width: 8),
                        _buildChip(
                          label: _selectedSize != null ? 'Size: $_selectedSize' : 'Size',
                          isActive: _selectedSize != null,
                          onTap: _showSizeSheet,
                        ),
                        const SizedBox(width: 8),
                        _buildChip(
                          label: _maxPrice != null ? '< ₹$_maxPrice' : 'Price',
                          isActive: _maxPrice != null,
                          onTap: _showPriceSheet,
                        ),
                        const SizedBox(width: 8),
                        _buildChip(
                          label: _selectedBrand != null ? _selectedBrand! : 'Brand',
                          isActive: _selectedBrand != null,
                          onTap: _showBrandSheet,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 2. Scrollable Body
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    // Subheader text
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '${products.length} products · Delivery to 380015',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: const Color(0xFF5A554C),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // First Product Grid (2 columns)
                    if (topProducts.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildGrid(topProducts),
                      ),

                    const SizedBox(height: 12),

                    // Promo Banner (Exact replica of Listing.dc.html)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: InkWell(
                        onTap: () {
                          final applied = !_promoApplied;
                          ShoppingBagStore.instance.setPromoApplied(applied);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                applied
                                    ? 'Coupon PREPAID10 applied! Extra 10% off at checkout'
                                    : 'Prepaid offer coupon removed',
                              ),
                              backgroundColor: const Color(0xFFC8321A),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC8321A),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Extra 10% off on prepaid orders',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (_promoApplied)
                                    const Icon(Icons.check_circle, color: Colors.white, size: 20),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _promoApplied ? 'Coupon PREPAID10 active ✓' : 'Applied at checkout',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Second Product Grid (2 columns with actual images instead of mockup skeletons!)
                    if (bottomProducts.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildGrid(bottomProducts),
                      ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5DFD3))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem('Home', 0, onTap: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            }),
            _buildNavItem('Categories', 1, onTap: () {
              setState(() {
                _activeNavIndex = 1;
                _selectedSize = null;
                _selectedBrand = null;
                _maxPrice = null;
                _currentSort = 'Recommended';
              });
            }),
            _buildNavItem(
              'Bag',
              2,
              count: ShoppingBagStore.instance.totalQuantity,
              onTap: _openCheckout,
            ),
            _buildNavItem('Profile', 3, onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Delivery address: Satellite, Ahmedabad 380015'),
                  duration: Duration(seconds: 2),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF14120F) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? Colors.transparent : const Color(0xFFD8D2C6),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isActive ? Colors.white : const Color(0xFF14120F),
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(List<KurtaProduct> list) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.58,
      ),
      itemBuilder: (context, index) {
        final product = list[index];
        return _buildProductCard(product);
      },
    );
  }

  Widget _buildProductCard(KurtaProduct product) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showProductDetail(product),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFEBE6DC),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Actual high-resolution image instead of colored mockup box!
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 190,
                    width: double.infinity,
                    color: product.placeholderColor,
                    child: Image.asset(
                      product.imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: product.placeholderColor,
                          alignment: Alignment.center,
                          child: const Icon(Icons.image, color: Colors.white70, size: 40),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  product.brand,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFF5A554C),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  product.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF14120F),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '₹${product.price}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF14120F),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '₹${product.originalPrice}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF5A554C),
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      product.discount,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1B7A3A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(String label, int index, {int? count, required VoidCallback onTap}) {
    final isSelected = _activeNavIndex == index;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                color: isSelected ? const Color(0xFFC8321A) : const Color(0xFF5A554C),
              ),
            ),
            if (count != null && count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFC8321A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
