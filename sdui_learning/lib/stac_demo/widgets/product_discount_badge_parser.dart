import 'package:flutter/material.dart';
import 'package:stac/stac.dart';

import '../data/stac_screen_validator.dart';

/// JSON model for the demo's only custom widget.
///
/// Stac 1.5.0 renders this only after [ProductDiscountBadgeParser] is
/// passed to [Stac.initialize]. Shipping that parser is an app release.
/// Returning the JSON type from a backend does not download Dart code.
class ProductDiscountBadge {
  const ProductDiscountBadge({required this.label});

  final String label;

  factory ProductDiscountBadge.fromJson(Map<String, dynamic> json) {
    final label = json['label'];
    if (label is! String || label.trim().isEmpty || label.length > 24) {
      throw const FormatException(
        'productDiscountBadge requires a short label.',
      );
    }
    return ProductDiscountBadge(label: label.trim());
  }
}

/// Official Stac 1.5.0 extension point: a [StacParser] registered at startup.
///
/// The Stac docs also show `json_annotation` and `build_runner` for a
/// [StacWidget] subclass. Those packages generate `fromJson`. This parser
/// uses the same registration API with a hand-written model so the demo
/// does not add a code generator.
class ProductDiscountBadgeParser extends StacParser<ProductDiscountBadge> {
  const ProductDiscountBadgeParser();

  @override
  String get type => StacScreenValidator.customWidgetType;

  @override
  ProductDiscountBadge getModel(Map<String, dynamic> json) {
    return ProductDiscountBadge.fromJson(json);
  }

  @override
  Widget parse(BuildContext context, ProductDiscountBadge model) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF9A3412),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        model.label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
