import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'bloc/cubit/festival_screen_cubit.dart';
import 'bloc/pages/festival_sdui_page.dart';
import 'riverpod/pages/festival_sdui_page.dart';
import 'riverpod/pages/rfw_sdui_page.dart';
import 'riverpod/providers/rfw_providers.dart';
import 'riverpod/providers/screen_providers.dart';
import 'shared/data/repositories/layout_repository.dart';
import 'shared/data/repositories/rfw_repository.dart';
import 'shared/data/repositories/screen_repository.dart';
import 'shared/ui/dynamic_layout_page.dart';

/// Landing screen: Riverpod / BLoC festivals, dynamic layout, or RFW.
class ArchitecturePickerPage extends StatelessWidget {
  const ArchitecturePickerPage({
    super.key,
    required this.repository,
    required this.layoutRepository,
    required this.rfwRepository,
  });

  final ScreenRepository repository;
  final LayoutRepository layoutRepository;
  final RfwRepository rfwRepository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F12),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          child: ListView(
            children: [
              Text(
                'Festival SDUI',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Firebase streaming. Typed festivals or model-free layout trees.',
                style: GoogleFonts.outfit(
                  color: Colors.white70,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              _ArchCard(
                title: 'Dynamic Layout',
                subtitle: 'Diwali Home (Given UI) · live from Firebase screens/diwali',
                color: const Color(0xFFC8321A),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DynamicLayoutPage(
                        repository: layoutRepository,
                        docId: 'diwali',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              _ArchCard(
                title: 'RFW · Riverpod',
                subtitle:
                    'Official Remote Flutter Widgets · live library from Firebase',
                color: const Color(0xFF2B4C7E),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ProviderScope(
                        overrides: [
                          rfwRepositoryProvider.overrideWithValue(
                            rfwRepository,
                          ),
                        ],
                        child: const RiverpodRfwSduiPage(),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              _ArchCard(
                title: 'Riverpod',
                subtitle: 'Typed festival sections · StreamProvider',
                color: const Color(0xFFC45C26),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ProviderScope(
                        overrides: [
                          screenRepositoryProvider.overrideWithValue(
                            repository,
                          ),
                        ],
                        child: const RiverpodFestivalSduiPage(),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              _ArchCard(
                title: 'BLoC',
                subtitle: 'Typed festival sections · Cubit (unchanged)',
                color: const Color(0xFF7B1E3A),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BlocProvider(
                        create: (_) => FestivalScreenCubit(repository),
                        child: const BlocFestivalSduiPage(),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArchCard extends StatelessWidget {
  const _ArchCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
