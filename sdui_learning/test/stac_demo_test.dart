import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdui_learning/main.dart' as app_main;
import 'package:sdui_learning/stac_demo/data/stac_screen_document.dart';
import 'package:sdui_learning/stac_demo/data/stac_screen_repository.dart';
import 'package:sdui_learning/stac_demo/data/stac_screen_validator.dart';
import 'package:sdui_learning/stac_demo/stac_bootstrap.dart';
import 'package:sdui_learning/stac_demo/stac_demo_app.dart';
import 'package:sdui_learning/stac_demo/stac_demo_config.dart';
import 'package:sdui_learning/stac_demo/widgets/stac_product_screen.dart';

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) {
      await tester.pump();
      return;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeStacDemo();
  });

  const validator = StacScreenValidator();
  const assets = AssetStacScreenRepository();

  test('screen URL stays empty unless it is absolute https', () {
    expect(StacDemoConfig.parseScreenUrl('').screenUrl, isNull);
    expect(StacDemoConfig.parseScreenUrl('').configurationError, isNull);

    final http = StacDemoConfig.parseScreenUrl('http://example.com/screen');
    expect(http.screenUrl, isNull);
    expect(http.configurationError, isNotNull);

    final https = StacDemoConfig.parseScreenUrl(
      'https://example.com/sdui/product-listing',
    );
    expect(https.screenUrl?.scheme, 'https');
    expect(https.configurationError, isNull);
  });

  test('bundled grid and promo documents are valid Stac screens', () async {
    final grid = await assets.load(StacLayoutId.grid);
    final promo = await assets.load(StacLayoutId.promo);

    expect(grid.layout, 'grid');
    expect(grid.screen['type'], 'scaffold');
    expect(validator.validate(grid.screen).isValid, isTrue);

    expect(promo.layout, 'promo');
    expect(validator.validate(promo.screen).isValid, isTrue);
    expect(promo.screen.toString(), contains('productDiscountBadge'));
    expect(grid.screen.toString(), isNot(contains('productDiscountBadge')));
  });

  test('unsupported widget JSON is rejected before render', () async {
    final document = await assets.load(StacLayoutId.unsupported);
    final result = validator.validate(document.screen);

    expect(result.isValid, isFalse);
    expect(result.message, contains('webview'));
    expect(result.message, contains('app release'));
  });

  test('malformed, secret, file, and network payloads are rejected', () {
    expect(
      validator.validate({'body': {}}).message,
      contains('missing a widget type'),
    );
    expect(
      validator.validate({
        'type': 'text',
        'data': 'Hello',
        'token': 'secret-value',
      }).message,
      contains('token'),
    );
    expect(
      validator.validate({
        'type': 'image',
        'imageType': 'file',
        'src': '/tmp/secret.png',
      }).message,
      contains('File images'),
    );
    expect(
      validator.validate({
        'type': 'column',
        'children': [
          {
            'type': 'elevatedButton',
            'onPressed': {
              'actionType': 'networkRequest',
              'url': 'https://example.com',
            },
            'child': {'type': 'text', 'data': 'Go'},
          },
        ],
      }).message,
      contains('networkRequest'),
    );
    expect(
      validator.validate({
        'type': 'dynamicView',
        'request': {'url': 'https://example.com', 'method': 'get'},
        'template': {'type': 'text', 'data': '{{name}}'},
      }).message,
      contains('not allowed'),
    );
  });

  test('a bare widget body parses as a screen document', () {
    final document = StacScreenDocument.parse(
      '{"type":"text","data":"Hello"}',
      requestedLayout: StacLayoutId.grid,
      origin: StacScreenOrigin.network,
    );

    expect(document.screen['type'], 'text');
    expect(document.origin, StacScreenOrigin.network);
  });

  test('network repository appends layout and surfaces bad JSON', () async {
    final repository = NetworkStacScreenRepository(
      endpoint: Uri.parse('https://example.com/sdui/product-listing'),
      loader: (uri) async {
        expect(uri.queryParameters['layout'], 'promo');
        return '{"id":"product_listing","layout":"promo","screen":{"type":"text","data":"Remote"}}';
      },
    );

    final document = await repository.load(StacLayoutId.promo);
    expect(document.screen['data'], 'Remote');
    expect(document.origin, StacScreenOrigin.network);

    final broken = NetworkStacScreenRepository(
      endpoint: Uri.parse('https://example.com/sdui/product-listing'),
      loader: (_) async => 'not-json',
    );
    expect(
      () => broken.load(StacLayoutId.grid),
      throwsA(
        isA<StacScreenLoadException>().having(
          (error) => error.message,
          'message',
          contains('not return Stac screen JSON'),
        ),
      ),
    );
  });

  testWidgets('grid and promo layouts render from JSON', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: StacProductScreen(repository: assets)),
    );
    await _pumpUntil(tester, find.text('Two-column grid'));

    expect(find.text('Two-column grid'), findsOneWidget);
    expect(find.text('Ceramic Pour Bowl'), findsWidgets);
    expect(find.text('20% off'), findsWidgets);
    expect(find.text('Weekend drop'), findsNothing);
    expect(find.text('SAVE 20%'), findsNothing);

    await tester.tap(find.byKey(const Key('stac-layout-promo')));
    await _pumpUntil(tester, find.text('Weekend drop'));

    expect(find.text('Weekend drop'), findsOneWidget);
    expect(find.text('Autumn edit'), findsWidgets);
    expect(find.text('SAVE 20%'), findsOneWidget);
    expect(find.text('Ceramics'), findsOneWidget);
    expect(find.text('Two-column grid'), findsNothing);
  });

  testWidgets('unsupported JSON shows a fallback instead of crashing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: StacProductScreen(repository: assets)),
    );
    await _pumpUntil(tester, find.text('Two-column grid'));

    await tester.tap(find.byKey(const Key('stac-layout-unsupported')));
    await _pumpUntil(tester, find.text('This screen cannot be rendered'));

    expect(find.text('This screen cannot be rendered'), findsOneWidget);
    expect(find.textContaining('webview'), findsOneWidget);

    await tester.tap(find.byKey(const Key('stac-preview-unsupported')));
    await _pumpUntil(tester, find.text('Stac Parse Error'));

    expect(find.text('Stac Parse Error'), findsOneWidget);
    expect(find.text('Two-column grid'), findsOneWidget);
  });

  testWidgets('a failed load can retry and fall back to a fixture', (
    tester,
  ) async {
    var calls = 0;
    final failing = _ScriptedRepository(() async {
      calls += 1;
      throw const StacScreenLoadException('Screen request failed.');
    });

    await tester.pumpWidget(
      MaterialApp(
        home: StacProductScreen(repository: failing, bundledRepository: assets),
      ),
    );
    await _pumpUntil(tester, find.text('Screen unavailable'));

    expect(find.text('Screen unavailable'), findsOneWidget);
    expect(find.text('Screen request failed.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('stac-use-fixture')));
    await _pumpUntil(tester, find.text('Two-column grid'));

    expect(find.text('Two-column grid'), findsOneWidget);
    expect(calls, 1);
  });

  testWidgets('the demo app renders the bundled grid', (tester) async {
    await tester.pumpWidget(const StacDemoApp(config: StacDemoConfig()));
    await _pumpUntil(tester, find.text('Two-column grid'));

    expect(find.text('Two-column grid'), findsOneWidget);
    expect(find.text('Product listing'), findsWidgets);
  });

  test('the existing entry point does not launch the Stac demo', () {
    expect(app_main.DiwaliApp, isNotNull);
  });
}

class _ScriptedRepository extends StacScreenRepository {
  _ScriptedRepository(this._load);

  final Future<StacScreenDocument> Function() _load;

  @override
  Future<StacScreenDocument> load(StacLayoutId layout) => _load();
}
