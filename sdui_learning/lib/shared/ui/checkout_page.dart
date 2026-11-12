import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'product_detail_sheet.dart';

/// Parses a rupee price label such as `'₹1,299'` into integer rupees.
int parseRupeeAmount(String? text) {
  if (text == null || text.isEmpty) return 0;
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  return int.tryParse(digits) ?? 0;
}

/// Formats integer rupees as `'₹1299'`.
String formatRupees(int amount) => '₹$amount';

/// Line item shown in the shopping bag and checkout summary.
class CheckoutItem {
  const CheckoutItem({
    required this.id,
    required this.title,
    required this.brand,
    required this.price,
    int? originalPrice,
    this.discount,
    this.imageUrl,
    this.imageColor = const Color(0xFFE9E3D7),
    this.size,
    this.subtitle,
    this.quantity = 1,
  }) : originalPrice = originalPrice ?? price;

  /// Builds a [CheckoutItem] from a shared [ProductDetailData] card payload.
  factory CheckoutItem.fromDetail(
    String id,
    ProductDetailData product, {
    String? size,
    int quantity = 1,
  }) {
    final parsedPrice = parseRupeeAmount(product.priceText);
    final parsedMrp = parseRupeeAmount(product.originalPriceText);
    return CheckoutItem(
      id: id,
      title: product.title,
      brand: product.brand,
      price: parsedPrice,
      originalPrice: parsedMrp > parsedPrice ? parsedMrp : parsedPrice,
      discount: product.discountText,
      imageUrl: product.imageUrl,
      imageColor: product.imageColor,
      size: size,
      subtitle: product.subtitle,
      quantity: quantity,
    );
  }

  final String id;
  final String title;
  final String brand;
  final int price;
  final int originalPrice;
  final String? discount;
  final String? imageUrl;
  final Color imageColor;
  final String? size;
  final String? subtitle;
  final int quantity;

  int get effectiveOriginalPrice => originalPrice > price ? originalPrice : price;
  int get lineTotal => price * quantity;
  int get lineOriginalTotal => effectiveOriginalPrice * quantity;
  int get lineDiscount => lineOriginalTotal - lineTotal;

  CheckoutItem copyWith({
    int? quantity,
    String? size,
  }) {
    return CheckoutItem(
      id: id,
      title: title,
      brand: brand,
      price: price,
      originalPrice: originalPrice,
      discount: discount,
      imageUrl: imageUrl,
      imageColor: imageColor,
      size: size ?? this.size,
      subtitle: subtitle,
      quantity: quantity ?? this.quantity,
    );
  }
}

/// Price calculation summary shared by the breakdown card and dummy API payload.
class CheckoutPriceSummary {
  const CheckoutPriceSummary({
    required this.itemCount,
    required this.totalMrp,
    required this.mrpDiscount,
    required this.subtotal,
    required this.promoDiscount,
    required this.deliveryFee,
    required this.totalPayable,
    required this.totalSavings,
  });

  factory CheckoutPriceSummary.calculate(
    List<CheckoutItem> items, {
    required bool promoApplied,
  }) {
    var itemCount = 0;
    var totalMrp = 0;
    var subtotal = 0;

    for (final item in items) {
      itemCount += item.quantity;
      totalMrp += item.lineOriginalTotal;
      subtotal += item.lineTotal;
    }

    final mrpDiscount = (totalMrp - subtotal).clamp(0, totalMrp);
    final promoDiscount =
        promoApplied && subtotal > 0 ? (subtotal * 0.10).round() : 0;
    final deliveryFee = subtotal == 0 || subtotal >= 499 ? 0 : 49;
    final totalPayable =
        (subtotal - promoDiscount + deliveryFee).clamp(0, totalMrp + deliveryFee);
    final totalSavings = mrpDiscount + promoDiscount;

    return CheckoutPriceSummary(
      itemCount: itemCount,
      totalMrp: totalMrp,
      mrpDiscount: mrpDiscount,
      subtotal: subtotal,
      promoDiscount: promoDiscount,
      deliveryFee: deliveryFee,
      totalPayable: totalPayable,
      totalSavings: totalSavings,
    );
  }

  final int itemCount;
  final int totalMrp;
  final int mrpDiscount;
  final int subtotal;
  final int promoDiscount;
  final int deliveryFee;
  final int totalPayable;
  final int totalSavings;
}

