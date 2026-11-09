import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rfw/formats.dart' show parseLibraryFile;
import 'package:sdui_learning/riverpod/pages/rfw_sdui_page.dart';
import 'package:sdui_learning/riverpod/providers/rfw_providers.dart';
import 'package:sdui_learning/shared/data/repositories/rfw_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('seed RFW library parses', () async {
    final raw = await rootBundle.loadString('assets/sdui/rfw_demo.json');
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final library = map['library'] as String;
    final remote = parseLibraryFile(library);
    expect(remote.widgets, isNotEmpty);
    expect(remote.widgets.any((w) => w.name == 'root'), isTrue);
  });

  testWidgets('RFW Riverpod page loads seed UI', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rfwRepositoryProvider.overrideWithValue(
            RfwRepository(firebaseReady: false),
          ),
        ],
        child: const MaterialApp(home: RiverpodRfwSduiPage()),
      ),
    );

    // rootBundle seed is a real Future — run outside fake async.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await tester.pump();

    expect(find.text('Offline · RFW'), findsOneWidget);
    expect(find.textContaining('Remote Flutter Widgets'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
