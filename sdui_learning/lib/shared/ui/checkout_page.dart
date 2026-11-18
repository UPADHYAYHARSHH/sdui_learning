import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../commerce/checkout_pricing.dart';
import '../commerce/shopping_bag_store.dart';
import '../sdui/layout/dynamic_layout_builder.dart';
import 'product_detail_sheet.dart';

export '../commerce/checkout_pricing.dart';
export '../commerce/shopping_bag_store.dart';

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
    List<CheckoutItem> items,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    final now = DateTime.now();
    final suffix = (now.millisecondsSinceEpoch % 900000) + 100000;
    final orderId = 'ORD-$suffix';
    const status = kDebugMode
        ? '201 Created · Demo order accepted'
        : 'Order confirmed';
    const deliveryAddress = 'Satellite, Ahmedabad 380015';
    const deliveryLabel = 'Home';
    const estimatedDelivery = 'Express · 2-3 Days';

    final orderItems = items
        .map(
          (item) => OrderItemInfo(
            title: item.title,
            brand: item.brand,
            price: item.price,
            lineTotal: item.lineTotal,
            quantity: item.quantity,
            size: item.size,
            imageUrl: item.imageUrl,
            imageColor: item.imageColor,
          ),
        )
        .toList();

    // Backend responds with the complete Server-Driven UI layout document
    final sduiDoc = buildOrderConfirmationSduiDocument(
      orderId: orderId,
      status: status,
      createdAt: now,
      totalPayable: summary.totalPayable,
      itemCount: summary.itemCount,
      paymentMethod: _selectedPaymentMethod,
      items: orderItems,
      deliveryAddress: deliveryAddress,
      deliveryLabel: deliveryLabel,
      estimatedDelivery: estimatedDelivery,
      requestPayload: payload,
    );

    return OrderConfirmation(
      orderId: orderId,
      status: status,
      createdAt: now,
      requestPayload: payload,
      totalPayable: summary.totalPayable,
      itemCount: summary.itemCount,
      paymentMethod: _selectedPaymentMethod,
      items: items,
      deliveryAddress: deliveryAddress,
      estimatedDelivery: estimatedDelivery,
      sduiDocument: sduiDoc,
    );
  }

  Future<void> _handlePlaceOrder() async {
    if (_isPlacingOrder || _items.isEmpty) return;

    final itemsSnapshot = List<CheckoutItem>.from(_items);
    final summary = CheckoutPriceSummary.calculate(
      itemsSnapshot,
      promoApplied: _promoApplied,
      paymentMethod: _selectedPaymentMethod,
    );
    final payload = _buildDummyOrderPayload(itemsSnapshot, summary);

    setState(() => _isPlacingOrder = true);

    try {
      final confirmation = widget.onPlaceOrder != null
          ? await widget.onPlaceOrder!(payload)
          : await _simulateDummyOrderRequest(payload, summary, itemsSnapshot);

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
      paymentMethod: _selectedPaymentMethod,
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
          ? _buildConfirmationBottomBar(_completedOrder!)
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
        _buildSectionHeading('Items (${summary.itemCount})'),
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

  bool get _isCodSelected =>
      _selectedPaymentMethod.toLowerCase().contains('cash on delivery');

  Widget _buildPromoCard() {
    final prepaidOnly = _isCodSelected;
    final switchOn = _promoApplied && !prepaidOnly;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: switchOn ? _greenColor : _borderColor,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.local_offer_outlined,
            size: 18,
            color: switchOn
                ? _greenColor
                : (prepaidOnly ? _mutedColor : _accentColor),
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
                    color: prepaidOnly ? _mutedColor : _inkColor,
                  ),
                ),
                Text(
                  prepaidOnly
                      ? 'Prepaid only — switch to UPI/Card to use PREPAID10'
                      : (switchOn
                          ? 'Extra 10% instant discount applied'
                          : 'Save an extra 10% on prepaid orders'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: switchOn ? _greenColor : _mutedColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: switchOn,
            activeTrackColor: _greenColor,
            onChanged: (_isPlacingOrder || prepaidOnly)
                ? null
                : _togglePromo,
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
                      : (_) {
                          setState(() => _selectedPaymentMethod = method);
                          // COD cannot use PREPAID10 — clear so UX matches pricing.
                          if (method.toLowerCase().contains('cash on delivery') &&
                              _promoApplied) {
                            _togglePromo(false);
                          }
                        },
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

  late final DynamicLayoutBuilder _sduiBuilder = DynamicLayoutBuilder(
    onAction: (action, props) {
      if (action == 'continue_shopping' || action == 'navigate_back') {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    },
  );

  Widget _buildOrderConfirmationView(OrderConfirmation order) {
    final sdui = order.sduiDocument ??
        buildOrderConfirmationSduiDocument(
          orderId: order.orderId,
          status: order.status,
          createdAt: order.createdAt,
          totalPayable: order.totalPayable,
          itemCount: order.itemCount,
          paymentMethod: order.paymentMethod,
          items: _getOrderItems(order),
          deliveryAddress: order.deliveryAddress,
          deliveryLabel: (order.requestPayload['shippingAddress']
                  as Map<String, dynamic>?)?['label']
              ?.toString() ??
              'Home',
          estimatedDelivery: order.estimatedDelivery,
          requestPayload: order.requestPayload,
        );

    final root = Map<String, dynamic>.from(sdui['root'] as Map);
    return SingleChildScrollView(
      child: _sduiBuilder.build(root),
    );
  }

  Widget? _buildConfirmationBottomBar(OrderConfirmation order) {
    final sdui = order.sduiDocument ??
        buildOrderConfirmationSduiDocument(
          orderId: order.orderId,
          status: order.status,
          createdAt: order.createdAt,
          totalPayable: order.totalPayable,
          itemCount: order.itemCount,
          paymentMethod: order.paymentMethod,
          items: _getOrderItems(order),
          deliveryAddress: order.deliveryAddress,
          deliveryLabel: (order.requestPayload['shippingAddress']
                  as Map<String, dynamic>?)?['label']
              ?.toString() ??
              'Home',
          estimatedDelivery: order.estimatedDelivery,
          requestPayload: order.requestPayload,
        );

    final bottomBarRaw = sdui['bottomBar'];
    if (bottomBarRaw is Map) {
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: _borderColor)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: SafeArea(
          top: false,
          child: _sduiBuilder.build(Map<String, dynamic>.from(bottomBarRaw)),
        ),
      );
    }
    return null;
  }

  List<OrderItemInfo> _getOrderItems(OrderConfirmation order) {
    if (order.items.isNotEmpty) {
      return order.items
          .map(
            (item) => OrderItemInfo(
              title: item.title,
              brand: item.brand,
              price: item.price,
              lineTotal: item.lineTotal,
              quantity: item.quantity,
              size: item.size,
              imageUrl: item.imageUrl,
              imageColor: item.imageColor,
            ),
          )
          .toList();
    }

    final rawItems = order.requestPayload['items'];
    if (rawItems is List) {
      return rawItems.map((raw) {
        final map = raw is Map ? raw : const <String, dynamic>{};
        final unitPrice = (map['unitPrice'] as num?)?.toInt() ?? 0;
        final quantity = (map['quantity'] as num?)?.toInt() ?? 1;
        final lineTotal =
            (map['lineTotal'] as num?)?.toInt() ?? (unitPrice * quantity);
        return OrderItemInfo(
          title: map['title']?.toString() ?? 'Festive item',
          brand: map['brand']?.toString() ?? '',
          size: map['size']?.toString(),
          quantity: quantity,
          price: unitPrice,
          lineTotal: lineTotal,
        );
      }).toList();
    }

    return const [];
  }
}

String _formatOrderDate(DateTime dt) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $hour:$minute $period';
}

