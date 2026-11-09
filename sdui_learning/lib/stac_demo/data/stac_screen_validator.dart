import 'package:stac/stac.dart';

/// Result of checking a Stac widget tree before it is rendered.
class StacScreenValidation {
  const StacScreenValidation.ok() : message = null;

  const StacScreenValidation.failed(this.message);

  final String? message;

  bool get isValid => message == null;
}

/// Rejects screen JSON that Stac 1.5.0 cannot render safely.
///
/// Built-in widget names come from [WidgetType] in the resolved `stac_core`.
/// `productDiscountBadge` is the one custom type registered by this demo.
///
/// Stac itself can render `dynamicView`, `networkWidget`, and
/// `networkRequest`, and those calls can target any URL embedded in the
/// JSON. This demo blocks them. Navigation by `routeName` is also blocked
/// because in 1.5.0 that path loads a Stac Cloud screen and requires
/// [StacOptions].
class StacScreenValidator {
  const StacScreenValidator();

  static const customWidgetType = 'productDiscountBadge';

  static const _blockedWidgets = {'dynamicView', 'networkWidget'};

  static const _allowedActions = {
    'showSnackBar',
    'navigate',
    'none',
    'showDialog',
    'showModalBottomSheet',
    'multiAction',
    'delay',
    'setValue',
    'getFormValue',
    'validateForm',
  };

  static const _widgetSlots = {
    'child',
    'children',
    'appBar',
    'body',
    'title',
    'leading',
    'flexibleSpace',
    'bottom',
    'floatingActionButton',
    'drawer',
    'endDrawer',
    'bottomNavigationBar',
    'label',
    'avatar',
    'deleteIcon',
    'icon',
    'prefixIcon',
    'suffixIcon',
    'persistentFooterButtons',
    'slivers',
    'tabs',
    'widget',
    'widgetJson',
    'content',
  };

  static const _secretKeys = {
    'authorization',
    'apikey',
    'api_key',
    'password',
    'secret',
    'token',
    'credential',
    'credentials',
    'privatekey',
    'private_key',
  };

  static final Set<String> _builtInWidgets = WidgetType.values
      .map((type) => type.name)
      .toSet();

  StacScreenValidation validate(
    Map<String, dynamic> screen, {
    bool rejectUnknownWidgets = true,
  }) {
    try {
      final failure = _inspect(
        screen,
        depth: 0,
        nodes: _NodeBudget(),
        mustBeWidget: true,
        rejectUnknownWidgets: rejectUnknownWidgets,
      );
      if (failure != null) {
        return StacScreenValidation.failed(failure);
      }
      return const StacScreenValidation.ok();
    } catch (_) {
      return const StacScreenValidation.failed(
        'Screen JSON could not be checked.',
      );
    }
  }

  String? _inspect(
    dynamic node, {
    required int depth,
    required _NodeBudget nodes,
    required bool mustBeWidget,
    required bool rejectUnknownWidgets,
    String slot = 'screen',
  }) {
    if (!nodes.take()) {
      return 'Screen JSON has too many nodes.';
    }
    if (depth > 32) {
      return 'Screen JSON is nested too deeply.';
    }

    if (node is List) {
      for (final item in node) {
        final failure = _inspect(
          item,
          depth: depth + 1,
          nodes: nodes,
          mustBeWidget: mustBeWidget,
          rejectUnknownWidgets: rejectUnknownWidgets,
          slot: slot,
        );
        if (failure != null) return failure;
      }
      return null;
    }

    // Numbers and strings are style fields (padding.bottom, icon names).
    // Widget objects and lists are checked below.
    if (node is! Map) {
      return null;
    }

    final map = Map<String, dynamic>.from(node);
    final secret = _secretKey(map);
    if (secret != null) {
      return 'Screen JSON must not contain "$secret".';
    }
    if (map['request'] is Map) {
      return 'Network requests inside screen JSON are not allowed.';
    }
    if (map['imageType'] == 'file') {
      return 'File images are not allowed in screen JSON.';
    }

    final actionType = map['actionType'];
    if (actionType != null) {
      final actionFailure = _checkAction(map, actionType);
      if (actionFailure != null) return actionFailure;
    }

    final type = map['type'];
    if (mustBeWidget) {
      if (type is! String || type.isEmpty) {
        return '$slot is missing a widget type.';
      }
      final typeFailure = _checkWidgetType(
        type,
        rejectUnknownWidgets: rejectUnknownWidgets,
      );
      if (typeFailure != null) return typeFailure;
      final widgetFailure = _checkWidget(map, type);
      if (widgetFailure != null) return widgetFailure;
    } else if (type is String && _builtInWidgets.contains(type)) {
      final widgetFailure = _checkWidget(map, type);
      if (widgetFailure != null) return widgetFailure;
    }

    for (final entry in map.entries) {
      final childIsAction =
          entry.key.startsWith('on') ||
          (actionType == 'multiAction' && entry.key == 'actions');
      if (childIsAction) {
        final failure = _inspectAction(
          entry.value,
          depth: depth + 1,
          nodes: nodes,
          rejectUnknownWidgets: rejectUnknownWidgets,
        );
        if (failure != null) return failure;
        continue;
      }

      final childMustBeWidget =
          _widgetSlots.contains(entry.key) ||
          (type == 'appBar' && entry.key == 'actions');
      final failure = _inspect(
        entry.value,
        depth: depth + 1,
        nodes: nodes,
        mustBeWidget: childMustBeWidget,
        rejectUnknownWidgets: rejectUnknownWidgets,
        slot: entry.key,
      );
      if (failure != null) return failure;
    }
    return null;
  }