/// Simulated response returned by the dummy order placement request.
class OrderConfirmation {
  const OrderConfirmation({
    required this.orderId,
    required this.status,
    required this.createdAt,
    required this.requestPayload,
    required this.totalPayable,
    required this.itemCount,
    required this.paymentMethod,
  });

  final String orderId;
  final String status;
  final DateTime createdAt;
  final Map<String, dynamic> requestPayload;
  final int totalPayable;
  final int itemCount;
  final String paymentMethod;
}

/// Callback signature allowing callers or tests to override order submission.
typedef PlaceOrderHandler = Future<OrderConfirmation> Function(
  Map<String, dynamic> requestPayload,
);

/// Shared shopping bag store synchronized across SDUI Home, See All, Categories,
/// and the full-screen [CheckoutPage].
class ShoppingBagStore extends ChangeNotifier {
  ShoppingBagStore._();

  static final ShoppingBagStore instance = ShoppingBagStore._();

  final Map<String, CheckoutItem> _items = {};
  bool _promoApplied = false;
  OrderConfirmation? _lastOrder;

  List<CheckoutItem> get items => List.unmodifiable(_items.values);
  bool get promoApplied => _promoApplied;
  OrderConfirmation? get lastOrder => _lastOrder;

  int get totalQuantity =>
      _items.values.fold<int>(0, (sum, item) => sum + item.quantity);

  int get distinctCount => _items.length;

  bool containsId(String id) => _items.containsKey(id);

  /// Adds an item or increments its quantity if the exact key is already present.
  void addItem(CheckoutItem item) {
    final existing = _items[item.id];
    if (existing != null) {
      _items[item.id] = existing.copyWith(
        quantity: existing.quantity + item.quantity,
        size: item.size ?? existing.size,
      );
    } else {
      _items[item.id] = item;
    }
    notifyListeners();
  }

  /// Replaces an item entry directly or inserts it if absent.
  void upsertItem(CheckoutItem item) {
    _items[item.id] = item;
    notifyListeners();
  }

  /// Updates the quantity of an item; removes it when [quantity] <= 0.
  void setQuantity(String id, int quantity) {
    final existing = _items[id];
    if (existing == null) return;
    if (quantity <= 0) {
      _items.remove(id);
    } else {
      _items[id] = existing.copyWith(quantity: quantity);
    }
    notifyListeners();
  }

  /// Removes a single item by its [id].
  void removeItem(String id) {
    if (_items.remove(id) != null) {
      notifyListeners();
    }
  }

  /// Removes any items whose ids match [predicate].
  void removeWhere(bool Function(String id) predicate) {
    final before = _items.length;
    _items.removeWhere((key, _) => predicate(key));
    if (_items.length != before) {
      notifyListeners();
    }
  }

  void setPromoApplied(bool value) {
    if (_promoApplied == value) return;
    _promoApplied = value;
    notifyListeners();
  }

  void recordOrder(OrderConfirmation confirmation) {
    _lastOrder = confirmation;
    _items.clear();
    notifyListeners();
  }

  void clear() {
    if (_items.isEmpty && !_promoApplied && _lastOrder == null) return;
    _items.clear();
    _promoApplied = false;
    _lastOrder = null;
    notifyListeners();
  }

  void clearItemsOnly() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
  }
}

/// Full-screen Checkout flow displaying bag products, delivery/coupon controls,
/// itemized price breakdown, and dummy order submission.
class CheckoutPage extends StatefulWidget {
  const CheckoutPage({
    super.key,
    this.initialItems,
    this.initialPromoApplied,
    this.onPlaceOrder,
  });

  /// Optional standalone item list; when omitted, binds directly to
  /// [ShoppingBagStore.instance].
  final List<CheckoutItem>? initialItems;
  final bool? initialPromoApplied;
  final PlaceOrderHandler? onPlaceOrder;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  static const Color _bgColor = Color(0xFFF7F5F0);
  static const Color _inkColor = Color(0xFF14120F);
  static const Color _mutedColor = Color(0xFF5A554C);
  static const Color _accentColor = Color(0xFFC8321A);
  static const Color _greenColor = Color(0xFF1B7A3A);
  static const Color _borderColor = Color(0xFFE5DFD3);

  static const List<String> _paymentMethods = [
    'UPI (Instant)',
    'Credit / Debit Card',
    'Cash on Delivery',
  ];

  late List<CheckoutItem> _localItems;
  late bool _promoApplied;
  String _selectedPaymentMethod = _paymentMethods.first;
  bool _isPlacingOrder = false;
  OrderConfirmation? _completedOrder;