/// Generates the canonical backend Server-Driven UI (SDUI) layout document
/// for the Order Confirmation screen.
Map<String, dynamic> buildOrderConfirmationSduiDocument({
  required String orderId,
  required String status,
  required DateTime createdAt,
  required int totalPayable,
  required int itemCount,
  required String paymentMethod,
  required List<OrderItemInfo> items,
  required String deliveryAddress,
  required String deliveryLabel,
  required String estimatedDelivery,
  required Map<String, dynamic> requestPayload,
}) {
  final prettyPayload =
      const JsonEncoder.withIndent('  ').convert(requestPayload);
  final formattedDate = _formatOrderDate(createdAt);

  final pricing = requestPayload['pricing'] as Map<String, dynamic>?;
  final totalMrp = (pricing?['totalMrp'] as num?)?.toInt();
  final mrpDiscount = (pricing?['mrpDiscount'] as num?)?.toInt() ?? 0;
  final promoDiscount = (pricing?['promoDiscount'] as num?)?.toInt() ?? 0;
  final deliveryFee = (pricing?['deliveryFee'] as num?)?.toInt() ?? 0;
  final promoCode = requestPayload['promoCode'] as String?;
  final totalSavings = mrpDiscount + promoDiscount;

  final itemsChildren = <Map<String, dynamic>>[];
  for (var i = 0; i < items.length; i++) {
    if (i > 0) {
      itemsChildren.add({
        'type': 'divider',
        'props': {'height': 1.0, 'color': '#E5DFD3'},
      });
    }
    final item = items[i];
    itemsChildren.add({
      'type': 'row',
      'props': {
        'crossAxisAlignment': 'start',
        'gap': 12.0,
      },
      'children': [
        if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
          {
            'type': 'image',
            'props': {
              'url': item.imageUrl,
              'width': 50.0,
              'height': 60.0,
              'radius': 8.0,
              'fit': 'cover',
            },
          }
        else
          {
            'type': 'container',
            'props': {
              'width': 50.0,
              'height': 60.0,
              'radius': 8.0,
              'color': '#E9E3D7',
              'alignment': 'center',
            },
            'children': [
              {
                'type': 'icon',
                'props': {
                  'name': 'shopping_bag',
                  'size': 24.0,
                  'color': '#5A554C',
                },
              },
            ],
          },
        {
          'type': 'expanded',
          'children': [
            {
              'type': 'column',
              'props': {
                'crossAxisAlignment': 'start',
                'gap': 4.0,
              },
              'children': [
                if (item.brand.isNotEmpty)
                  {
                    'type': 'text',
                    'props': {
                      'value': item.brand,
                      'fontSize': 10.0,
                      'bold': true,
                      'color': '#5A554C',
                    },
                  },
                {
                  'type': 'text',
                  'props': {
                    'value': item.title,
                    'fontSize': 13.0,
                    'bold': true,
                    'color': '#14120F',
                    'maxLines': 2,
                    'overflow': 'ellipsis',
                  },
                },
                {
                  'type': 'row',
                  'props': {
                    'gap': 8.0,
                    'crossAxisAlignment': 'center',
                  },
                  'children': [
                    if (item.size != null)
                      {
                        'type': 'container',
                        'props': {
                          'color': '#F3EFE6',
                          'radius': 4.0,
                          'padding': {
                            'left': 6,
                            'right': 6,
                            'top': 2,
                            'bottom': 2,
                          },
                        },
                        'children': [
                          {
                            'type': 'text',
                            'props': {
                              'value': 'Size ${item.size}',
                              'fontSize': 10.0,
                              'bold': true,
                              'color': '#14120F',
                            },
                          },
                        ],
                      },
                    {
                      'type': 'text',
                      'props': {
                        'value': 'Qty: ${item.quantity}',
                        'fontSize': 11.0,
                        'color': '#5A554C',
                      },
                    },
                  ],
                },
              ],
            },
          ],
        },
        {
          'type': 'text',
          'props': {
            'value': formatRupees(item.lineTotal),
            'fontSize': 13.0,
            'bold': true,
            'color': '#14120F',
          },
        },
      ],
    });
  }

  final pricingChildren = <Map<String, dynamic>>[
    {
      'type': 'row',
      'props': {
        'crossAxisAlignment': 'center',
        'gap': 10.0,
      },
      'children': [
        {
          'type': 'container',
          'props': {
            'width': 36.0,
            'height': 36.0,
            'color': '#EAF6EE',
            'radius': 10.0,
            'alignment': 'center',
          },
          'children': [
            {
              'type': 'icon',
              'props': {
                'name': 'check_outline',
                'size': 20.0,
                'color': '#1B7A3A',
              },
            },
          ],
        },
        {
          'type': 'column',
          'props': {
            'crossAxisAlignment': 'start',
            'gap': 2.0,
          },
          'children': [
            {
              'type': 'text',
              'props': {
                'value': 'Payment Summary',
                'fontSize': 13.0,
                'bold': true,
                'color': '#14120F',
              },
            },
            {
              'type': 'text',
              'props': {
                'value': 'Paid via $paymentMethod',
                'fontSize': 11.0,
                'bold': true,
                'color': '#1B7A3A',
              },
            },
          ],
        },
      ],
    },
    {
      'type': 'divider',
      'props': {'height': 1.0, 'color': '#E5DFD3'},
    },
  ];

  if (totalMrp != null && totalMrp > 0) {
    pricingChildren.addAll([
      {
        'type': 'row',
        'props': {'mainAxisAlignment': 'spaceBetween'},
        'children': [
          {
            'type': 'text',
            'props': {
              'value': 'Total MRP',
              'fontSize': 13.0,
              'color': '#5A554C',
            },
          },
          {
            'type': 'text',
            'props': {
              'value': formatRupees(totalMrp),
              'fontSize': 13.0,
              'bold': true,
              'color': '#14120F',
            },
          },
        ],
      },
      if (mrpDiscount > 0)
        {
          'type': 'row',
          'props': {'mainAxisAlignment': 'spaceBetween'},
          'children': [
            {
              'type': 'text',
              'props': {
                'value': 'Discount on MRP',
                'fontSize': 13.0,
                'color': '#5A554C',
              },
            },
            {
              'type': 'text',
              'props': {
                'value': '-${formatRupees(mrpDiscount)}',
                'fontSize': 13.0,
                'bold': true,
                'color': '#1B7A3A',
              },
            },
          ],
        },
      if (promoDiscount > 0)
        {
          'type': 'row',
          'props': {'mainAxisAlignment': 'spaceBetween'},
          'children': [
            {
              'type': 'text',
              'props': {
                'value': 'Coupon (${promoCode ?? "Promo"})',
                'fontSize': 13.0,
                'color': '#5A554C',
              },
            },
            {
              'type': 'text',
              'props': {
                'value': '-${formatRupees(promoDiscount)}',
                'fontSize': 13.0,
                'bold': true,
                'color': '#1B7A3A',
              },
            },
          ],
        },
      {
        'type': 'row',
        'props': {'mainAxisAlignment': 'spaceBetween'},
        'children': [
          {
            'type': 'text',
            'props': {
              'value': 'Delivery Fee',
              'fontSize': 13.0,
              'color': '#5A554C',
            },
          },
          {
            'type': 'text',
            'props': {
              'value': deliveryFee == 0 ? 'FREE' : formatRupees(deliveryFee),
              'fontSize': 13.0,
              'bold': true,
              'color': deliveryFee == 0 ? '#1B7A3A' : '#14120F',
            },
          },
        ],
      },
      {
        'type': 'divider',
        'props': {'height': 1.0, 'color': '#E5DFD3'},
      },
    ]);
  }

  pricingChildren.add({
    'type': 'row',
    'props': {'mainAxisAlignment': 'spaceBetween'},
    'children': [
      {
        'type': 'text',
        'props': {
          'value': 'Total Paid',
          'fontSize': 15.0,
          'bold': true,
          'color': '#14120F',
        },
      },
      {
        'type': 'text',
        'props': {
          'value': formatRupees(totalPayable),
          'fontSize': 17.0,
          'bold': true,
          'color': '#C8321A',
        },
      },
    ],
  });

  if (totalSavings > 0) {
    pricingChildren.add({
      'type': 'container',
      'props': {
        'color': '#EAF6EE',
        'radius': 10.0,
        'padding': {'left': 12, 'right': 12, 'top': 8, 'bottom': 8},
      },
      'children': [
        {
          'type': 'row',
          'props': {'gap': 8.0, 'crossAxisAlignment': 'center'},
          'children': [
            {
              'type': 'icon',
              'props': {'name': 'savings', 'size': 16.0, 'color': '#1B7A3A'},
            },
            {
              'type': 'expanded',
              'children': [
                {
                  'type': 'text',
                  'props': {
                    'value':
                        'You saved ${formatRupees(totalSavings)} on this order!',
                    'fontSize': 12.0,
                    'bold': true,
                    'color': '#1B7A3A',
                  },
                },
              ],
            },
          ],
        },
      ],
    });
  }

  return {
    'id': 'order_confirmation',
    'title': 'Order Confirmed',
    'background': '#F7F5F0',
    'showAppBar': true,
    'bottomBar': {
      'type': 'button',
      'props': {
        'label': 'Continue Shopping',
        'action': 'continue_shopping',
        'fullWidth': true,
        'backgroundColor': '#14120F',
        'textColor': '#FFFFFF',
        'radius': 12.0,
        'fontSize': 14.0,
        'bold': true,
      },
    },
    'root': {
      'type': 'column',
      'props': {
        'scroll': true,
        'gap': 14.0,
        'crossAxisAlignment': 'stretch',
        'padding': {'left': 16, 'right': 16, 'top': 16, 'bottom': 32},
      },
      'children': [
        // 1. Hero Card
        {
          'type': 'container',
          'props': {
            'color': '#FFFFFF',
            'radius': 20.0,
            'borderColor': '#E5DFD3',
            'padding': {'left': 20, 'right': 20, 'top': 20, 'bottom': 20},
          },
          'children': [
            {
              'type': 'column',
              'props': {'gap': 10.0, 'crossAxisAlignment': 'center'},
              'children': [
                {
                  'type': 'container',
                  'props': {
                    'width': 64.0,
                    'height': 64.0,
                    'color': '#EAF6EE',
                    'shape': 'circle',
                    'borderColor': '#1B7A3A',
                    'alignment': 'center',
                  },
                  'children': [
                    {
                      'type': 'icon',
                      'props': {
                        'name': 'check_circle',
                        'size': 38.0,
                        'color': '#1B7A3A',
                      },
                    },
                  ],
                },
                {
                  'type': 'text',
                  'props': {
                    'value': 'Order Placed Successfully!',
                    'fontSize': 20.0,
                    'bold': true,
                    'color': '#14120F',
                    'align': 'center',
                  },
                },
                {
                  'type': 'text',
                  'props': {
                    'value':
                        'Thank you for your order! We are preparing your items for delivery.',
                    'fontSize': 13.0,
                    'color': '#5A554C',
                    'align': 'center',
                  },
                },
                {
                  'type': 'container',
                  'props': {
                    'color': '#F7F5F0',
                    'radius': 10.0,
                    'borderColor': '#E5DFD3',
                    'padding': {
                      'left': 14,
                      'right': 14,
                      'top': 8,
                      'bottom': 8,
                    },
                    'action': 'copy_order_id',
                    'orderId': orderId,
                  },
                  'children': [
                    {
                      'type': 'row',
                      'props': {'gap': 8.0, 'crossAxisAlignment': 'center'},
                      'children': [
                        {
                          'type': 'text',
                          'props': {
                            'value': 'Order ID: ',
                            'fontSize': 12.0,
                            'color': '#5A554C',
                          },
                        },
                        {
                          'type': 'text',
                          'props': {
                            'value': orderId,
                            'fontSize': 13.0,
                            'bold': true,
                            'color': '#C8321A',
                          },
                        },
                        {
                          'type': 'icon',
                          'props': {
                            'name': 'copy',
                            'size': 14.0,
                            'color': '#5A554C',
                          },
                        },
                      ],
                    },
                  ],
                },
                {
                  'type': 'text',
                  'props': {
                    'value': 'Placed on $formattedDate',
                    'fontSize': 11.0,
                    'color': '#5A554C',
                    'align': 'center',
                  },
                },
              ],
            },
          ],
        },

        // 2. Delivery Details Card
        {
          'type': 'container',
          'props': {
            'color': '#FFFFFF',
            'radius': 16.0,
            'borderColor': '#E5DFD3',
            'padding': {'left': 16, 'right': 16, 'top': 16, 'bottom': 16},
          },
          'children': [
            {
              'type': 'column',
              'props': {'gap': 12.0, 'crossAxisAlignment': 'stretch'},
              'children': [
                {
                  'type': 'row',
                  'props': {'gap': 10.0, 'crossAxisAlignment': 'center'},
                  'children': [
                    {
                      'type': 'container',
                      'props': {
                        'width': 36.0,
                        'height': 36.0,
                        'color': '#FFF1ED',
                        'radius': 10.0,
                        'alignment': 'center',
                      },
                      'children': [
                        {
                          'type': 'icon',
                          'props': {
                            'name': 'local_shipping',
                            'size': 20.0,
                            'color': '#C8321A',
                          },
                        },
                      ],
                    },
                    {
                      'type': 'column',
                      'props': {'gap': 2.0, 'crossAxisAlignment': 'start'},
                      'children': [
                        {
                          'type': 'text',
                          'props': {
                            'value': 'Delivery Details',
                            'fontSize': 13.0,
                            'bold': true,
                            'color': '#14120F',
                          },
                        },
                        {
                          'type': 'text',
                          'props': {
                            'value': estimatedDelivery,
                            'fontSize': 11.0,
                            'bold': true,
                            'color': '#1B7A3A',
                          },
                        },
                      ],
                    },
                  ],
                },
                {
                  'type': 'container',
                  'props': {
                    'color': '#F7F5F0',
                    'radius': 12.0,
                    'borderColor': '#E5DFD3',
                    'padding': {
                      'left': 12,
                      'right': 12,
                      'top': 12,
                      'bottom': 12,
                    },
                  },
                  'children': [
                    {
                      'type': 'row',
                      'props': {'gap': 8.0, 'crossAxisAlignment': 'start'},
                      'children': [
                        {
                          'type': 'icon',
                          'props': {
                            'name': 'location_on',
                            'size': 16.0,
                            'color': '#5A554C',
                          },
                        },
                        {
                          'type': 'column',
                          'props': {'gap': 2.0, 'crossAxisAlignment': 'start'},
                          'children': [
                            {
                              'type': 'text',
                              'props': {
                                'value': 'Delivering to $deliveryLabel',
                                'fontSize': 12.0,
                                'bold': true,
                                'color': '#14120F',
                              },
                            },
                            {
                              'type': 'text',
                              'props': {
                                'value': deliveryAddress,
                                'fontSize': 12.0,
                                'color': '#5A554C',
                              },
                            },
                          ],
                        },
                      ],
                    },
                  ],
                },
                // Tracker Progress
                {
                  'type': 'row',
                  'props': {'crossAxisAlignment': 'center'},
                  'children': [
                    {
                      'type': 'column',
                      'props': {'crossAxisAlignment': 'center', 'gap': 4.0},
                      'children': [
                        {
                          'type': 'container',
                          'props': {
                            'width': 24.0,
                            'height': 24.0,
                            'color': '#1B7A3A',
                            'shape': 'circle',
                            'alignment': 'center',
                          },
                          'children': [
                            {
                              'type': 'icon',
                              'props': {
                                'name': 'check',
                                'size': 14.0,
                                'color': '#FFFFFF',
                              },
                            },
                          ],
                        },
                        {
                          'type': 'text',
                          'props': {
                            'value': 'Confirmed',
                            'fontSize': 11.0,
                            'bold': true,
                            'color': '#14120F',
                          },
                        },
                        {
                          'type': 'text',
                          'props': {
                            'value': 'Order Placed',
                            'fontSize': 9.0,
                            'bold': true,
                            'color': '#1B7A3A',
                          },
                        },
                      ],
                    },
                    {
                      'type': 'expanded',
                      'children': [
                        {
                          'type': 'container',
                          'props': {'height': 2.0, 'color': '#1B7A3A'},
                        },
                      ],
                    },
                    {
                      'type': 'column',
                      'props': {'crossAxisAlignment': 'center', 'gap': 4.0},
                      'children': [
                        {
                          'type': 'container',
                          'props': {
                            'width': 24.0,
                            'height': 24.0,
                            'color': '#FFF1ED',
                            'shape': 'circle',
                            'borderColor': '#C8321A',
                            'borderWidth': 2.0,
                            'alignment': 'center',
                          },
                          'children': [
                            {
                              'type': 'container',
                              'props': {
                                'width': 8.0,
                                'height': 8.0,
                                'color': '#C8321A',
                                'shape': 'circle',
                              },
                            },
                          ],
                        },
                        {
                          'type': 'text',
                          'props': {
                            'value': 'Preparing',
                            'fontSize': 11.0,
                            'bold': true,
                            'color': '#14120F',
                          },
                        },
                        {
                          'type': 'text',
                          'props': {
                            'value': 'Packing',
                            'fontSize': 9.0,
                            'bold': true,
                            'color': '#C8321A',
                          },
                        },
                      ],
                    },
                    {
                      'type': 'expanded',
                      'children': [
                        {
                          'type': 'container',
                          'props': {'height': 2.0, 'color': '#E5DFD3'},
                        },
                      ],
                    },
                    {
                      'type': 'column',
                      'props': {'crossAxisAlignment': 'center', 'gap': 4.0},
                      'children': [
                        {
                          'type': 'container',
                          'props': {
                            'width': 24.0,
                            'height': 24.0,
                            'color': '#F7F5F0',
                            'shape': 'circle',
                            'borderColor': '#E5DFD3',
                            'borderWidth': 2.0,
                          },
                        },
                        {
                          'type': 'text',
                          'props': {
                            'value': 'Delivered',
                            'fontSize': 11.0,
                            'color': '#5A554C',
                          },
                        },
                        {
                          'type': 'text',
                          'props': {
                            'value': '2-3 Days',
                            'fontSize': 9.0,
                            'color': '#5A554C',
                          },
                        },
                      ],
                    },
                  ],
                },
              ],
            },
          ],
        },

        // 3. Items Ordered Card
        {
          'type': 'container',
          'props': {
            'color': '#FFFFFF',
            'radius': 16.0,
            'borderColor': '#E5DFD3',
            'padding': {'left': 16, 'right': 16, 'top': 16, 'bottom': 16},
          },
          'children': [
            {
              'type': 'column',
              'props': {'gap': 12.0, 'crossAxisAlignment': 'stretch'},
              'children': [
                {
                  'type': 'row',
                  'props': {
                    'mainAxisAlignment': 'spaceBetween',
                    'crossAxisAlignment': 'center',
                  },
                  'children': [
                    {
                      'type': 'text',
                      'props': {
                        'value': 'Items in this Order',
                        'fontSize': 13.0,
                        'bold': true,
                        'color': '#14120F',
                      },
                    },
                    {
                      'type': 'container',
                      'props': {
                        'color': '#F3EFE6',
                        'radius': 6.0,
                        'padding': {
                          'left': 8,
                          'right': 8,
                          'top': 2,
                          'bottom': 2,
                        },
                      },
                      'children': [
                        {
                          'type': 'text',
                          'props': {
                            'value':
                                '$itemCount ${itemCount == 1 ? "item" : "items"}',
                            'fontSize': 11.0,
                            'bold': true,
                            'color': '#14120F',
                          },
                        },
                      ],
                    },
                  ],
                },
                ...itemsChildren,
              ],
            },
          ],
        },

        // 4. Payment & Price Summary
        {
          'type': 'container',
          'props': {
            'color': '#FFFFFF',
            'radius': 16.0,
            'borderColor': '#E5DFD3',
            'padding': {'left': 16, 'right': 16, 'top': 16, 'bottom': 16},
          },
          'children': [
            {
              'type': 'column',
              'props': {'gap': 10.0, 'crossAxisAlignment': 'stretch'},
              'children': pricingChildren,
            },
          ],
        },

        // 5. Order Updates
        {
          'type': 'container',
          'props': {
            'color': '#FFFFFF',
            'radius': 16.0,
            'borderColor': '#E5DFD3',
            'padding': {'left': 14, 'right': 14, 'top': 14, 'bottom': 14},
          },
          'children': [
            {
              'type': 'row',
              'props': {'gap': 12.0, 'crossAxisAlignment': 'center'},
              'children': [
                {
                  'type': 'container',
                  'props': {
                    'width': 36.0,
                    'height': 36.0,
                    'color': '#F3EFE6',
                    'radius': 10.0,
                    'alignment': 'center',
                  },
                  'children': [
                    {
                      'type': 'icon',
                      'props': {
                        'name': 'email',
                        'size': 20.0,
                        'color': '#14120F',
                      },
                    },
                  ],
                },
                {
                  'type': 'column',
                  'props': {'gap': 2.0, 'crossAxisAlignment': 'start'},
                  'children': [
                    {
                      'type': 'text',
                      'props': {
                        'value': 'Order Updates',
                        'fontSize': 12.0,
                        'bold': true,
                        'color': '#14120F',
                      },
                    },
                    {
                      'type': 'text',
                      'props': {
                        'value':
                            'You will receive order updates on SMS & WhatsApp.',
                        'fontSize': 11.0,
                        'color': '#5A554C',
                      },
                    },
                  ],
                },
              ],
            },
          ],
        },

        if (kDebugMode)
          {
            'type': 'expansion_tile',
            'props': {
              'title': 'View API Request Details',
              'subtitle': 'Debug only · $status · /api/v1/orders',
              'icon': 'terminal',
              'initiallyExpanded': false,
            },
            'children': [
              {
                'type': 'container',
                'props': {
                  'color': '#F7F5F0',
                  'radius': 10.0,
                  'borderColor': '#E5DFD3',
                  'padding': {
                    'left': 12,
                    'right': 12,
                    'top': 12,
                    'bottom': 12,
                  },
                },
                'children': [
                  {
                    'type': 'selectable_text',
                    'props': {
                      'value': prettyPayload,
                      'monospace': true,
                      'fontSize': 10.0,
                      'color': '#14120F',
                    },
                  },
                ],
              },
            ],
          },
      ],
    },
  };
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

