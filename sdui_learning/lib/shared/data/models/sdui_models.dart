import 'package:flutter/material.dart';

class SduiThemeConfig {
  const SduiThemeConfig({
    required this.primary,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.onPrimary,
    required this.onBackground,
  });

  final Color primary;
  final Color secondary;
  final Color background;
  final Color surface;
  final Color onPrimary;
  final Color onBackground;

  factory SduiThemeConfig.fromJson(Map<String, dynamic> json) {
    return SduiThemeConfig(
      primary: _parseColor(json['primary'] as String? ?? '#7B1E3A'),
      secondary: _parseColor(json['secondary'] as String? ?? '#C9A227'),
      background: _parseColor(json['background'] as String? ?? '#FFFFFF'),
      surface: _parseColor(json['surface'] as String? ?? '#FFFFFF'),
      onPrimary: _parseColor(json['onPrimary'] as String? ?? '#FFFFFF'),
      onBackground: _parseColor(json['onBackground'] as String? ?? '#000000'),
    );
  }

  static Color _parseColor(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    final value = int.parse(
      cleaned.length == 6 ? 'FF$cleaned' : cleaned,
      radix: 16,
    );
    return Color(value);
  }
}

sealed class SduiSection {
  const SduiSection();

  factory SduiSection.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? '';
    return switch (type) {
      'hero' => HeroSection.fromJson(json),
      'ritual_list' => RitualListSection.fromJson(json),
      'offer_strip' => OfferStripSection.fromJson(json),
      'cta' => CtaSection.fromJson(json),
      _ => UnknownSection(type: type),
    };
  }
}

class UnknownSection extends SduiSection {
  const UnknownSection({required this.type});
  final String type;
}

class HeroSection extends SduiSection {
  const HeroSection({
    required this.title,
    required this.subtitle,
    this.badge,
    this.imageUrl,
  });

  final String title;
  final String subtitle;
  final String? badge;
  final String? imageUrl;

  factory HeroSection.fromJson(Map<String, dynamic> json) {
    return HeroSection(
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      badge: json['badge'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );
  }
}

class RitualItem {
  const RitualItem({
    required this.title,
    required this.description,
    this.icon,
  });

  final String title;
  final String description;
  final String? icon;

  factory RitualItem.fromJson(Map<String, dynamic> json) {
    return RitualItem(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String?,
    );
  }
}

class RitualListSection extends SduiSection {
  const RitualListSection({
    required this.title,
    required this.items,
  });

  final String title;
  final List<RitualItem> items;

  factory RitualListSection.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    return RitualListSection(
      title: json['title'] as String? ?? '',
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(RitualItem.fromJson)
          .toList(),
    );
  }
}

class OfferItem {
  const OfferItem({
    required this.code,
    required this.label,
    required this.discount,
  });

  final String code;
  final String label;
  final String discount;

  factory OfferItem.fromJson(Map<String, dynamic> json) {
    return OfferItem(
      code: json['code'] as String? ?? '',
      label: json['label'] as String? ?? '',
      discount: json['discount'] as String? ?? '',
    );
  }
}

class OfferStripSection extends SduiSection {
  const OfferStripSection({
    required this.title,
    required this.offers,
  });

  final String title;
  final List<OfferItem> offers;

  factory OfferStripSection.fromJson(Map<String, dynamic> json) {
    final rawOffers = json['offers'] as List<dynamic>? ?? const [];
    return OfferStripSection(
      title: json['title'] as String? ?? '',
      offers: rawOffers
          .whereType<Map<String, dynamic>>()
          .map(OfferItem.fromJson)
          .toList(),
    );
  }
}

enum CtaAction { toast, share, openUrl, unknown }

class CtaSection extends SduiSection {
  const CtaSection({
    required this.label,
    required this.action,
    this.payload,
  });

  final String label;
  final CtaAction action;
  final String? payload;

  factory CtaSection.fromJson(Map<String, dynamic> json) {
    final raw = (json['action'] as String? ?? '').toLowerCase();
    final action = switch (raw) {
      'toast' => CtaAction.toast,
      'share' => CtaAction.share,
      'open_url' => CtaAction.openUrl,
      _ => CtaAction.unknown,
    };
    return CtaSection(
      label: json['label'] as String? ?? 'Continue',
      action: action,
      payload: json['payload'] as String?,
    );
  }
}

class SduiScreenConfig {
  const SduiScreenConfig({
    required this.id,
    required this.title,
    required this.theme,
    required this.sections,
    this.root,
    this.components,
    this.showAppBar = false,
  });

  final String id;
  final String title;
  final SduiThemeConfig theme;
  final List<SduiSection> sections;
  final Map<String, dynamic>? root;
  final Map<String, Map<String, dynamic>>? components;
  final bool showAppBar;

  factory SduiScreenConfig.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'] as List<dynamic>? ?? const [];
    final rawRoot = json['root'];
    final rawComponents = json['components'];
    final componentsMap = <String, Map<String, dynamic>>{};
    if (rawComponents is Map) {
      rawComponents.forEach((key, val) {
        if (val is Map) componentsMap['$key'] = Map<String, dynamic>.from(val);
      });
    }

    return SduiScreenConfig(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? json['id'] as String? ?? 'Festival',
      theme: SduiThemeConfig.fromJson(
        Map<String, dynamic>.from(json['theme'] as Map? ?? const {}),
      ),
      sections: rawSections
          .whereType<Map>()
          .map((e) => SduiSection.fromJson(Map<String, dynamic>.from(e)))
          .where((s) => s is! UnknownSection)
          .toList(),
      root: rawRoot is Map ? Map<String, dynamic>.from(rawRoot) : null,
      components: componentsMap.isNotEmpty ? componentsMap : null,
      showAppBar: json['showAppBar'] == true,
    );
  }
}
