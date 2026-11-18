import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Tests must not hit the network for fonts (HttpClient is stubbed to 400).
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
