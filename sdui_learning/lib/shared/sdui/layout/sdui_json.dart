/// Semantic JSON helpers for SDUI layout updates.
class SduiJson {
  /// True when [next] is meaningfully different from [previous].
  ///
  /// Map key insertion order does not count as a change.
  static bool hasMeaningfulChange(
    Map<String, dynamic>? previous,
    Map<String, dynamic>? next,
  ) {
    if (identical(previous, next)) return false;
    if (previous == null || next == null) return previous != next;
    return !_deepEquals(previous, next);
  }

  static bool _deepEquals(Object? a, Object? b) {
    if (identical(a, b)) return true;
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key)) return false;
        if (!_deepEquals(a[key], b[key])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_deepEquals(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }
}
