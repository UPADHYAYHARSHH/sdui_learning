part of 'dynamic_layout_builder.dart';

mixin _SduiCommerceBuilders on _SduiBuilderCore {
  Widget _searchBar(Map<String, dynamic> props) {
    final hint = _interpolate(props['hint'] as String? ?? 'Search...');
    final fill = _color(props['color']) ?? const Color(0xFF1E1E24);
    final radius = _double(props['radius'], 14);
    final action = props['action'] as String? ?? 'open_search';

    return Builder(
      builder: (context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: () => _dispatchTapAction(context, action, {
            ...props,
            'searchHint': hint,
            'hint': hint,
          }),
          child: Container(
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
          ),
        ),
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
            } else {
              _dispatchTapAction(context, action, props);
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

    final chipWidget = Container(
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

    return Builder(
      builder: (context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            final action = props['action'] as String? ?? 'select_category';
            final category = props['category'] as String? ?? label;
            _dispatchTapAction(context, action, {
              'action': action,
              'category': category,
              'label': label,
              ...props,
            });
          },
          borderRadius: BorderRadius.circular(_double(props['radius'], 20)),
          child: chipWidget,
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
    final label = _interpolate(
      props['label'] as String? ?? props['text'] as String? ?? 'Button',
    );
    final action = props['action'] as String? ?? props['onTap'] as String?;
    final bg = _color(props['backgroundColor'] ?? props['color']) ??
        const Color(0xFF14120F);
    final fg = _color(props['textColor'] ?? props['foregroundColor']) ??
        Colors.white;
    final radius = _double(props['radius'] ?? props['borderRadius'], 12.0);
    final padding = _edgeInsets(
      props['padding'] ?? {'top': 14, 'bottom': 14, 'left': 20, 'right': 20},
    );
    final fullWidth = props['fullWidth'] == true || props['expand'] == true;

    final btn = Builder(
      builder: (context) => ElevatedButton(
        onPressed: action != null
            ? () => _dispatchTapAction(context, action, props)
            : () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: _double(props['elevation'], 0),
          padding: padding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: _double(props['fontSize'], 14.0),
            fontWeight:
                props['bold'] == true ? FontWeight.w800 : FontWeight.w700,
            color: fg,
          ),
        ),
      ),
    );

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: btn);
    }
    return btn;
  }

  /// Resolves a reusable template from [_components].
  Widget _comboCard(Map<String, dynamic> props) {
    final title = props['title'] as String? ?? '';
    final subtitle = props['subtitle'] as String? ?? '';
    final price = props['price'] as String? ?? '';
    final originalPrice = props['originalPrice'] as String?;
    final imageUrl = props['imageUrl'] as String?;
    final imageColor = _color(props['imageColor']) ?? const Color(0xFFEBDDB0);
    final buttonText = props['buttonText'] as String? ?? 'Add';

    final comboWidget = Container(
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

    return Builder(
      builder: (context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _openSduiProductDetail(
              context,
              ProductDetailData(
                title: title,
                brand: 'Festive Combo',
                subtitle: subtitle,
                priceText: price,
                originalPriceText: originalPrice,
                imageUrl: imageUrl,
                imageColor: imageColor,
              ),
            ),
            child: comboWidget,
          ),
        ),
      ),
    );
  }

  void _openSduiProductDetail(
    BuildContext context,
    ProductDetailData detail,
  ) {
    showProductDetailCard(
      context,
      detail,
      onActionPressed: (selectedSize) {
        final slug = '${detail.brand}_${detail.title}_${selectedSize ?? ''}'
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '_');
        ShoppingBagStore.instance.addItem(
          CheckoutItem.fromDetail(
            'sdui_$slug',
            detail,
            size: selectedSize,
          ),
        );
        final sizeNote = selectedSize != null ? ' (Size $selectedSize)' : '';
        final navigator = Navigator.of(context);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('${detail.title.trim()}$sizeNote added to bag!'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'View Bag',
                onPressed: () {
                  navigator.push(
                    MaterialPageRoute(builder: (_) => const CheckoutPage()),
                  );
                },
              ),
            ),
          );
      },
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
      builder: (context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openSduiProductDetail(
              context,
              ProductDetailData(
                title: title,
                brand: brand,
                priceText: price,
                originalPriceText: originalPrice,
                discountText: discount,
                imageUrl: imageUrl,
                imageColor: imageColor,
                sizes: inferProductSizes(title, props['sizes']),
              ),
            ),
            borderRadius: BorderRadius.circular(12),
            child: cardWidget,
          ),
        ),
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
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5DFD3))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SafeArea(
        top: false,
        child: AnimatedBuilder(
          animation: ShoppingBagStore.instance,
          builder: (context, _) {
            final bagCount = ShoppingBagStore.instance.totalQuantity;
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (var i = 0; i < items.length; i++)
                  Builder(
                    builder: (context) => GestureDetector(
                      onTap: () {
                        final item = items[i];
                        final action = switch (item) {
                          'Categories' || 'Kurtas' => 'open_category',
                          'Bag' => 'open_checkout',
                          'Home' => 'home',
                          'Profile' => 'open_profile',
                          _ => item.toLowerCase(),
                        };
                        _dispatchTapAction(context, action, {
                          ...props,
                          'label': item,
                          if (item == 'Categories' || item == 'Kurtas')
                            'category': 'Kurtas',
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              items[i],
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: i == activeIndex
                                    ? const Color(0xFFC8321A)
                                    : const Color(0xFF5A554C),
                              ),
                            ),
                            if (items[i] == 'Bag' && bagCount > 0) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFC8321A),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$bagCount',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
