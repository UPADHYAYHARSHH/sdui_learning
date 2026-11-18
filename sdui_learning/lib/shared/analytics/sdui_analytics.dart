import 'package:flutter/foundation.dart';

/// Thin analytics facade — swap implementation for Firebase Analytics later.
class SduiAnalytics {
  SduiAnalytics._();

  static void screenView(String name, {Map<String, Object?> params = const {}}) {
    _log('screen_view', {'screen': name, ...params});
  }

  static void action(String name, {Map<String, Object?> params = const {}}) {
    _log('sdui_action', {'action': name, ...params});
  }

  static void addToBag({
    required String productId,
    required String title,
    String? size,
  }) {
    _log('add_to_bag', {
      'productId': productId,
      'title': title,
      if (size != null) 'size': size,
    });
  }

  static void _log(String event, Map<String, Object?> params) {
    if (kDebugMode) {
      debugPrint('[SDUI][Analytics] $event $params');
    }
  }
}