  bool get _usesSharedStore => widget.initialItems == null;

  List<CheckoutItem> get _items =>
      _usesSharedStore ? ShoppingBagStore.instance.items : _localItems;

  @override
  void initState() {
    super.initState();
    _localItems = List<CheckoutItem>.from(widget.initialItems ?? const []);
    if (_usesSharedStore) {
      if (widget.initialPromoApplied != null) {
        ShoppingBagStore.instance.setPromoApplied(widget.initialPromoApplied!);
      }
      _promoApplied = ShoppingBagStore.instance.promoApplied;
      ShoppingBagStore.instance.addListener(_onStoreChanged);
    } else {
      _promoApplied = widget.initialPromoApplied ?? false;
    }
  }

  @override
  void dispose() {
    if (_usesSharedStore) {
      ShoppingBagStore.instance.removeListener(_onStoreChanged);
    }
    super.dispose();
  }

  void _onStoreChanged() {
    if (!mounted) return;
    setState(() {
      _promoApplied = ShoppingBagStore.instance.promoApplied;
    });
  }

  void _updateQuantity(String id, int delta) {
    final current = _items.where((item) => item.id == id).firstOrNull;
    if (current == null) return;
    final nextQty = current.quantity + delta;
    if (_usesSharedStore) {
      ShoppingBagStore.instance.setQuantity(id, nextQty);
    } else {
      setState(() {
        final index = _localItems.indexWhere((item) => item.id == id);
        if (index == -1) return;
        if (nextQty <= 0) {
          _localItems.removeAt(index);
        } else {
          _localItems[index] = _localItems[index].copyWith(quantity: nextQty);
        }
      });
    }
  }

  void _removeItem(String id) {
    if (_usesSharedStore) {
      ShoppingBagStore.instance.removeItem(id);
    } else {
      setState(() {
        _localItems.removeWhere((item) => item.id == id);
      });
    }
  }

  void _clearBag() {
    if (_usesSharedStore) {
      ShoppingBagStore.instance.clearItemsOnly();
    } else {
      setState(() => _localItems.clear());
    }
  }

  void _togglePromo(bool value) {
    if (_usesSharedStore) {
      ShoppingBagStore.instance.setPromoApplied(value);
    } else {
      setState(() => _promoApplied = value);
    }
  }

  Map<String, dynamic> _buildDummyOrderPayload(
    List<CheckoutItem> items,
    CheckoutPriceSummary summary,
  ) {
    final timestamp = DateTime.now();
    return {
      'method': 'POST',
      'endpoint': '/api/v1/orders',
      'requestType': 'dummy_order_request',
      'requestId': 'REQ-${timestamp.millisecondsSinceEpoch}',
      'timestamp': timestamp.toIso8601String(),
      'shippingAddress': {
        'label': 'Home',
        'line': 'Satellite, Ahmedabad 380015',
      },
      'paymentMethod': _selectedPaymentMethod,
      'promoCode': _promoApplied ? 'PREPAID10' : null,
      'pricing': {
        'totalMrp': summary.totalMrp,
        'mrpDiscount': summary.mrpDiscount,
        'promoDiscount': summary.promoDiscount,
        'deliveryFee': summary.deliveryFee,
        'totalPayable': summary.totalPayable,
        'currency': 'INR',
      },
      'items': [
        for (final item in items)
          {
            'productId': item.id,
            'title': item.title,
            'brand': item.brand,
            if (item.size != null) 'size': item.size,
            'quantity': item.quantity,
            'unitPrice': item.price,
            'lineTotal': item.lineTotal,
          },
      ],
    };
  }

  Future<OrderConfirmation> _simulateDummyOrderRequest(
    Map<String, dynamic> payload,
    CheckoutPriceSummary summary,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final now = DateTime.now();
    final suffix = (now.millisecondsSinceEpoch % 900000) + 100000;
    return OrderConfirmation(
      orderId: 'ORD-$suffix',
      status: '201 Created · Dummy request accepted',
      createdAt: now,
      requestPayload: payload,
      totalPayable: summary.totalPayable,
      itemCount: summary.itemCount,
      paymentMethod: _selectedPaymentMethod,
    );
  }

