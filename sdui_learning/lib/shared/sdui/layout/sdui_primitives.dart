part of 'dynamic_layout_builder.dart';

mixin _SduiPrimitiveBuilders on _SduiBuilderCore {
  Widget _column(Map<String, dynamic> props, List<Widget> children) {
    final colWidget = Padding(
      padding: _edgeInsets(props['padding']),
      child: Column(
        mainAxisSize: _mainAxisSize(props['mainAxisSize']),
        mainAxisAlignment: _mainAxisAlignment(props['mainAxisAlignment']),
        crossAxisAlignment: _crossAxisAlignment(props['crossAxisAlignment']),
        children: _withGap(children, _double(props['gap'], 0)),
      ),
    );

    final action = props['action'] as String? ?? props['onTap'] as String?;
    if (action != null) {
      return Builder(
        builder: (context) => InkWell(
          onTap: () => _dispatchTapAction(context, action, props),
          child: colWidget,
        ),
      );
    }

    return colWidget;
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
            onTap: () => _dispatchTapAction(context, action, props),
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

    final textWidget = Text(
      value,
      textAlign: align,
      maxLines: _intOrNull(props['maxLines']),
      overflow: props['overflow'] == 'ellipsis' ? TextOverflow.ellipsis : null,
      style: GoogleFonts.plusJakartaSans(textStyle: baseStyle),
    );

    final action = props['action'] as String? ?? props['onTap'] as String?;
    final effectiveAction = action ??
        (value.trim().toLowerCase() == 'see all' ? 'see_all' : null);

    if (effectiveAction != null) {
      return Builder(
        builder: (context) => MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _dispatchTapAction(context, effectiveAction, props),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: textWidget,
              ),
            ),
          ),
        ),
      );
    }

    return textWidget;
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

  Widget _divider(Map<String, dynamic> props, _) {
    final height = _double(props['height'], 1.0);
    final thickness = _double(props['thickness'], 1.0);
    final color = _color(props['color']) ?? const Color(0xFFE5DFD3);
    final indent = _double(props['indent'], 0.0);
    final endIndent = _double(props['endIndent'], 0.0);
    return Divider(
      height: height,
      thickness: thickness,
      color: color,
      indent: indent,
      endIndent: endIndent,
    );
  }

  Widget _expansionTile(Map<String, dynamic> props, List<Widget> children) {
    final title = _interpolate(props['title'] as String? ?? '');
    final subtitle = _interpolate(props['subtitle'] as String? ?? '');
    final initiallyExpanded = props['initiallyExpanded'] == true;
    final color = _color(props['color']) ?? Colors.white;
    final radius = _double(props['radius'], 14.0);
    final borderColor = _color(props['borderColor']) ?? const Color(0xFFE5DFD3);
    final iconName = props['icon']?.toString().toLowerCase();

    return Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: _edgeInsets(
            props['tilePadding'] ?? {'left': 14, 'right': 14},
          ),
          collapsedIconColor:
              _color(props['iconColor']) ?? const Color(0xFF5A554C),
          iconColor: const Color(0xFF14120F),
          leading: iconName != null
              ? Icon(
                  iconName.contains('terminal')
                      ? Icons.terminal
                      : Icons.info_outline,
                  size: 18,
                  color: const Color(0xFF5A554C),
                )
              : null,
          title: Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: _double(props['titleFontSize'], 12.0),
              fontWeight: FontWeight.w700,
              color: _color(props['titleColor']) ?? const Color(0xFF5A554C),
            ),
          ),
          subtitle: subtitle.isNotEmpty
              ? Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: _double(props['subtitleFontSize'], 10.0),
                    color: _color(props['subtitleColor']) ??
                        const Color(0xFF5A554C),
                  ),
                )
              : null,
          childrenPadding: _edgeInsets(
            props['childrenPadding'] ??
                {'left': 14, 'right': 14, 'bottom': 14},
          ),
          children: children,
        ),
      ),
    );
  }

  Widget _selectableText(Map<String, dynamic> props) {
    final raw = props['value'] as String? ?? props['text'] as String? ?? '';
    final value = _interpolate(raw);
    final size = _double(props['fontSize'], 11);
    final color = _color(props['color']) ?? const Color(0xFF14120F);
    final isMono =
        props['monospace'] == true || props['fontFamily'] == 'monospace';

    return SelectableText(
      value,
      style: isMono
          ? TextStyle(
              fontFamily: 'monospace',
              fontSize: size,
              color: color,
              height: _double(props['height'], 1.35),
            )
          : GoogleFonts.plusJakartaSans(
              fontSize: size,
              fontWeight: _fontWeight(props),
              color: color,
              height: _doubleOrNull(props['height']),
            ),
    );
  }
}
