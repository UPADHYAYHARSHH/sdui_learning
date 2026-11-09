import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';
import 'shared/data/repositories/layout_repository.dart';
import 'shared/ui/dynamic_layout_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;
    debugPrint(
      '[SDUI] Firebase.init OK | project=${DefaultFirebaseOptions.currentPlatform.projectId}',
    );
  } catch (e, st) {
    debugPrint('[SDUI] Firebase.init FAILED → offline seeds only: $e\n$st');
  }

  final firestore = firebaseReady ? FirebaseFirestore.instance : null;
  final layoutRepository = LayoutRepository(
    firestore: firestore,
    firebaseReady: firebaseReady,
  );

  runApp(FestivalApp(layoutRepository: layoutRepository));
}

/// Main application launching Server-Driven UI driven by Firestore `config/active`.
class FestivalApp extends StatelessWidget {
  const FestivalApp({super.key, required this.layoutRepository});

  final LayoutRepository layoutRepository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Festival Shopping',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF7F5F0),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(),
      ),
      home: DynamicLayoutPage(
        repository: layoutRepository,
        // Omitted docId dynamically streams Firestore config/active in real-time!
      ),
    );
  }
}

/// Backwards compatibility aliases
typedef HoliApp = FestivalApp;
typedef UttarayanApp = FestivalApp;
typedef NavratriApp = FestivalApp;
typedef DiwaliApp = FestivalApp;