  Future<void> _handlePlaceOrder() async {
    if (_isPlacingOrder || _items.isEmpty) return;

    final itemsSnapshot = List<CheckoutItem>.from(_items);
    final summary = CheckoutPriceSummary.calculate(
      itemsSnapshot,
      promoApplied: _promoApplied,
    );
    final payload = _buildDummyOrderPayload(itemsSnapshot, summary);

    setState(() => _isPlacingOrder = true);

    try {
      final confirmation = widget.onPlaceOrder != null
          ? await widget.onPlaceOrder!(payload)
          : await _simulateDummyOrderRequest(payload, summary);

      if (!mounted) return;
      if (_usesSharedStore) {
        ShoppingBagStore.instance.recordOrder(confirmation);
      } else {
        _localItems.clear();
      }
      setState(() {
        _isPlacingOrder = false;
        _completedOrder = confirmation;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isPlacingOrder = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not place order: $error'),
          backgroundColor: _accentColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final summary = CheckoutPriceSummary.calculate(
      items,
      promoApplied: _promoApplied,
    );

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _inkColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _completedOrder != null ? 'Order Confirmed' : 'Checkout',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _inkColor,
              ),
            ),
            if (_completedOrder == null && items.isNotEmpty)
              Text(
                '${summary.itemCount} ${summary.itemCount == 1 ? 'item' : 'items'} in bag',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _mutedColor,
                ),
              ),
          ],
        ),
        actions: [
          if (_completedOrder == null && items.isNotEmpty)
            TextButton(
              onPressed: _isPlacingOrder ? null : _clearBag,
              child: Text(
                'Clear',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  color: _accentColor,
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _borderColor),
        ),
      ),
      body: _completedOrder != null
          ? _buildOrderConfirmationView(_completedOrder!)
          : items.isEmpty
              ? _buildEmptyBagView()
              : _buildCheckoutBody(items, summary),
      bottomNavigationBar: _completedOrder != null
          ? _buildConfirmationBottomBar()
          : items.isNotEmpty
              ? _buildBottomOrderBar(summary)
              : null,
    );
  }

  Widget _buildEmptyBagView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3EFE6),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  size: 30,
                  color: _inkColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your bag is empty',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _inkColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Add festive picks or kurtas to see your price breakdown and place an order.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: _mutedColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _inkColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Continue Shopping',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckoutBody(
    List<CheckoutItem> items,
    CheckoutPriceSummary summary,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _buildDeliveryCard(),
        const SizedBox(height: 14),
        _buildSectionHeading('Product Display (${summary.itemCount})'),
        const SizedBox(height: 8),
        for (final item in items) ...[
          _buildProductItemCard(item),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 4),
        _buildPromoCard(),
        const SizedBox(height: 12),
        _buildPaymentMethodCard(),
        const SizedBox(height: 14),
        _buildPriceBreakdownCard(summary),
      ],
    );
  }

  Widget _buildSectionHeading(String title) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: _inkColor,
      ),
    );
  }

  Widget _buildDeliveryCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1ED),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.location_on_outlined,
              color: _accentColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delivering to Home',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _inkColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Satellite, Ahmedabad 380015 · Express 2-3 days',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: _mutedColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductItemCard(CheckoutItem item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 78,
              height: 92,
              child: buildProductDetailImage(
                item.imageUrl,
                fit: BoxFit.cover,
                fallbackColor: item.imageColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.brand,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _mutedColor,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed:
                          _isPlacingOrder ? null : () => _removeItem(item.id),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      color: _mutedColor,
                      tooltip: 'Remove item',
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _inkColor,
                  ),
                ),
                if (item.size != null ||
                    (item.subtitle != null && item.subtitle!.isNotEmpty)) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (item.size != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3EFE6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Size ${item.size}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _inkColor,
                            ),
                          ),
                        ),
                      if (item.subtitle != null && item.subtitle!.isNotEmpty)
                        Text(
                          item.subtitle!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: _mutedColor,
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            formatRupees(item.lineTotal),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: _inkColor,
                            ),
                          ),
                          if (item.effectiveOriginalPrice > item.price)
                            Text(
                              formatRupees(item.lineOriginalTotal),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: _mutedColor,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          if (item.discount != null && item.discount!.isNotEmpty)
                            Text(
                              item.discount!,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: _greenColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                    _buildQuantityStepper(item),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityStepper(CheckoutItem item) {
    return Container(
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            icon: Icons.remove,
            tooltip: 'Decrease quantity',
            onTap: _isPlacingOrder ? null : () => _updateQuantity(item.id, -1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '${item.quantity}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _inkColor,
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.add,
            tooltip: 'Increase quantity',
            onTap: _isPlacingOrder ? null : () => _updateQuantity(item.id, 1),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _promoApplied ? _greenColor : _borderColor,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.local_offer_outlined,
            size: 18,
            color: _promoApplied ? _greenColor : _accentColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Apply Coupon: PREPAID10',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _inkColor,
                  ),
                ),
                Text(
                  _promoApplied
                      ? 'Extra 10% instant discount applied'
                      : 'Save an extra 10% on your order subtotal',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: _promoApplied ? _greenColor : _mutedColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _promoApplied,
            activeTrackColor: _greenColor,
            onChanged: _isPlacingOrder ? null : _togglePromo,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Method',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: _inkColor,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final method in _paymentMethods)
                ChoiceChip(
                  label: Text(
                    method,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color:
                          _selectedPaymentMethod == method ? Colors.white : _inkColor,
                    ),
                  ),
                  selected: _selectedPaymentMethod == method,
                  selectedColor: _inkColor,
                  backgroundColor: _bgColor,
                  side: BorderSide(
                    color: _selectedPaymentMethod == method
                        ? _inkColor
                        : _borderColor,
                  ),
                  showCheckmark: false,
                  onSelected: _isPlacingOrder
                      ? null
                      : (_) => setState(() => _selectedPaymentMethod = method),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceBreakdownCard(CheckoutPriceSummary summary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Price Breakdown',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _inkColor,
            ),
          ),
          const SizedBox(height: 12),
          _PriceLine(
            label:
                'Total MRP (${summary.itemCount} ${summary.itemCount == 1 ? 'item' : 'items'})',
            value: formatRupees(summary.totalMrp),
          ),
          if (summary.mrpDiscount > 0) ...[
            const SizedBox(height: 8),
            _PriceLine(
              label: 'Discount on MRP',
              value: '-${formatRupees(summary.mrpDiscount)}',
              valueColor: _greenColor,
            ),
          ],
          if (summary.promoDiscount > 0) ...[
            const SizedBox(height: 8),
            _PriceLine(
              label: 'Coupon Discount (PREPAID10)',
              value: '-${formatRupees(summary.promoDiscount)}',
              valueColor: _greenColor,
            ),
          ],
          const SizedBox(height: 8),
          _PriceLine(
            label: 'Delivery Fee',
            value:
                summary.deliveryFee == 0 ? 'FREE' : formatRupees(summary.deliveryFee),
            valueColor: summary.deliveryFee == 0 ? _greenColor : _inkColor,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: _borderColor),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Payable',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: _inkColor,
                ),
              ),
              Text(
                formatRupees(summary.totalPayable),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: _accentColor,
                ),
              ),
            ],
          ),
          if (summary.totalSavings > 0) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF6EE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'You are saving ${formatRupees(summary.totalSavings)} on this order!',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _greenColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomOrderBar(CheckoutPriceSummary summary) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _borderColor)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatRupees(summary.totalPayable),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _inkColor,
                    ),
                  ),
                  Text(
                    summary.totalSavings > 0
                        ? 'Saving ${formatRupees(summary.totalSavings)}'
                        : 'Inclusive of all taxes',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: summary.totalSavings > 0 ? _greenColor : _mutedColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isPlacingOrder ? null : _handlePlaceOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _accentColor.withValues(alpha: 0.7),
                  disabledForegroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isPlacingOrder
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Placing Order...',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        'Place Order',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderConfirmationView(OrderConfirmation order) {
    final prettyPayload =
        const JsonEncoder.withIndent('  ').convert(order.requestPayload);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _borderColor),
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF6EE),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 38,
                  color: _greenColor,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Order Placed Successfully!',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: _inkColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Order ID: ${order.orderId}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _accentColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${order.itemCount} ${order.itemCount == 1 ? 'item' : 'items'} · Paid ${formatRupees(order.totalPayable)} via ${order.paymentMethod}',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: _mutedColor,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _bgColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.cloud_done_outlined,
                          size: 16,
                          color: _greenColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Dummy Request Sent · ${order.status}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _greenColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      prettyPayload,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: _inkColor,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmationBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _borderColor)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: _inkColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Continue Shopping',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 16,
            color: onTap == null ? const Color(0xFFAAA397) : const Color(0xFF14120F),
          ),
        ),
      ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({
    required this.label,
    required this.value,
    this.valueColor = const Color(0xFF14120F),
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: const Color(0xFF5A554C),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

