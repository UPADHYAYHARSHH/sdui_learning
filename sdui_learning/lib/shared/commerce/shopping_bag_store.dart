import 'package:flutter/material.dart';

import '../ui/product_detail_sheet.dart';

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
    this.items = const [],
    this.deliveryAddress = 'Satellite, Ahmedabad 380015',
    this.estimatedDelivery = 'Express · 2-3 Days',
    this.sduiDocument,
  });

  final String orderId;
  final String status;
  final DateTime createdAt;
  final Map<String, dynamic> requestPayload;
  final int totalPayable;
  final int itemCount;
  final String paymentMethod;
  final List<CheckoutItem> items;
  final String deliveryAddress;
  final String estimatedDelivery;
  final Map<String, dynamic>? sduiDocument;
}

/// Normalized display item used in order confirmation view.
class OrderItemInfo {
  const OrderItemInfo({
    required this.title,
    required this.brand,
    required this.price,
    required this.lineTotal,
    required this.quantity,
    this.size,
    this.imageUrl,
    this.imageColor = const Color(0xFFE9E3D7),
  });

  final String title;
  final String brand;
  final int price;
  final int lineTotal;
  final int quantity;
  final String? size;
  final String? imageUrl;
  final Color imageColor;
}

/// Callback signature allowing callers or tests to override order submission.
typedef PlaceOrderHandler = Future<OrderConfirmation> Function(
  Map<String, dynamic> requestPayload,
);

/// Shared shopping bag store synchronized across SDUI Home, See All, Categories,
/// and the full-screen checkout flow.
class ShoppingBagStore extends ChangeNotifier {
  ShoppingBagStore._();

  static final ShoppingBagStore instance = ShoppingBagStore._();

  /// Stable bag key so Home / See All / Category listing share one line item.
  static String canonicalId(String productId, {String? size}) {
    final id = productId.trim();
    final s = size?.trim();
    if (s == null || s.isEmpty) return id;
    return '${id}_$s';
  }

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

  int quantityFor(String id) => _items[id]?.quantity ?? 0;

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
