import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdui_learning/main.dart';
import 'package:sdui_learning/shared/data/repositories/layout_repository.dart';
import 'package:sdui_learning/shared/sdui/layout/dynamic_layout_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final layoutRepository = LayoutRepository(firebaseReady: false);

  testWidgets('FestivalApp loads the latest Holi UI', (tester) async {
    await tester.pumpWidget(
      FestivalApp(layoutRepository: layoutRepository),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Delivering to Home'), findsOneWidget);
    expect(find.text('Satellite, Ahmedabad 380015'), findsOneWidget);
    expect(find.text('Holi must haves'), findsOneWidget);
    expect(find.text('Colour up'), findsOneWidget);
    expect(find.text('Skin and hair care combos'), findsOneWidget);
    expect(find.text('White cotton tee'), findsOneWidget);
    expect(find.text('Herbal colour set'), findsOneWidget);
  });

  testWidgets('Layout builder switches column children to grid', (
    tester,
  ) async {
    final builder = DynamicLayoutBuilder();

    final column = builder.build({
      'type': 'column',
      'children': [
        {
          'type': 'text',
          'props': {'value': 'A'},
        },
        {
          'type': 'text',
          'props': {'value': 'B'},
        },
      ],
    });

    final grid = builder.build({
      'type': 'grid',
      'props': {'crossAxisCount': 2},
      'children': [
        {
          'type': 'text',
          'props': {'value': 'A'},
        },
        {
          'type': 'text',
          'props': {'value': 'B'},
        },
      ],
    });

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: column)));
    expect(find.text('A'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: grid)));
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });
}
