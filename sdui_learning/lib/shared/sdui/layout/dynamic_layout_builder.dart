import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../actions/sdui_action_router.dart';
import 'sdui_video_player.dart';
import '../../ui/checkout_page.dart';
import '../../ui/product_detail_sheet.dart';

part 'sdui_primitives.dart';
part 'sdui_commerce_widgets.dart';
part 'sdui_festival_widgets.dart';

/// Builds one SDUI node: props + pre-built children → Widget.
typedef SduiNodeBuilder =
    Widget Function(Map<String, dynamic> props, List<Widget> children);

/// Shared helpers/state for domain mixins (primitives / commerce / festival).
abstract class _SduiBuilderCore {
  _SduiBuilderCore({
    Map<String, Map<String, dynamic>>? components,
    this.maxComponentDepth = 12,
    this.failUnknownVisibly = false,
    this.onAction,
    SduiActionRouter? actionRouter,
  })  : _components = Map<String, Map<String, dynamic>>.from(
          components ?? const {},
        ),
        actionRouter = actionRouter ?? SduiActionRouter(onPageAction: onAction);

  /// Callback when user interacts with an action node (e.g. chip tap, filter button).
  final void Function(String action, Map<String, dynamic> data)? onAction;

  /// Typed action → navigation / side-effect router.
  final SduiActionRouter actionRouter;

  void _dispatchTapAction(
    BuildContext context,
    String? action,
    Map<String, dynamic> props,
  ) {
    actionRouter.dispatch(context, action, props);
  }

  /// Named JSON templates resolved by `type: component` / `type: ref`.
  final Map<String, Map<String, dynamic>> _components;

  /// Guard against runaway nested component expansion.
  final int maxComponentDepth;

  /// When true (debug/tests), unknown types show a tiny diagnostic chip.
  /// Production default is invisible [SizedBox.shrink].
  final bool failUnknownVisibly;

  final Set<String> _resolvingComponents = <String>{};
  final List<Map<String, dynamic>> _dataStack = <Map<String, dynamic>>[];
  int _componentDepth = 0;

  static const String _firebaseHostedBase =
      'https://sdui-learning.web.app/festival_images';

