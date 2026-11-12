import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared product payload used to render the product details card across screens.
class ProductDetailData {
  const ProductDetailData({
    required this.title,
    required this.brand,
    required this.priceText,
    this.originalPriceText,
    this.discountText,
    this.imageUrl,
    this.imageColor = const Color(0xFFE9E3D7),
    this.sizes = const <String>[],
    this.subtitle,
  });

  final String title;
  final String brand;
  final String priceText;
  final String? originalPriceText;
  final String? discountText;
  final String? imageUrl;
  final Color imageColor;
  final List<String> sizes;
  final String? subtitle;
}

/// Infers apparel sizes when explicit [rawSizes] are absent.
List<String> inferProductSizes(String title, [Object? rawSizes]) {
  if (rawSizes is List && rawSizes.isNotEmpty) {
    return rawSizes.map((e) => e.toString()).toList();
  }
  final lower = title.toLowerCase();
  if (lower.contains('kurta') ||
      lower.contains('kurti') ||
      lower.contains('choli') ||
      lower.contains('ghagra') ||
      lower.contains('kediyu') ||
      lower.contains('jacket') ||
      lower.contains('saree') ||
      lower.contains('tee')) {
    return const ['S', 'M', 'L', 'XL'];
  }
  return const [];
}

/// Renders either a network image, local festival asset, or fallback icon.
Widget buildProductDetailImage(
  String? path, {
  BoxFit fit = BoxFit.cover,
  Alignment alignment = Alignment.center,
  Color fallbackColor = const Color(0xFFE9E3D7),
}) {
  final cleaned = (path ?? '').trim();
  if (cleaned.isEmpty) {
    return ColoredBox(
      color: fallbackColor,
      child: const Center(
        child: Icon(Icons.image_outlined, color: Color(0xFF7A7265), size: 40),
      ),
    );
  }
  if (cleaned.startsWith('http://') || cleaned.startsWith('https://')) {
    return CachedNetworkImage(
      imageUrl: cleaned,
      fit: fit,
      alignment: alignment,
      placeholder: (_, __) => ColoredBox(
        color: fallbackColor,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (_, __, ___) => ColoredBox(
        color: fallbackColor,
        child: const Center(
          child: Icon(Icons.broken_image_outlined, color: Color(0xFF7A7265)),
        ),
      ),
    );
  }
  final assetPath = cleaned.startsWith('assets/')
      ? cleaned
      : 'assets/festival_images/$cleaned';
  return Image.asset(
    assetPath,
    fit: fit,
    alignment: alignment,
    errorBuilder: (_, __, ___) => ColoredBox(
      color: fallbackColor,
      child: const Center(
        child: Icon(Icons.broken_image_outlined, color: Color(0xFF7A7265)),
      ),
    ),
  );
}

/// Displays a consistent modal product details card for any product card tap.
void showProductDetailCard(
  BuildContext context,
  ProductDetailData product, {
  String actionLabel = 'Add to Bag',
  Color actionColor = const Color(0xFFC8321A),
  void Function(String? selectedSize)? onActionPressed,
}) {
  String? selectedSize = product.sizes.isNotEmpty ? product.sizes.first : null;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 540),
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Spacer(),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD8D2C6),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            tooltip: 'Close',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: Color(0xFF5A554C),
                            ),
                            onPressed: () => Navigator.of(sheetContext).pop(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 210,
                      width: double.infinity,
                      child: buildProductDetailImage(
                        product.imageUrl,
                        fit: BoxFit.cover,
                        fallbackColor: product.imageColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (product.brand.trim().isNotEmpty) ...[
                    Text(
                      product.brand.trim(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF5A554C),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    product.title.trim(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF14120F),
                      height: 1.2,
                    ),
                  ),
                  if (product.subtitle != null &&
                      product.subtitle!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      product.subtitle!.trim(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: const Color(0xFF5A554C),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (product.priceText.trim().isNotEmpty)
                        Text(
                          product.priceText.trim(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF14120F),
                          ),
                        ),
                      if (product.originalPriceText != null &&
                          product.originalPriceText!.trim().isNotEmpty &&
                          product.originalPriceText!.trim() !=
                              product.priceText.trim()) ...[
                        const SizedBox(width: 8),
                        Text(
                          product.originalPriceText!.trim(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: const Color(0xFF7A7265),
                            textStyle: const TextStyle(
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                      ],
                      if (product.discountText != null &&
                          product.discountText!.trim().isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF6EE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            product.discountText!.trim(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1B7A3A),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F5F0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEBE6DC)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.local_shipping_outlined,
                          size: 18,
                          color: Color(0xFF5A554C),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Fast delivery to 380015 · Easy 7-day returns',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF5A554C),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (product.sizes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Select Size',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF14120F),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in product.sizes)
                          InkWell(
                            onTap: () => setSheetState(() => selectedSize = s),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: selectedSize == s
                                    ? const Color(0xFF14120F)
                                    : Colors.white,
                                border: Border.all(
                                  color: selectedSize == s
                                      ? const Color(0xFF14120F)
                                      : const Color(0xFFD8D2C6),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                s,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  color: selectedSize == s
                                      ? Colors.white
                                      : const Color(0xFF14120F),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: actionColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        if (onActionPressed != null) {
                          onActionPressed(selectedSize);
                        } else {
                          final sizeNote =
                              selectedSize != null ? ' (Size $selectedSize)' : '';
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${product.title.trim()}$sizeNote added to bag!',
                                ),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                        }
                      },
                      child: Text(
                        actionLabel,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
