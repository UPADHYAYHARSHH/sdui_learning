import 'package:flutter/material.dart';

import '../../data/models/sdui_models.dart';
import '../widgets/cta_section_widget.dart';
import '../widgets/hero_section_widget.dart';
import '../widgets/offer_strip_section_widget.dart';
import '../widgets/ritual_list_section_widget.dart';

/// Maps SDUI JSON `type` → Flutter widget.
///
/// Server can reorder / add known section types without an app release.
/// Unknown types are skipped (see [UnknownSection]).
class SduiWidgetRegistry {
  const SduiWidgetRegistry();

  Widget build(SduiSection section) {
    return switch (section) {
      HeroSection() => HeroSectionWidget(section: section),
      RitualListSection() => RitualListSectionWidget(section: section),
      OfferStripSection() => OfferStripSectionWidget(section: section),
      CtaSection() => CtaSectionWidget(section: section),
      UnknownSection() => const SizedBox.shrink(),
    };
  }

  /// Build the full vertical screen from `sections` array in Firestore JSON.
  List<Widget> buildAll(List<SduiSection> sections) {
    return sections.map(build).toList();
  }
}