  Map<String, dynamic> _props(Map<String, dynamic> node) {
    final raw = node['props'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return Map<String, dynamic>.from(node)
      ..remove('type')
      ..remove('children')
      ..remove('child');
  }

  String _interpolate(String input) {
    if (_dataStack.isEmpty || !input.contains('{{')) return input;
    final data = <String, dynamic>{};
    for (final layer in _dataStack) {
      data.addAll(layer);
    }
    return input.replaceAllMapped(RegExp(r'\{\{(\w+)\}\}'), (m) {
      final key = m.group(1)!;
      final value = data[key];
      return value?.toString() ?? '';
    });
  }

  EdgeInsets _edgeInsets(Object? value) {
    if (value == null) return EdgeInsets.zero;
    if (value is num) return EdgeInsets.all(value.toDouble());
    if (value is Map) {
      final m = Map<String, dynamic>.from(value);
      return EdgeInsets.only(
        left: _double(m['left'] ?? m['l'], 0),
        top: _double(m['top'] ?? m['t'], 0),
        right: _double(m['right'] ?? m['r'], 0),
        bottom: _double(m['bottom'] ?? m['b'], 0),
      );
    }
    return EdgeInsets.zero;
  }

  double _layoutWidth(BuildContext context, BoxConstraints constraints) {
    if (constraints.maxWidth.isFinite && constraints.maxWidth > 0) {
      return constraints.maxWidth;
    }
    return MediaQuery.sizeOf(context).width;
  }

  int _responsiveInt(Object? value, double width, {required int fallback}) {
    if (value is Map) {
      final entries =
          value.entries
              .map(
                (e) => MapEntry(
                  double.tryParse('${e.key}') ?? 0,
                  _int(e.value, fallback),
                ),
              )
              .toList()
            ..sort((a, b) => a.key.compareTo(b.key));
      var result = fallback;
      for (final e in entries) {
        if (width >= e.key) result = e.value;
      }
      return result;
    }

    final base = _int(value, fallback);
    if (width >= 900) return (base + 2).clamp(1, 6);
    if (width >= 600) return (base + 1).clamp(1, 6);
    return base;
  }

  double _responsiveDouble(
    Object? value,
    double width, {
    required double fallbackFactor,
  }) {
    if (value is Map) {
      final entries =
          value.entries
              .map(
                (e) => MapEntry(
                  double.tryParse('${e.key}') ?? 0,
                  _double(e.value, width * fallbackFactor),
                ),
              )
              .toList()
            ..sort((a, b) => a.key.compareTo(b.key));
      var result = width * fallbackFactor;
      for (final e in entries) {
        if (width >= e.key) result = e.value;
      }
      return result;
    }
    if (value is num || value is String) {
      return _double(value, width * fallbackFactor);
    }
    return width * fallbackFactor;
  }

  double _double(Object? value, double fallback) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  double? _doubleOrNull(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  int _int(Object? value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  int? _intOrNull(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Color? _color(Object? value) {
    if (value is! String || value.isEmpty) return null;
    var hex = value.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return null;
    return Color(parsed);
  }

  LinearGradient? _gradient(Object? value) {
    if (value is! Map) return null;
    final m = Map<String, dynamic>.from(value);
    final colorsRaw = m['colors'];
    if (colorsRaw is! List || colorsRaw.isEmpty) return null;
    final colors = <Color>[];
    for (final c in colorsRaw) {
      final parsed = _color(c);
      if (parsed != null) colors.add(parsed);
    }
    if (colors.length < 2) return null;
    final begin = _alignment(m['begin']) ?? Alignment.centerLeft;
    final end = _alignment(m['end']) ?? Alignment.centerRight;
    return LinearGradient(colors: colors, begin: begin, end: end);
  }

  Alignment? _alignment(Object? value) {
    return switch (value) {
      'center' => Alignment.center,
      'topLeft' || 'top_left' => Alignment.topLeft,
      'topRight' || 'top_right' => Alignment.topRight,
      'bottomLeft' || 'bottom_left' => Alignment.bottomLeft,
      'bottomRight' || 'bottom_right' => Alignment.bottomRight,
      'topCenter' || 'top' => Alignment.topCenter,
      'bottomCenter' || 'bottom' => Alignment.bottomCenter,
      'centerLeft' || 'left' => Alignment.centerLeft,
      'centerRight' || 'right' => Alignment.centerRight,
      _ => null,
    };
  }

  FontWeight _fontWeight(Map<String, dynamic> props) {
    if (props['bold'] == true) return FontWeight.w700;
    final w = props['fontWeight'];
    if (w is num) {
      final v = w.toInt();
      return FontWeight.values.firstWhere(
        (e) => e.value == v,
        orElse: () => FontWeight.w400,
      );
    }
    return switch (w) {
      'w100' || 'thin' => FontWeight.w100,
      'w300' || 'light' => FontWeight.w300,
      'w500' || 'medium' => FontWeight.w500,
      'w600' || 'semibold' => FontWeight.w600,
      'w700' || 'bold' => FontWeight.w700,
      'w900' || 'black' => FontWeight.w900,
      _ => FontWeight.w400,
    };
  }

  MainAxisSize _mainAxisSize(Object? value) {
    return value == 'max' ? MainAxisSize.max : MainAxisSize.min;
  }

  MainAxisAlignment _mainAxisAlignment(Object? value) {
    return switch (value) {
      'center' => MainAxisAlignment.center,
      'end' || 'bottom' || 'right' => MainAxisAlignment.end,
      'spaceBetween' => MainAxisAlignment.spaceBetween,
      'spaceAround' => MainAxisAlignment.spaceAround,
      'spaceEvenly' => MainAxisAlignment.spaceEvenly,
      _ => MainAxisAlignment.start,
    };
  }

  CrossAxisAlignment _crossAxisAlignment(Object? value) {
    return switch (value) {
      'center' => CrossAxisAlignment.center,
      'end' => CrossAxisAlignment.end,
      'stretch' => CrossAxisAlignment.stretch,
      _ => CrossAxisAlignment.start,
    };
  }

  BoxFit _boxFit(Object? value) {
    return switch (value) {
      'contain' => BoxFit.contain,
      'fill' => BoxFit.fill,
      'fitWidth' => BoxFit.fitWidth,
      'fitHeight' => BoxFit.fitHeight,
      _ => BoxFit.cover,
    };
  }

  void _log(String message) {
    debugPrint('[SDUI][Builder] $message');
  }
  /// Implemented by [DynamicLayoutBuilder].
  Widget build(Map<String, dynamic>? node);
  List<Widget> buildAll(List<dynamic>? nodes);

  String _resolveImageUrl(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return '';

    if (trimmed.startsWith('gs://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null && uri.host.isNotEmpty) {
        final bucket = uri.host;
        final rawPath =
            uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
        final encodedPath = Uri.encodeComponent(rawPath);
        return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/$encodedPath?alt=media';
      }
    }

    if (trimmed.startsWith('firebase://')) {
      final subpath = trimmed
          .substring('firebase://'.length)
          .replaceFirst(RegExp(r'^/+'), '');
      return '$_firebaseHostedBase/$subpath';
    }

    return trimmed;
  }

  String? _deriveFallbackAsset(String path) {
    try {
      final uri = Uri.tryParse(path);
      final rawPath = uri != null ? uri.path : path;
      final match = RegExp(
        r'(?:festival_images/)?(diwali|navratri|holi|uttarayan)/[^?#]+',
        caseSensitive: false,
      ).firstMatch(rawPath);
      if (match != null) {
        final festivalPath = match.group(0)!;
        final clean = festivalPath.startsWith('festival_images/')
            ? festivalPath
            : 'festival_images/$festivalPath';
        return 'assets/$clean';
      }
    } catch (_) {}
    return null;
  }

  Widget _buildImageWidget({
    required String path,
    BoxFit fit = BoxFit.cover,
    Alignment alignment = Alignment.center,
    double? width,
    double? height,
  }) {
    final trimmed = _resolveImageUrl(path);
    if (trimmed.isEmpty) {
      return const SizedBox.shrink();
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final fallbackAsset = _deriveFallbackAsset(trimmed);
      return CachedNetworkImage(
        imageUrl: trimmed,
        fit: fit,
        alignment: alignment,
        width: width,
        height: height,
        placeholder: (_, __) =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorWidget: (_, error, __) {
          if (fallbackAsset != null) {
            return Image.asset(
              fallbackAsset,
              fit: fit,
              alignment: alignment,
              width: width,
              height: height,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: Colors.white10,
                child: Center(child: Icon(Icons.broken_image_outlined)),
              ),
            );
          }
          return const ColoredBox(
            color: Colors.white10,
            child: Center(child: Icon(Icons.broken_image_outlined)),
          );
        },
      );
    }
    final assetPath = trimmed.startsWith('assets/')
        ? trimmed
        : 'assets/festival_images/$trimmed';
    return Image.asset(
      assetPath,
      fit: fit,
      alignment: alignment,
      width: width,
      height: height,
      errorBuilder: (_, error, __) {
        debugPrint('[SDUI][Image] Failed to load asset: $assetPath ($error)');
        return const ColoredBox(
          color: Colors.white10,
          child: Center(child: Icon(Icons.broken_image_outlined)),
        );
      },
    );
  }

  List<Widget> _withGap(
    List<Widget> children,
    double gap, {
    Axis axis = Axis.vertical,
  }) {
    if (gap <= 0 || children.length <= 1) return children;
    final out = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      out.add(children[i]);
      if (i < children.length - 1) {
        out.add(
          axis == Axis.vertical ? SizedBox(height: gap) : SizedBox(width: gap),
        );
      }
    }
    return out;
  }

  List<Widget> _children(Map<String, dynamic> node) {
    final child = node['child'];
    if (child is Map) {
      return [build(Map<String, dynamic>.from(child))];
    }
    final children = node['children'];
    if (children is List) {
      return buildAll(children);
    }
    return const [];
  }

  Widget _singleChild(List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();
    if (children.length == 1) return children.first;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _applyConstraints(Widget child, Map<String, dynamic> props) {
    final minW = _doubleOrNull(props['minWidth']);
    final maxW = _doubleOrNull(props['maxWidth']);
    final minH = _doubleOrNull(props['minHeight']);
    final maxH = _doubleOrNull(props['maxHeight']);
    if (minW == null && maxW == null && minH == null && maxH == null) {
      return child;
    }
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: minW ?? 0,
        maxWidth: maxW ?? double.infinity,
        minHeight: minH ?? 0,
        maxHeight: maxH ?? double.infinity,
      ),
      child: child,
    );
  }

  Widget _applyVisibility(Widget child, Map<String, dynamic> props) {
    final opacity = _doubleOrNull(props['opacity']);
    if (opacity == null) return child;
    return Opacity(opacity: opacity.clamp(0.0, 1.0), child: child);
  }

  /// Scoped data binding: replace `{{key}}` from the current data stack.
  /// Not a general expression engine.
  Widget _unknown(
    String type,
    Map<String, dynamic> props,
    List<Widget> children,
  ) {
    _log('Unknown SDUI type: $type');

    if (props['asLayout'] == true && children.isNotEmpty) {
      return Column(
        mainAxisSize: _mainAxisSize(props['mainAxisSize']),
        mainAxisAlignment: _mainAxisAlignment(props['mainAxisAlignment']),
        crossAxisAlignment: _crossAxisAlignment(props['crossAxisAlignment']),
        children: _withGap(children, _double(props['gap'], 0)),
      );
    }

    if (failUnknownVisibly) {
      return Padding(
        padding: const EdgeInsets.all(4),
        child: Text(
          'Unknown: $type',
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // --- helpers ---

  Widget _component(Map<String, dynamic> props) {
    final id = (props['id'] as String? ?? props['ref'] as String? ?? '').trim();
    if (id.isEmpty) {
      _log('component missing id');
      return const SizedBox.shrink();
    }
    if (_resolvingComponents.contains(id)) {
      _log('Circular component reference: $id');
      return const SizedBox.shrink();
    }
    if (_componentDepth >= maxComponentDepth) {
      _log('Max component depth ($maxComponentDepth) exceeded at $id');
      return const SizedBox.shrink();
    }

    final template = _components[id];
    if (template == null) {
      _log('Unknown component id: $id');
      return const SizedBox.shrink();
    }

    final data = props['data'];
    final dataMap = data is Map ? Map<String, dynamic>.from(data) : null;

    _resolvingComponents.add(id);
    _componentDepth++;
    if (dataMap != null) _dataStack.add(dataMap);
    try {
      return build(Map<String, dynamic>.from(template));
    } finally {
      if (dataMap != null && _dataStack.isNotEmpty) _dataStack.removeLast();
      _componentDepth--;
      _resolvingComponents.remove(id);
    }
  }


}

class DynamicLayoutBuilder extends _SduiBuilderCore
    with _SduiPrimitiveBuilders, _SduiCommerceBuilders, _SduiFestivalBuilders {
  DynamicLayoutBuilder({
    super.components,
    super.maxComponentDepth,
    super.failUnknownVisibly,
    super.onAction,
    super.actionRouter,
  });

  /// Extra types registered at runtime (optional).
  static final Map<String, SduiNodeBuilder> _custom = {};

  /// Register a type without editing [build] (still Dart code once).
  static void register(String type, SduiNodeBuilder builder) {
    _custom[type.trim().toLowerCase()] = builder;
  }

  /// Built-in widget catalog (map lookup, not switch).
  late final Map<String, SduiNodeBuilder> _catalog = {
    'column': _column,
    'row': _row,
    'grid': _grid,
    'padding': _padding,
    'expanded': (_, children) => Expanded(child: _singleChild(children)),
    'flexible': (_, children) => Flexible(child: _singleChild(children)),
    'sized_box': _sizedBox,
    'sizedbox': _sizedBox,
    'spacer': (props, _) => Spacer(flex: _int(props['flex'], 1)),
    'center': (_, children) => Center(child: _singleChild(children)),
    'text': (props, _) => _text(props),
    'image': (props, _) => _image(props),
    'gif': (props, _) => _image(props), // CachedNetworkImage animates GIFs
    'video': (props, _) => _video(props),
    'container': _container,
    'button': (props, _) => _button(props),
    'card': _card,
    'list': _list,
    'search_bar': (props, _) => _searchBar(props),
    'searchbar': (props, _) => _searchBar(props),
    'icon': (props, _) => _icon(props),
    'chip': (props, _) => _chip(props),
    'chips': _chips,
    'carousel': _carousel,
    'component': (props, _) => _component(props),
    'ref': (props, _) => _component(props),
    'stack': _stack,
    'positioned': _positioned,
    'diwali_header': (props, _) => _festiveHeader(props, defaultFestival: 'diwali'),
    'navratri_header': (props, _) => _festiveHeader(props, defaultFestival: 'navratri'),
    'uttarayan_header': (props, _) => _festiveHeader(props, defaultFestival: 'uttarayan'),
    'holi_header': (props, _) => _festiveHeader(props, defaultFestival: 'holi'),
    'festive_header': (props, _) => _festiveHeader(props, defaultFestival: 'holi'),
    'nine_colours': (props, _) => _nineColours(props),
    'countdown_card': (props, _) => _countdownCard(props),
    'combo_card': (props, _) => _comboCard(props),
    'product_card': (props, _) => _productCard(props),
    'bottom_nav': (props, _) => _bottomNav(props),
    'divider': _divider,
    'expansion_tile': _expansionTile,
    'selectable_text': (props, _) => _selectableText(props),
  };

  @override
  Widget build(Map<String, dynamic>? node) {
    if (node == null) return const SizedBox.shrink();

    try {
      final type = (node['type'] as String? ?? '').toLowerCase().trim();
      if (type.isEmpty) {
        _log('Skipping node with empty type');
        return const SizedBox.shrink();
      }

      final props = _props(node);
      if (props['visible'] == false) return const SizedBox.shrink();

      final children = _children(node);
      final builder = _custom[type] ?? _catalog[type];
      if (builder == null) {
        return _unknown(type, props, children);
      }

      Widget widget = builder(props, children);
      widget = _applyConstraints(widget, props);
      widget = _applyVisibility(widget, props);
      return widget;
    } catch (e, st) {
      _log('Node build failed: $e\n$st');
      return const SizedBox.shrink();
    }
  }

  @override
  List<Widget> buildAll(List<dynamic>? nodes) {
    if (nodes == null) return const [];
    final out = <Widget>[];
    for (final raw in nodes) {
      if (raw is! Map) {
        _log('Skipping non-map child: ${raw.runtimeType}');
        continue;
      }
      try {
        out.add(build(Map<String, dynamic>.from(raw)));
      } catch (e, st) {
        _log('Child build failed (siblings continue): $e\n$st');
      }
    }
    return out;
  }

  // --- layout primitives ---

}
