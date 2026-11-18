import 'shopping_bag_store.dart';

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
    String? paymentMethod,
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
    final isCod =
        (paymentMethod ?? '').toLowerCase().contains('cash on delivery');
    final promoDiscount = promoApplied && !isCod && subtotal > 0
        ? (subtotal * 0.10).round()
        : 0;
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