  String? _inspectAction(
    dynamic node, {
    required int depth,
    required _NodeBudget nodes,
    required bool rejectUnknownWidgets,
  }) {
    if (node == null) return null;
    if (node is! Map) return 'An action must be a JSON object.';
    if (node['actionType'] == null) {
      return 'An action is missing actionType.';
    }
    return _inspect(
      node,
      depth: depth,
      nodes: nodes,
      mustBeWidget: false,
      rejectUnknownWidgets: rejectUnknownWidgets,
      slot: 'action',
    );
  }

  String? _checkAction(Map<String, dynamic> map, Object? actionType) {
    if (actionType is! String) {
      return 'actionType must be a string.';
    }
    if (actionType == 'networkRequest') {
      return 'networkRequest actions are not allowed in screen JSON.';
    }
    if (!_allowedActions.contains(actionType)) {
      return 'Action "$actionType" is not supported.';
    }
    if (actionType == 'navigate') {
      final routeName = map['routeName'];
      if (routeName is String && routeName.isNotEmpty) {
        return 'routeName navigation is disabled. '
            'Stac 1.5.0 sends that to Stac Cloud.';
      }
      final assetPath = map['assetPath'];
      if (assetPath != null && !_allowedAssetPath(assetPath)) {
        return 'Navigate assetPath must stay under assets/sdui/stac/.';
      }
    }
    return null;
  }

  String? _checkWidgetType(String type, {required bool rejectUnknownWidgets}) {
    if (type == customWidgetType) return null;
    if (_blockedWidgets.contains(type)) {
      return 'Widget "$type" can fetch arbitrary URLs and is blocked.';
    }
    if (_builtInWidgets.contains(type)) return null;
    if (!rejectUnknownWidgets) return null;
    return 'Widget "$type" is not registered in Stac 1.5.0. '
        'Adding it requires a Dart parser and a new app release.';
  }

  String? _checkWidget(Map<String, dynamic> map, String type) {
    if (type != 'image') return null;
    final imageType = map['imageType'];
    if (imageType != null && imageType != 'network' && imageType != 'asset') {
      return 'Image type "$imageType" is not allowed.';
    }
    final src = map['src'];
    if (src is! String || src.isEmpty) {
      return 'An image is missing src.';
    }
    if (src.contains('..')) {
      return 'Image src cannot contain "..".';
    }
    if (imageType == 'asset' || src.startsWith('assets/')) {
      if (!src.startsWith('assets/')) {
        return 'Asset images must use an assets/ path.';
      }
      return null;
    }
    final uri = Uri.tryParse(src);
    if (uri == null || !uri.isAbsolute || uri.scheme != 'https') {
      return 'Network images must use an https URL.';
    }
    return null;
  }

  String? _secretKey(Map<String, dynamic> map) {
    for (final key in map.keys) {
      final normalized = key.toLowerCase().replaceAll('-', '');
      if (_secretKeys.contains(normalized)) return key;
    }
    return null;
  }

  bool _allowedAssetPath(Object? assetPath) {
    if (assetPath is! String) return false;
    return assetPath.startsWith('assets/sdui/stac/') &&
        !assetPath.contains('..');
  }
}

class _NodeBudget {
  int _count = 0;

  bool take() {
    _count += 1;
    return _count <= 2000;
  }
}
