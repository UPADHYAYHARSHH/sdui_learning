import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdui_learning/shared/data/repositories/layout_repository.dart';
import 'package:sdui_learning/shared/sdui/layout/dynamic_layout_builder.dart';
import 'package:sdui_learning/shared/sdui/layout/sdui_json.dart';
import 'package:sdui_learning/shared/sdui/layout/sdui_video_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('existing compositions', () {
    testWidgets('column + text still render', (tester) async {
      final builder = DynamicLayoutBuilder();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: builder.build({
              'type': 'column',
              'props': {'gap': 8},
              'children': [
                {
                  'type': 'text',
                  'props': {'value': 'Title', 'bold': true},
                },
                {
                  'type': 'text',
                  'props': {'value': 'Subtitle'},
                },
              ],
            }),
          ),
        ),
      );

      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Subtitle'), findsOneWidget);
    });

    testWidgets('nested generic product card without dedicated class', (
      tester,
    ) async {
      final builder = DynamicLayoutBuilder();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: builder.build({
              'type': 'container',
              'props': {'padding': 8, 'color': '#1E1E24', 'radius': 12},
              'children': [
                {
                  'type': 'column',
                  'props': {'gap': 6},
                  'children': [
                    {
                      'type': 'text',
                      'props': {'value': 'Lamp Set', 'color': '#FFFFFF'},
                    },
                    {
                      'type': 'button',
                      'props': {'label': 'Buy'},
                    },
                  ],
                },
              ],
            }),
          ),
        ),
      );

      expect(find.text('Lamp Set'), findsOneWidget);
      expect(find.text('Buy'), findsOneWidget);
    });
  });

  group('components', () {
    testWidgets('component ref resolves template + data binding', (
      tester,
    ) async {
      final builder = DynamicLayoutBuilder(
        components: {
          'banner': {
            'type': 'text',
            'props': {'value': '{{title}}'},
          },
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: builder.build({
              'type': 'component',
              'props': {
                'id': 'banner',
                'data': {'title': 'Hello Component'},
              },
            }),
          ),
        ),
      );

      expect(find.text('Hello Component'), findsOneWidget);
    });

    testWidgets('circular component refs fail safely', (tester) async {
      final builder = DynamicLayoutBuilder(
        components: {
          'a': {
            'type': 'component',
            'props': {'id': 'b'},
          },
          'b': {
            'type': 'component',
            'props': {'id': 'a'},
          },
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: builder.build({
              'type': 'column',
              'children': [
                {
                  'type': 'text',
                  'props': {'value': 'Before'},
                },
                {
                  'type': 'component',
                  'props': {'id': 'a'},
                },
                {
                  'type': 'text',
                  'props': {'value': 'After'},
                },
              ],
            }),
          ),
        ),
      );

      expect(find.text('Before'), findsOneWidget);
      expect(find.text('After'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('fail-safe', () {
    testWidgets('unknown type does not crash and shows no red error', (
      tester,
    ) async {
      final builder = DynamicLayoutBuilder();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: builder.build({
              'type': 'column',
              'children': [
                {
                  'type': 'text',
                  'props': {'value': 'Ok'},
                },
                {
                  'type': 'totally_unknown_widget',
                  'props': {'foo': 1},
                },
                {
                  'type': 'text',
                  'props': {'value': 'Still Ok'},
                },
              ],
            }),
          ),
        ),
      );

      expect(find.text('Ok'), findsOneWidget);
      expect(find.text('Still Ok'), findsOneWidget);
      expect(find.textContaining('Unknown'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('invalid child does not block siblings', (tester) async {
      final builder = DynamicLayoutBuilder();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: builder.build({
              'type': 'column',
              'children': [
                {
                  'type': 'text',
                  'props': {'value': 'A'},
                },
                'not-a-map',
                {
                  'type': 'text',
                  'props': {'value': 'B'},
                },
                null,
              ],
            }),
          ),
        ),
      );

      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('malformed color / numbers fall back safely', (tester) async {
      final builder = DynamicLayoutBuilder();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: builder.build({
              'type': 'text',
              'props': {
                'value': 'Safe',
                'color': 'not-a-color',
                'fontSize': 'xx',
              },
            }),
          ),
        ),
      );

      expect(find.text('Safe'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('asLayout unknown type renders children as column', (
      tester,
    ) async {
      final builder = DynamicLayoutBuilder();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: builder.build({
              'type': 'custom_section',
              'props': {'asLayout': true, 'gap': 4},
              'children': [
                {
                  'type': 'text',
                  'props': {'value': 'Child1'},
                },
                {
                  'type': 'text',
                  'props': {'value': 'Child2'},
                },
              ],
            }),
          ),
        ),
      );

      expect(find.text('Child1'), findsOneWidget);
      expect(find.text('Child2'), findsOneWidget);
    });
  });

  group('media', () {
    testWidgets('gif type builds without crash', (tester) async {
      final builder = DynamicLayoutBuilder();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: builder.build({
              'type': 'gif',
              'props': {'url': 'https://example.com/anim.gif', 'height': 80},
            }),
          ),
        ),
      );

      await tester.pump();
      expect(tester.takeException(), isNull);
      // gif aliases image → CachedNetworkImage tree present
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('video widget initializes and disposes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SduiVideoPlayer(url: '', height: 100)),
        ),
      );
      await tester.pump();
      expect(find.byType(SduiVideoPlayer), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('video type from builder mounts', (tester) async {
      final builder = DynamicLayoutBuilder();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: builder.build({
              'type': 'video',
              'props': {'url': 'https://example.com/v.mp4', 'height': 120},
            }),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(SduiVideoPlayer), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('json compare + components cache', () {
    test('semantic equality ignores key order', () {
      final a = {
        'title': 'Home',
        'root': {
          'type': 'column',
          'props': {'gap': 8},
        },
      };
      final b = {
        'root': {
          'props': {'gap': 8},
          'type': 'column',
        },
        'title': 'Home',
      };
      expect(SduiJson.hasMeaningfulChange(a, b), isFalse);
    });

    test('detects meaningful root change', () {
      final a = {
        'root': {'type': 'column'},
      };
      final b = {
        'root': {'type': 'grid'},
      };
      expect(SduiJson.hasMeaningfulChange(a, b), isTrue);
    });

    test('component template change invalidates equality', () {
      final prev = LayoutLoadResult(
        docId: 'layout_demo',
        fromCache: false,
        data: {
          'components': {
            'banner': {
              'type': 'text',
              'props': {'value': 'Old'},
            },
          },
          'root': {
            'type': 'component',
            'props': {'id': 'banner'},
          },
        },
      );
      final next = LayoutLoadResult(
        docId: 'layout_demo',
        fromCache: false,
        data: {
          'components': {
            'banner': {
              'type': 'text',
              'props': {'value': 'New'},
            },
          },
          'root': {
            'type': 'component',
            'props': {'id': 'banner'},
          },
        },
      );

      expect(prev.isMeaningfullyDifferentFrom(next), isTrue);
      expect(next.components['banner']?['props']?['value'], 'New');
    });
  });
}
