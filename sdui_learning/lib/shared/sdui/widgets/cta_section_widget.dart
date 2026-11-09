import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/sdui_models.dart';

class CtaSectionWidget extends StatelessWidget {
  const CtaSectionWidget({super.key, required this.section});

  final CtaSection section;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _handleTap(context),
          child: Text(section.label),
        ),
      ),
    );
  }

  Future<void> _handleTap(BuildContext context) async {
    final payload = section.payload ?? '';

    switch (section.action) {
      case CtaAction.toast:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(payload.isEmpty ? section.label : payload)),
        );
      case CtaAction.share:
        await SharePlus.instance.share(
          ShareParams(text: payload.isEmpty ? section.label : payload),
        );
      case CtaAction.openUrl:
        final uri = Uri.tryParse(payload);
        if (uri == null) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid link in SDUI payload')),
          );
          return;
        }
        final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!ok && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open link')),
          );
        }
      case CtaAction.unknown:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unknown CTA action')),
        );
    }
  }
}
