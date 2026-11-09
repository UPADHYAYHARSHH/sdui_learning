import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'sdui_video_player.dart';
import '../../ui/category_listing_page.dart';

/// Builds one SDUI node: props + pre-built children → Widget.
typedef SduiNodeBuilder =
    Widget Function(Map<String, dynamic> props, List<Widget> children);

/// Model-free SDUI: builds Flutter widgets from nested JSON Maps.
///
/// Types are resolved by **map lookup**, not switch/case.
/// New designs are compositions of catalog primitives (or `component` refs),
/// not new Dart classes.
///
/// Node shape:
/// ```json
/// { "type": "column", "props": { "gap": 12 }, "children": [ ... ] }
/// ```
///
/// Component refs (templates from [components]):
/// ```json
/// { "type": "component", "props": { "id": "promo_banner", "data": { "title": "Sale" } } }
/// ```
class DynamicLayoutBuilder {
  DynamicLayoutBuilder({
    Map<String, Map<String, dynamic>>? components,
    this.maxComponentDepth = 12,
    this.failUnknownVisibly = false,
  }) : _components = Map<String, Map<String, dynamic>>.from(
         components ?? const {},
       );

  /// Named JSON templates resolved by `type: component` / `type: ref`.
  final Map<String, Map<String, dynamic>> _components;

  /// Guard against runaway nested component expansion.
  final int maxComponentDepth;

  /// When true (debug/tests), unknown types show a tiny diagnostic chip.
  /// Production default is invisible [SizedBox.shrink].
  final bool failUnknownVisibly;

  /// Extra types registered at runtime (optional).
  static final Map<String, SduiNodeBuilder> _custom = {};

  final Set<String> _resolvingComponents = <String>{};
  final List<Map<String, dynamic>> _dataStack = <Map<String, dynamic>>[];
  int _componentDepth = 0;

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
  };

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

  Widget _column(Map<String, dynamic> props, List<Widget> children) {
    return Padding(
      padding: _edgeInsets(props['padding']),
      child: Column(
        mainAxisSize: _mainAxisSize(props['mainAxisSize']),
        mainAxisAlignment: _mainAxisAlignment(props['mainAxisAlignment']),
        crossAxisAlignment: _crossAxisAlignment(props['crossAxisAlignment']),
        children: _withGap(children, _double(props['gap'], 0)),
      ),
    );
  }

  Widget _row(Map<String, dynamic> props, List<Widget> children) {
    final scroll = props['scroll'] == true;
    final expandChildren = props['expandChildren'] == true;
    final gap = _double(props['gap'], 0);

    List<Widget> items;
    if (expandChildren && !scroll) {
      items = <Widget>[];
      for (var i = 0; i < children.length; i++) {
        items.add(Expanded(child: children[i]));
        if (gap > 0 && i < children.length - 1) {
          items.add(SizedBox(width: gap));
        }
      }
    } else {
      items = _withGap(children, gap, axis: Axis.horizontal);
    }

    final row = Row(
      mainAxisSize: scroll ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment: _mainAxisAlignment(props['mainAxisAlignment']),
      crossAxisAlignment: _crossAxisAlignment(props['crossAxisAlignment']),
      children: items,
    );

    final padded = Padding(padding: _edgeInsets(props['padding']), child: row);

    if (!scroll) return padded;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: padded,
    );
  }

  Widget _grid(Map<String, dynamic> props, List<Widget> children) {
    final gap = _double(props['gap'], 8);
    final aspect = _double(props['childAspectRatio'], 1);
    final responsive = props['responsive'] != false;

    return Padding(
      padding: _edgeInsets(props['padding']),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = _layoutWidth(context, constraints);
          final count = responsive
              ? _responsiveInt(props['crossAxisCount'], width, fallback: 2)
              : _int(props['crossAxisCount'], 2);

          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: count.clamp(1, 6),
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            childAspectRatio: aspect,
            children: children,
          );
        },
      ),
    );
  }

  Widget _list(Map<String, dynamic> props, List<Widget> children) {
    final gap = _double(props['gap'], 0);
    final scrollDirection =
        (props['scrollDirection'] as String?) == 'horizontal'
        ? Axis.horizontal
        : Axis.vertical;

    return Padding(
      padding: _edgeInsets(props['padding']),
      child: ListView.separated(
        shrinkWrap: true,
        scrollDirection: scrollDirection,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: children.length,
        separatorBuilder: (_, __) => scrollDirection == Axis.horizontal
            ? SizedBox(width: gap)
            : SizedBox(height: gap),
        itemBuilder: (_, i) => children[i],
      ),
    );
  }

  Widget _padding(Map<String, dynamic> props, List<Widget> children) {
    return Padding(
      padding: _edgeInsets(props['padding'] ?? props['all'] ?? 16),
      child: _singleChild(children),
    );
  }

  Widget _sizedBox(Map<String, dynamic> props, List<Widget> children) {
    return SizedBox(
      width: _doubleOrNull(props['width']),
      height: _doubleOrNull(props['height']),
      child: children.isEmpty ? null : _singleChild(children),
    );
  }

  Widget _container(Map<String, dynamic> props, List<Widget> children) {
    final radius = _double(props['radius'] ?? props['borderRadius'], 0);
    final borderWidth = _double(props['borderWidth'], 0);
    final borderColor = _color(props['borderColor']);

    final bgImageRaw =
        props['bgImage'] as String? ?? props['image'] as String?;
    DecorationImage? decorationImage;
    if (bgImageRaw != null && bgImageRaw.isNotEmpty) {
      final imgPath = _resolveImageUrl(bgImageRaw);
      final imageProvider =
          (imgPath.startsWith('http://') || imgPath.startsWith('https://'))
              ? CachedNetworkImageProvider(imgPath) as ImageProvider
              : AssetImage(
                  imgPath.startsWith('assets/')
                      ? imgPath
                      : 'assets/festival_images/$imgPath',
                );
      final imgAlignment = _alignment(props['imageAlignment']) ?? Alignment.center;
      decorationImage = DecorationImage(
        image: imageProvider,
        fit: _boxFit(props['fit']),
        alignment: imgAlignment,
        colorFilter: props['imageDim'] == true
            ? ColorFilter.mode(
                Colors.black.withValues(alpha: 0.15),
                BlendMode.darken,
              )
            : null,
      );
    }

    final containerWidget = Container(
      width: _doubleOrNull(props['width']),
      height: _doubleOrNull(props['height']),
      padding: _edgeInsets(props['padding']),
      margin: _edgeInsets(props['margin']),
      alignment: _alignment(props['alignment']),
      decoration: BoxDecoration(
        color: _gradient(props['gradient']) == null
            ? _color(props['color'])
            : null,
        gradient: _gradient(props['gradient']),
        image: decorationImage,
        borderRadius: BorderRadius.circular(radius),
        border: borderWidth > 0
            ? Border.all(
                color: borderColor ?? Colors.white24,
                width: borderWidth,
              )
            : null,
      ),
      child: children.isEmpty ? null : _singleChild(children),
    );

    final action = props['action'] as String? ?? props['onTap'] as String?;
    final isCategoryTile = bgImageRaw != null &&
        (bgImageRaw.contains('looks') ||
            bgImageRaw.contains('choli') ||
            bgImageRaw.contains('kediyu') ||
            bgImageRaw.contains('kurta'));

    if (action != null || isCategoryTile) {
      return Builder(
        builder: (context) {
          return InkWell(
            onTap: () {
              if (action == 'navigate_back') {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CategoryListingPage(),
                  ),
                );
              }
            },
            borderRadius: BorderRadius.circular(radius),
            child: containerWidget,
          );
        },
      );
    }

    return containerWidget;
  }

  Widget _card(Map<String, dynamic> props, List<Widget> children) {
    return Card(
      color: _color(props['color']),
      child: Padding(
        padding: _edgeInsets(props['padding'] ?? 12),
        child: _singleChild(children),
      ),
    );
  }

  // --- leaf widgets ---

  Widget _text(Map<String, dynamic> props) {
    final raw = props['value'] as String? ?? props['text'] as String? ?? '';
    final value = _interpolate(raw);
    final size = _double(props['fontSize'], 16);
    final weight = _fontWeight(props);
    final align = switch (props['align'] as String? ??
        props['textAlign'] as String?) {
      'center' => TextAlign.center,
      'right' || 'end' => TextAlign.right,
      'justify' => TextAlign.justify,
      _ => TextAlign.left,
    };

    final decoration = (props['lineThrough'] == true ||
            props['decoration'] == 'lineThrough' ||
            props['strike'] == true)
        ? TextDecoration.lineThrough
        : null;

    final shadow = props['shadow'] == true
        ? [
            Shadow(
              color: Colors.black.withValues(alpha: 0.65),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ]
        : null;

    final baseStyle = TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: _color(props['color']),
      height: _doubleOrNull(props['height']),
      decoration: decoration,
      shadows: shadow,
    );

    return Text(
      value,
      textAlign: align,
      maxLines: _intOrNull(props['maxLines']),
      overflow: props['overflow'] == 'ellipsis' ? TextOverflow.ellipsis : null,
      style: GoogleFonts.plusJakartaSans(textStyle: baseStyle),
    );
  }

  Widget _image(Map<String, dynamic> props) {
    final url = _interpolate(
      props['url'] as String? ??
          props['imageUrl'] as String? ??
          props['src'] as String? ??
          props['asset'] as String? ??
          '',
    );
    final height = _doubleOrNull(props['height']) ?? 160;
    final width = _doubleOrNull(props['width']);
    final radius = _double(props['radius'], 12);
    final aspect = _doubleOrNull(props['aspectRatio']);
    final alignment = _alignment(props['imageAlignment'] ?? props['alignment']) ??
        Alignment.center;
    final fit = _boxFit(props['fit']);
    final bgColor = _color(props['color'] ?? props['backgroundColor']);
    final borderWidth = _double(props['borderWidth'], 0);
    final borderColor = _color(props['borderColor']);
    final w = width ?? double.infinity;

    Widget child;
    if (url.isEmpty) {
      child = const ColoredBox(
        color: Colors.white12,
        child: Center(child: Icon(Icons.image_not_supported_outlined)),
      );
    } else {
      child = _buildImageWidget(
        path: url,
        fit: fit,
        alignment: alignment,
        width: w,
        height: aspect == null ? height : null,
      );
    }

    if (bgColor != null) {
      child = ColoredBox(color: bgColor, child: child);
    }

    Widget framed = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: child,
    );

    if (borderWidth > 0 && borderColor != null) {
      framed = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: framed,
      );
    }

    if (aspect != null) {
      framed = AspectRatio(aspectRatio: aspect, child: framed);
    } else {
      framed = SizedBox(width: width, height: height, child: framed);
    }

    return framed;
  }

  static const String _firebaseHostedBase =
      'https://sdui-learning.web.app/festival_images';

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

  Widget _video(Map<String, dynamic> props) {
    final url = _interpolate(
      props['url'] as String? ?? props['videoUrl'] as String? ?? '',
    );
    return SduiVideoPlayer(
      url: url,
      height: _double(props['height'], 200),
      width: _doubleOrNull(props['width']),
      autoplay: props['autoplay'] == true,
      looping: props['looping'] != false,
      muted: props['muted'] != false,
      fit: _boxFit(props['fit']),
      radius: _double(props['radius'], 12),
    );
  }

  Widget _searchBar(Map<String, dynamic> props) {
    final hint = _interpolate(props['hint'] as String? ?? 'Search...');
    final fill = _color(props['color']) ?? const Color(0xFF1E1E24);
    final radius = _double(props['radius'], 14);

    return Container(
      height: _double(props['height'], 48),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: _color(props['iconColor']) ?? Colors.white54,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hint,
              style: TextStyle(
                color: _color(props['hintColor']) ?? Colors.white54,
                fontSize: _double(props['fontSize'], 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _icon(Map<String, dynamic> props) {
    final name = (props['name'] as String? ?? 'notifications').toLowerCase();
    final size = _double(props['size'], 26);
    final color = _color(props['color']) ?? Colors.white;
    final bg = _color(props['background']);
    final radius = _double(props['radius'], 12);

    final iconData = switch (name) {
      'arrow_back' ||
      'back' ||
      'arrow_left' => Icons.arrow_back_rounded,
      'close' || 'clear' => Icons.close_rounded,
      'tune' || 'filter' => Icons.tune_rounded,
      'sort' => Icons.swap_vert_rounded,
      'shopping_bag' || 'bag' => Icons.shopping_bag_outlined,
      'notifications' ||
      'notification' ||
      'bell' => Icons.notifications_none_rounded,
      'search' => Icons.search_rounded,
      'cart' || 'shopping_cart' => Icons.shopping_cart_outlined,
      'menu' => Icons.menu_rounded,
      'person' || 'profile' => Icons.person_outline_rounded,
      'home' => Icons.home_outlined,
      'favorite' || 'heart' => Icons.favorite_border_rounded,
      'play' => Icons.play_arrow_rounded,
      'gift' => Icons.card_giftcard_rounded,
      'star' => Icons.star_outline_rounded,
      _ => Icons.circle_outlined,
    };

    final icon = Icon(iconData, size: size, color: color);
    Widget iconWidget = icon;
    if (bg != null) {
      iconWidget = Container(
        width: _double(props['box'], size + 20),
        height: _double(props['box'], size + 20),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(radius),
        ),
        alignment: Alignment.center,
        child: icon,
      );
    }

    final action = props['action'] as String? ?? props['onTap'] as String?;
    if (action != null) {
      return Builder(
        builder: (context) => GestureDetector(
          onTap: () {
            if (action == 'navigate_back' || action == 'back') {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            } else if (action == 'category_listing' || action == 'categories') {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CategoryListingPage(),
                ),
              );
            }
          },
          child: iconWidget,
        ),
      );
    }

    return iconWidget;
  }

  Widget _chip(Map<String, dynamic> props) {
    final label = _interpolate(
      props['label'] as String? ?? props['value'] as String? ?? 'Chip',
    );
    final selected = props['selected'] == true;
    final bg = _color(props['color']) ??
        (selected ? const Color(0xFF14120F) : Colors.white);
    final fg = _color(props['textColor']) ??
        (selected ? Colors.white : const Color(0xFF14120F));
    final borderColor = _color(props['borderColor']) ??
        (selected ? Colors.transparent : const Color(0xFFD8D2C6));
    final minHeight = _double(props['minHeight'] ?? props['height'], 44);

    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(_double(props['radius'], 20)),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          color: fg,
          fontSize: _double(props['fontSize'], 13),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _chips(Map<String, dynamic> props, List<Widget> children) {
    var items = children;
    if (items.isEmpty) {
      final raw = props['items'];
      if (raw is List) {
        items = raw.map((e) {
          if (e is String) return _chip({'label': e});
          if (e is Map) return _chip(Map<String, dynamic>.from(e));
          return const SizedBox.shrink();
        }).toList();
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _withGap(
          items,
          _double(props['gap'], 8),
          axis: Axis.horizontal,
        ),
      ),
    );
  }

  Widget _carousel(Map<String, dynamic> props, List<Widget> children) {
    final height = _double(props['height'], 160);
    final gap = _double(props['gap'], 12);
    final responsive = props['responsive'] != false;

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = _layoutWidth(context, constraints);
          final factor = width >= 900
              ? 0.42
              : width >= 600
              ? 0.55
              : 0.82;
          final itemWidth = responsive
              ? _responsiveDouble(
                  props['itemWidth'],
                  width,
                  fallbackFactor: factor,
                )
              : _double(props['itemWidth'], 280);

          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: children.length,
            separatorBuilder: (_, __) => SizedBox(width: gap),
            itemBuilder: (context, index) {
              return SizedBox(
                width: itemWidth,
                height: height,
                child: children[index],
              );
            },
          );
        },
      ),
    );
  }

  Widget _button(Map<String, dynamic> props) {
    final label = _interpolate(props['label'] as String? ?? 'Button');
    return ElevatedButton(onPressed: () {}, child: Text(label));
  }

  /// Resolves a reusable template from [_components].
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

  Widget _stack(Map<String, dynamic> props, List<Widget> children) {
    return Stack(
      alignment:
          _alignment(props['alignment']) ?? AlignmentDirectional.topStart,
      fit: props['fit'] == 'expand' ? StackFit.expand : StackFit.loose,
      clipBehavior: props['clip'] == 'none' ? Clip.none : Clip.hardEdge,
      children: children,
    );
  }

  Widget _positioned(Map<String, dynamic> props, List<Widget> children) {
    return Positioned(
      left: _doubleOrNull(props['left']),
      top: _doubleOrNull(props['top']),
      right: _doubleOrNull(props['right']),
      bottom: _doubleOrNull(props['bottom']),
      width: _doubleOrNull(props['width']),
      height: _doubleOrNull(props['height']),
      child: _singleChild(children),
    );
  }

  Widget _festiveHeader(
    Map<String, dynamic> props, {
    String defaultFestival = 'navratri',
  }) {
    final title = props['title'] as String? ?? 'Delivering to Home';
    final address =
        props['address'] as String? ?? 'Satellite, Ahmedabad 380015';
    final festival =
        (props['festival'] as String? ?? defaultFestival).toLowerCase();
    final isNavratri = festival == 'navratri';
    final isUttarayan = festival == 'uttarayan';
    final isHoli = festival == 'holi';
    final searchHint = props['searchHint'] as String? ??
        (isHoli
            ? 'Search colours, white tees, pichkari'
            : isUttarayan
                ? 'Search kites, manja, sunglasses'
                : isNavratri
                    ? 'Search chaniya choli, jewellery'
                    : 'Search diyas, kurtas, gifts');
    final baseHeight = _double(props['height'], 168);
    final bgImage = props['bgImage'] as String? ??
        (isHoli
            ? 'holi/topbar_holi_v3.gif'
            : isUttarayan
                ? 'uttarayan/topbar_kites_v2.gif'
                : isNavratri
                    ? 'navratri/topbar_animated_v6.gif'
                    : 'diwali/topbar.gif');
    final bgColor = _color(props['bgColor']) ??
        (isHoli
            ? const Color(0xFF2A1245)
            : isUttarayan
                ? const Color(0xFF0B4A6B)
                : isNavratri
                    ? const Color(0xFF2B0B1E)
                    : const Color(0xFF2A1608));

    return Builder(
      builder: (context) {
        final topInset = MediaQuery.paddingOf(context).top;
        final totalHeight = baseHeight + topInset;

        return Container(
          constraints: BoxConstraints(minHeight: totalHeight),
          color: bgColor,
          child: Stack(
            children: [
              Positioned.fill(
                child: bgImage.isNotEmpty
                    ? _buildImageWidget(
                        path: bgImage,
                        fit: _boxFit(props['fit']),
                        alignment: _alignment(props['imageAlignment'] ?? props['alignment']) ??
                            Alignment.center,
                      )
                    : CustomPaint(
                        painter: isHoli
                            ? HoliFestiveArtworkPainter()
                            : isUttarayan
                                ? UttarayanFestiveArtworkPainter()
                                : isNavratri
                                    ? NavratriFestiveArtworkPainter()
                                    : DiwaliFestiveArtworkPainter(),
                      ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.25),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.20),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: baseHeight),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            address,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.search_rounded,
                              size: 20,
                              color: Color(0xFF5A554C),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              searchHint,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                color: const Color(0xFF5A554C),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          ),
        );
      },
    );
  }

  Widget _nineColours(Map<String, dynamic> props) {
    final title = props['title'] as String? ?? 'Nine nights, nine colours';
    final rawColors = props['colors'] as List? ??
        [
          '#E8731A',
          '#FFFFFF',
          '#C8321A',
          '#2A5BD7',
          '#F2C14E',
          '#1B7A3A',
          '#8A8A8A',
          '#7A2FB5',
          '#0B7A75',
        ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFEBE6DC),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF14120F),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final raw in rawColors) ...[
                Builder(
                  builder: (_) {
                    final colorHex = raw.toString().toUpperCase();
                    final color = _color(raw) ?? Colors.transparent;
                    final isWhite =
                        colorHex == '#FFFFFF' ||
                        colorHex == '#FFF' ||
                        color == Colors.white;
                    return Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isWhite
                            ? Border.all(
                                color: const Color(0xFFD8D2C6),
                                width: 1,
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _countdownCard(Map<String, dynamic> props) {
    final title = props['title'] as String? ?? 'Kite day starts in';
    final subtitle = props['subtitle'] as String? ?? 'Order before the rush';
    final targetDate = props['targetDate'] as String?;
    final rawBadges = props['badges'] as List?;
    final badgeColor = _color(props['badgeColor']) ?? const Color(0xFF0B4A6B);

    return LiveCountdownCard(
      title: title,
      subtitle: subtitle,
      targetDate: targetDate,
      fallbackBadges: rawBadges,
      badgeColor: badgeColor,
    );
  }

  Widget _comboCard(Map<String, dynamic> props) {
    final title = props['title'] as String? ?? '';
    final subtitle = props['subtitle'] as String? ?? '';
    final price = props['price'] as String? ?? '';
    final originalPrice = props['originalPrice'] as String?;
    final imageUrl = props['imageUrl'] as String?;
    final imageColor = _color(props['imageColor']) ?? const Color(0xFFEBDDB0);
    final buttonText = props['buttonText'] as String? ?? 'Add';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: imageColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: (imageUrl != null && imageUrl.isNotEmpty)
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _buildImageWidget(path: imageUrl, fit: BoxFit.cover),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: const Color(0xFF14120F),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFF5A554C),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      price,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: const Color(0xFF14120F),
                      ),
                    ),
                    if (originalPrice != null && originalPrice.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        originalPrice,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: const Color(0xFF5A554C),
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFC8321A),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              buttonText,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _productCard(Map<String, dynamic> props) {
    final imageHeight = _double(props['imageHeight'], 120);
    final cardWidth = _doubleOrNull(props['width']);
    final imageColor = _color(props['imageColor']) ?? const Color(0xFFE4DED2);
    final imageUrl = props['imageUrl'] as String?;
    final brand = props['brand'] as String? ?? '';
    final title = props['title'] as String? ?? '';
    final price = props['price'] as String? ?? '';
    final originalPrice = props['originalPrice'] as String?;
    final discount = props['discount'] as String?;
    final fit = _boxFit(props['fit'] ?? props['imageFit']);
    final alignment = _alignment(props['imageAlignment'] ?? props['alignment']) ??
        Alignment.topCenter;

    final cardWidget = Container(
      width: cardWidth,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFEBE6DC),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: imageHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              color: imageColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: (imageUrl != null && imageUrl.isNotEmpty)
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _buildImageWidget(
                      path: imageUrl,
                      fit: fit,
                      alignment: alignment,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 4),
          if (brand.isNotEmpty)
            Text(
              brand,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: const Color(0xFF5A554C),
                fontWeight: FontWeight.w500,
              ),
            ),
          if (title.isNotEmpty)
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF14120F),
              ),
            ),
          const SizedBox(height: 3),
          Row(
            children: [
              if (price.isNotEmpty)
                Text(
                  price,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF14120F),
                  ),
                ),
              if (originalPrice != null && originalPrice.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  originalPrice,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFF5A554C),
                    textStyle: const TextStyle(
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (discount != null && discount.isNotEmpty) ...[
            const SizedBox(height: 1),
            Text(
              discount,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1B7A3A),
              ),
            ),
          ],
        ],
      ),
    );

    return Builder(
      builder: (context) => InkWell(
        onTap: () {
          final isKurta = title.toLowerCase().contains('kurta') ||
              brand.toLowerCase().contains('kurta') ||
              (imageUrl != null && imageUrl.contains('kurta'));
          if (isKurta) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CategoryListingPage(),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$title added to bag!'),
                duration: const Duration(seconds: 1),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: cardWidget,
      ),
    );
  }

  Widget _bottomNav(Map<String, dynamic> props) {
    final activeIndex = _int(props['activeIndex'], 0);
    final rawItems = props['items'];
    final items = rawItems is List
        ? rawItems.map((e) => e.toString()).toList()
        : const ['Home', 'Categories', 'Bag', 'Profile'];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (var i = 0; i < items.length; i++)
              Builder(
                builder: (context) => GestureDetector(
                  onTap: () {
                    final item = items[i];
                    if (item == 'Categories' || item == 'Kurtas') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CategoryListingPage(),
                        ),
                      );
                    } else if (item == 'Home') {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$item tapped'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Text(
                      items[i],
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: i == activeIndex
                            ? const Color(0xFFC8321A)
                            : const Color(0xFF5A554C),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Fail-safe unknown type: never crashes; invisible in production.
  ///
  /// Only when `asLayout: true` (explicit schema opt-in) unknown nodes with
  /// children are rendered as a generic column.
  Widget _unknown(
    String type,
    Map<String, dynamic> props,
    List<Widget> children,
  ) {
    _log('Unknown SDUI type: $type');

    if (props['asLayout'] == true && children.isNotEmpty) {
      return _column({
        'gap': props['gap'] ?? 0,
        'padding': props['padding'],
        'mainAxisAlignment': props['mainAxisAlignment'],
        'crossAxisAlignment': props['crossAxisAlignment'],
        'mainAxisSize': props['mainAxisSize'],
      }, children);
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

  Map<String, dynamic> _props(Map<String, dynamic> node) {
    final raw = node['props'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return Map<String, dynamic>.from(node)
      ..remove('type')
      ..remove('children')
      ..remove('child');
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
}

/// Replicates the exact decorative festive lights + diya artwork from Main.dc.html.
/// Coordinates are scaled proportionally from the 390x168 viewBox.
class DiwaliFestiveArtworkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 390.0;
    final sy = size.height / 168.0;

    // 1. Hanging garland string: M0 18 Q100 60 200 20 T390 30
    final wirePaint = Paint()
      ..color = const Color(0xFF7A4A1E)
      ..strokeWidth = 2.0 * sy
      ..style = PaintingStyle.stroke;

    final wirePath = Path()
      ..moveTo(0, 18 * sy)
      ..quadraticBezierTo(100 * sx, 60 * sy, 200 * sx, 20 * sy)
      ..quadraticBezierTo(300 * sx, -20 * sy, 390 * sx, 30 * sy);
    canvas.drawPath(wirePath, wirePaint);

    // 2. Festive golden light beads / lanterns
    final bulbPaint = Paint()
      ..color = const Color(0xFFF5B83D)
      ..style = PaintingStyle.fill;

    final bulbs = [
      Offset(50 * sx, 38 * sy),
      Offset(120 * sx, 44 * sy),
      Offset(200 * sx, 22 * sy),
      Offset(280 * sx, 32 * sy),
      Offset(350 * sx, 36 * sy),
    ];
    for (final bulb in bulbs) {
      canvas.drawCircle(bulb, 6 * sx, bulbPaint);
    }

    // 3. Terracotta Diya base: M300 150 Q340 120 380 150Z
    final diyaPaint = Paint()
      ..color = const Color(0xFFB4440A)
      ..style = PaintingStyle.fill;

    final diyaPath = Path()
      ..moveTo(300 * sx, 150 * sy)
      ..quadraticBezierTo(340 * sx, 120 * sy, 380 * sx, 150 * sy)
      ..close();
    canvas.drawPath(diyaPath, diyaPaint);

    // 4. Diya Flame: M340 118 Q330 100 340 86 Q352 100 340 118Z
    final flamePath = Path()
      ..moveTo(340 * sx, 118 * sy)
      ..quadraticBezierTo(330 * sx, 100 * sy, 340 * sx, 86 * sy)
      ..quadraticBezierTo(352 * sx, 100 * sy, 340 * sx, 118 * sy)
      ..close();
    canvas.drawPath(flamePath, bulbPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Replicates the decorative kites, sky ellipses and manja threads from Uttarayan.dc.html.
class UttarayanFestiveArtworkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 390.0;
    final sy = size.height / 168.0;

    final cloudPaint = Paint()
      ..color = const Color(0xFF1B6A93)
      ..style = PaintingStyle.fill;

    // Ellipse 1: cx="60" cy="150" rx="70" ry="14"
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(60 * sx, 150 * sy),
        width: 140 * sx,
        height: 28 * sy,
      ),
      cloudPaint,
    );

    // Ellipse 2: cx="320" cy="140" rx="80" ry="16"
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(320 * sx, 140 * sy),
        width: 160 * sx,
        height: 32 * sy,
      ),
      cloudPaint,
    );

    // Kite 1 (Yellow): M300 20l22 28-22 28-22-28z
    final kite1Paint = Paint()
      ..color = const Color(0xFFF2C14E)
      ..style = PaintingStyle.fill;
    final kite1 = Path()
      ..moveTo(300 * sx, 20 * sy)
      ..lineTo(322 * sx, 48 * sy)
      ..lineTo(300 * sx, 76 * sy)
      ..lineTo(278 * sx, 48 * sy)
      ..close();
    canvas.drawPath(kite1, kite1Paint);

    // Kite 2 (Orange): M340 70l16 20-16 20-16-20z
    final kite2Paint = Paint()
      ..color = const Color(0xFFE4572E)
      ..style = PaintingStyle.fill;
    final kite2 = Path()
      ..moveTo(340 * sx, 70 * sy)
      ..lineTo(356 * sx, 90 * sy)
      ..lineTo(340 * sx, 110 * sy)
      ..lineTo(324 * sx, 90 * sy)
      ..close();
    canvas.drawPath(kite2, kite2Paint);

    // Kite 3 (White): M250 40l14 18-14 18-14-18z
    final kite3Paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final kite3 = Path()
      ..moveTo(250 * sx, 40 * sy)
      ..lineTo(264 * sx, 58 * sy)
      ..lineTo(250 * sx, 76 * sy)
      ..lineTo(236 * sx, 58 * sy)
      ..close();
    canvas.drawPath(kite3, kite3Paint);

    // Thread paths:
    // M300 76Q290 110 310 140
    // M340 110Q330 130 345 160
    // M250 76Q245 100 255 120
    final threadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5 * sy
      ..style = PaintingStyle.stroke;

    final threads = Path()
      ..moveTo(300 * sx, 76 * sy)
      ..quadraticBezierTo(290 * sx, 110 * sy, 310 * sx, 140 * sy)
      ..moveTo(340 * sx, 110 * sy)
      ..quadraticBezierTo(330 * sx, 130 * sy, 345 * sx, 160 * sy)
      ..moveTo(250 * sx, 76 * sy)
      ..quadraticBezierTo(245 * sx, 100 * sy, 255 * sx, 120 * sy);
    canvas.drawPath(threads, threadPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Replicates the decorative Garba concentric circles and Dandiya sticks from Navratri.dc.html.
class NavratriFestiveArtworkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 390.0;
    final sy = size.height / 168.0;

    // 1. Concentric circles at (330, 84)
    final circlePaint = Paint()
      ..color = const Color(0xFFE8A3C4).withValues(alpha: 0.6)
      ..strokeWidth = 2.0 * sy
      ..style = PaintingStyle.stroke;

    final center = Offset(330 * sx, 84 * sy);
    canvas.drawCircle(center, 70 * sx, circlePaint);
    canvas.drawCircle(center, 50 * sx, circlePaint);
    canvas.drawCircle(center, 30 * sx, circlePaint);

    // 2. Center bead: (330, 84) radius 8, fill #F2C14E
    final centerBeadPaint = Paint()
      ..color = const Color(0xFFF2C14E)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 8 * sx, centerBeadPaint);

    // 3. Dandiya stick 1: rect x="230" y="20" width="10" height="80" rx="5" fill="#F2C14E" transform="rotate(30 235 60)"
    canvas.save();
    canvas.translate(235 * sx, 60 * sy);
    canvas.rotate(30 * 3.141592653589793 / 180);
    canvas.translate(-235 * sx, -60 * sy);
    final stick1Paint = Paint()
      ..color = const Color(0xFFF2C14E)
      ..style = PaintingStyle.fill;
    final rrect1 = RRect.fromRectAndRadius(
      Rect.fromLTWH(230 * sx, 20 * sy, 10 * sx, 80 * sy),
      Radius.circular(5 * sx),
    );
    canvas.drawRRect(rrect1, stick1Paint);
    canvas.restore();

    // 4. Dandiya stick 2: rect x="262" y="20" width="10" height="80" rx="5" fill="#E8A3C4" transform="rotate(-25 267 60)"
    canvas.save();
    canvas.translate(267 * sx, 60 * sy);
    canvas.rotate(-25 * 3.141592653589793 / 180);
    canvas.translate(-267 * sx, -60 * sy);
    final stick2Paint = Paint()
      ..color = const Color(0xFFE8A3C4)
      ..style = PaintingStyle.fill;
    final rrect2 = RRect.fromRectAndRadius(
      Rect.fromLTWH(262 * sx, 20 * sy, 10 * sx, 80 * sy),
      Radius.circular(5 * sx),
    );
    canvas.drawRRect(rrect2, stick2Paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Replicates the decorative colour splash circles from Holi.dc.html.
class HoliFestiveArtworkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 390.0;
    final sy = size.height / 168.0;

    // 1. Magenta circle: cx="340" cy="30" r="46" fill="#E4357A"
    canvas.drawCircle(
      Offset(340 * sx, 30 * sy),
      46 * sx,
      Paint()
        ..color = const Color(0xFFE4357A)
        ..style = PaintingStyle.fill,
    );

    // 2. Yellow circle: cx="290" cy="110" r="38" fill="#F2A900"
    canvas.drawCircle(
      Offset(290 * sx, 110 * sy),
      38 * sx,
      Paint()
        ..color = const Color(0xFFF2A900)
        ..style = PaintingStyle.fill,
    );

    // 3. Teal circle: cx="360" cy="130" r="30" fill="#2DB5A0"
    canvas.drawCircle(
      Offset(360 * sx, 130 * sy),
      30 * sx,
      Paint()
        ..color = const Color(0xFF2DB5A0)
        ..style = PaintingStyle.fill,
    );

    // 4. Green circle: cx="240" cy="40" r="20" fill="#7AC74F"
    canvas.drawCircle(
      Offset(240 * sx, 40 * sy),
      20 * sx,
      Paint()
        ..color = const Color(0xFF7AC74F)
        ..style = PaintingStyle.fill,
    );

    // 5. Small yellow circle: cx="200" cy="130" r="12" fill="#F2A900"
    canvas.drawCircle(
      Offset(200 * sx, 130 * sy),
      12 * sx,
      Paint()
        ..color = const Color(0xFFF2A900)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LiveCountdownCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String? targetDate;
  final List<dynamic>? fallbackBadges;
  final Color badgeColor;

  const LiveCountdownCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.targetDate,
    this.fallbackBadges,
    required this.badgeColor,
  });

  @override
  State<LiveCountdownCard> createState() => _LiveCountdownCardState();
}

class _LiveCountdownCardState extends State<LiveCountdownCard> {
  Timer? _timer;
  late DateTime _target;

  @override
  void initState() {
    super.initState();
    _initTarget();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _initTarget() {
    if (widget.targetDate != null && widget.targetDate!.isNotEmpty) {
      try {
        _target = DateTime.parse(widget.targetDate!);
        return;
      } catch (_) {}
    }
    // Default to next Uttarayan (Jan 14, 06:00 AM)
    final now = DateTime.now();
    int targetYear = now.year;
    final thisYearTarget = DateTime(targetYear, 1, 14, 6, 0, 0);
    if (now.isAfter(thisYearTarget)) {
      targetYear += 1;
    }
    _target = DateTime(targetYear, 1, 14, 6, 0, 0);
  }

  @override
  void didUpdateWidget(covariant LiveCountdownCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetDate != widget.targetDate) {
      _initTarget();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<String> _calculateBadges() {
    final now = DateTime.now();
    final diff = _target.difference(now);
    if (diff.isNegative || diff.inSeconds <= 0) {
      return ['00 d', '00 h', '00 m', '00 s'];
    }

    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;
    final seconds = diff.inSeconds % 60;

    return [
      '${days.toString().padLeft(2, '0')} d',
      '${hours.toString().padLeft(2, '0')} h',
      '${minutes.toString().padLeft(2, '0')} m',
      '${seconds.toString().padLeft(2, '0')} s',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final badges = _calculateBadges();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFEBE6DC),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF14120F),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFF5A554C),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final b in badges) ...[
                Container(
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: widget.badgeColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    b,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

