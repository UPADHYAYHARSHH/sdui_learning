part of 'dynamic_layout_builder.dart';

mixin _SduiFestivalBuilders on _SduiBuilderCore {
  Widget _festiveHeader(
    Map<String, dynamic> props, {
    String defaultFestival = 'navratri',
  }) {
    final title = props['title'] as String? ?? 'Delivering to Home';
    final address =
        props['address'] as String? ?? 'Satellite, Ahmedabad 380015';
    final festival =
        (props['festival'] as String? ?? defaultFestival).toLowerCase();
    final isNavratri = festival == 'navratri';
    final isUttarayan = festival == 'uttarayan';
    final isHoli = festival == 'holi';
    final searchHint = props['searchHint'] as String? ??
        (isHoli
            ? 'Search colours, white tees, pichkari'
            : isUttarayan
                ? 'Search kites, manja, sunglasses'
                : isNavratri
                    ? 'Search chaniya choli, jewellery'
                    : 'Search diyas, kurtas, gifts');
    final baseHeight = _double(props['height'], 168);
    final bgImage = props['bgImage'] as String? ??
        (isHoli
            ? 'holi/topbar_holi_v3.gif'
            : isUttarayan
                ? 'uttarayan/topbar_kites_v2.gif'
                : isNavratri
                    ? 'navratri/topbar_animated_v6.gif'
                    : 'diwali/topbar.gif');
    final bgColor = _color(props['bgColor']) ??
        (isHoli
            ? const Color(0xFF2A1245)
            : isUttarayan
                ? const Color(0xFF0B4A6B)
                : isNavratri
                    ? const Color(0xFF2B0B1E)
                    : const Color(0xFF2A1608));

    return Builder(
      builder: (context) {
        final topInset = MediaQuery.paddingOf(context).top;
        final totalHeight = baseHeight + topInset;

        return Container(
          constraints: BoxConstraints(minHeight: totalHeight),
          color: bgColor,
          child: Stack(
            children: [
              Positioned.fill(
                child: bgImage.isNotEmpty
                    ? _buildImageWidget(
                        path: bgImage,
                        fit: _boxFit(props['fit']),
                        alignment: _alignment(props['imageAlignment'] ?? props['alignment']) ??
                            Alignment.center,
                      )
                    : CustomPaint(
                        painter: isHoli
                            ? HoliFestiveArtworkPainter()
                            : isUttarayan
                                ? UttarayanFestiveArtworkPainter()
                                : isNavratri
                                    ? NavratriFestiveArtworkPainter()
                                    : DiwaliFestiveArtworkPainter(),
                      ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.25),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.20),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: baseHeight),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            address,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _dispatchTapAction(
                            context,
                            props['action'] as String? ?? 'open_search',
                            {
                              ...props,
                              'searchHint': searchHint,
                              'hint': searchHint,
                              'festival': festival,
                            },
                          ),
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.search_rounded,
                                  size: 20,
                                  color: Color(0xFF5A554C),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    searchHint,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      color: const Color(0xFF5A554C),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          ),
        );
      },
    );
  }

  Widget _nineColours(Map<String, dynamic> props) {
    final title = props['title'] as String? ?? 'Nine nights, nine colours';
    final rawColors = props['colors'] as List? ??
        [
          '#E8731A',
          '#FFFFFF',
          '#C8321A',
          '#2A5BD7',
          '#F2C14E',
          '#1B7A3A',
          '#8A8A8A',
          '#7A2FB5',
          '#0B7A75',
        ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFEBE6DC),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF14120F),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final raw in rawColors) ...[
                Builder(
                  builder: (_) {
                    final colorHex = raw.toString().toUpperCase();
                    final color = _color(raw) ?? Colors.transparent;
                    final isWhite =
                        colorHex == '#FFFFFF' ||
                        colorHex == '#FFF' ||
                        color == Colors.white;
                    return Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isWhite
                            ? Border.all(
                                color: const Color(0xFFD8D2C6),
                                width: 1,
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _countdownCard(Map<String, dynamic> props) {
    final title = props['title'] as String? ?? 'Kite day starts in';
    final subtitle = props['subtitle'] as String? ?? 'Order before the rush';
    final targetDate = props['targetDate'] as String?;
    final rawBadges = props['badges'] as List?;
    final badgeColor = _color(props['badgeColor']) ?? const Color(0xFF0B4A6B);

    return LiveCountdownCard(
      title: title,
      subtitle: subtitle,
      targetDate: targetDate,
      fallbackBadges: rawBadges,
      badgeColor: badgeColor,
    );
  }

}

class DiwaliFestiveArtworkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 390.0;
    final sy = size.height / 168.0;

    // 1. Hanging garland string: M0 18 Q100 60 200 20 T390 30
    final wirePaint = Paint()
      ..color = const Color(0xFF7A4A1E)
      ..strokeWidth = 2.0 * sy
      ..style = PaintingStyle.stroke;

    final wirePath = Path()
      ..moveTo(0, 18 * sy)
      ..quadraticBezierTo(100 * sx, 60 * sy, 200 * sx, 20 * sy)
      ..quadraticBezierTo(300 * sx, -20 * sy, 390 * sx, 30 * sy);
    canvas.drawPath(wirePath, wirePaint);

    // 2. Festive golden light beads / lanterns
    final bulbPaint = Paint()
      ..color = const Color(0xFFF5B83D)
      ..style = PaintingStyle.fill;

    final bulbs = [
      Offset(50 * sx, 38 * sy),
      Offset(120 * sx, 44 * sy),
      Offset(200 * sx, 22 * sy),
      Offset(280 * sx, 32 * sy),
      Offset(350 * sx, 36 * sy),
    ];
    for (final bulb in bulbs) {
      canvas.drawCircle(bulb, 6 * sx, bulbPaint);
    }

    // 3. Terracotta Diya base: M300 150 Q340 120 380 150Z
    final diyaPaint = Paint()
      ..color = const Color(0xFFB4440A)
      ..style = PaintingStyle.fill;

    final diyaPath = Path()
      ..moveTo(300 * sx, 150 * sy)
      ..quadraticBezierTo(340 * sx, 120 * sy, 380 * sx, 150 * sy)
      ..close();
    canvas.drawPath(diyaPath, diyaPaint);

    // 4. Diya Flame: M340 118 Q330 100 340 86 Q352 100 340 118Z
    final flamePath = Path()
      ..moveTo(340 * sx, 118 * sy)
      ..quadraticBezierTo(330 * sx, 100 * sy, 340 * sx, 86 * sy)
      ..quadraticBezierTo(352 * sx, 100 * sy, 340 * sx, 118 * sy)
      ..close();
    canvas.drawPath(flamePath, bulbPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Replicates the decorative kites, sky ellipses and manja threads from Uttarayan.dc.html.
class UttarayanFestiveArtworkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 390.0;
    final sy = size.height / 168.0;

    final cloudPaint = Paint()
      ..color = const Color(0xFF1B6A93)
      ..style = PaintingStyle.fill;

    // Ellipse 1: cx="60" cy="150" rx="70" ry="14"
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(60 * sx, 150 * sy),
        width: 140 * sx,
        height: 28 * sy,
      ),
      cloudPaint,
    );

    // Ellipse 2: cx="320" cy="140" rx="80" ry="16"
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(320 * sx, 140 * sy),
        width: 160 * sx,
        height: 32 * sy,
      ),
      cloudPaint,
    );

    // Kite 1 (Yellow): M300 20l22 28-22 28-22-28z
    final kite1Paint = Paint()
      ..color = const Color(0xFFF2C14E)
      ..style = PaintingStyle.fill;
    final kite1 = Path()
      ..moveTo(300 * sx, 20 * sy)
      ..lineTo(322 * sx, 48 * sy)
      ..lineTo(300 * sx, 76 * sy)
      ..lineTo(278 * sx, 48 * sy)
      ..close();
    canvas.drawPath(kite1, kite1Paint);

    // Kite 2 (Orange): M340 70l16 20-16 20-16-20z
    final kite2Paint = Paint()
      ..color = const Color(0xFFE4572E)
      ..style = PaintingStyle.fill;
    final kite2 = Path()
      ..moveTo(340 * sx, 70 * sy)
      ..lineTo(356 * sx, 90 * sy)
      ..lineTo(340 * sx, 110 * sy)
      ..lineTo(324 * sx, 90 * sy)
      ..close();
    canvas.drawPath(kite2, kite2Paint);

    // Kite 3 (White): M250 40l14 18-14 18-14-18z
    final kite3Paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final kite3 = Path()
      ..moveTo(250 * sx, 40 * sy)
      ..lineTo(264 * sx, 58 * sy)
      ..lineTo(250 * sx, 76 * sy)
      ..lineTo(236 * sx, 58 * sy)
      ..close();
    canvas.drawPath(kite3, kite3Paint);

    // Thread paths:
    // M300 76Q290 110 310 140
    // M340 110Q330 130 345 160
    // M250 76Q245 100 255 120
    final threadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5 * sy
      ..style = PaintingStyle.stroke;

    final threads = Path()
      ..moveTo(300 * sx, 76 * sy)
      ..quadraticBezierTo(290 * sx, 110 * sy, 310 * sx, 140 * sy)
      ..moveTo(340 * sx, 110 * sy)
      ..quadraticBezierTo(330 * sx, 130 * sy, 345 * sx, 160 * sy)
      ..moveTo(250 * sx, 76 * sy)
      ..quadraticBezierTo(245 * sx, 100 * sy, 255 * sx, 120 * sy);
    canvas.drawPath(threads, threadPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Replicates the decorative Garba concentric circles and Dandiya sticks from Navratri.dc.html.
class NavratriFestiveArtworkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 390.0;
    final sy = size.height / 168.0;

    // 1. Concentric circles at (330, 84)
    final circlePaint = Paint()
      ..color = const Color(0xFFE8A3C4).withValues(alpha: 0.6)
      ..strokeWidth = 2.0 * sy
      ..style = PaintingStyle.stroke;

    final center = Offset(330 * sx, 84 * sy);
    canvas.drawCircle(center, 70 * sx, circlePaint);
    canvas.drawCircle(center, 50 * sx, circlePaint);
    canvas.drawCircle(center, 30 * sx, circlePaint);

    // 2. Center bead: (330, 84) radius 8, fill #F2C14E
    final centerBeadPaint = Paint()
      ..color = const Color(0xFFF2C14E)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 8 * sx, centerBeadPaint);

    // 3. Dandiya stick 1: rect x="230" y="20" width="10" height="80" rx="5" fill="#F2C14E" transform="rotate(30 235 60)"
    canvas.save();
    canvas.translate(235 * sx, 60 * sy);
    canvas.rotate(30 * 3.141592653589793 / 180);
    canvas.translate(-235 * sx, -60 * sy);
    final stick1Paint = Paint()
      ..color = const Color(0xFFF2C14E)
      ..style = PaintingStyle.fill;
    final rrect1 = RRect.fromRectAndRadius(
      Rect.fromLTWH(230 * sx, 20 * sy, 10 * sx, 80 * sy),
      Radius.circular(5 * sx),
    );
    canvas.drawRRect(rrect1, stick1Paint);
    canvas.restore();

    // 4. Dandiya stick 2: rect x="262" y="20" width="10" height="80" rx="5" fill="#E8A3C4" transform="rotate(-25 267 60)"
    canvas.save();
    canvas.translate(267 * sx, 60 * sy);
    canvas.rotate(-25 * 3.141592653589793 / 180);
    canvas.translate(-267 * sx, -60 * sy);
    final stick2Paint = Paint()
      ..color = const Color(0xFFE8A3C4)
      ..style = PaintingStyle.fill;
    final rrect2 = RRect.fromRectAndRadius(
      Rect.fromLTWH(262 * sx, 20 * sy, 10 * sx, 80 * sy),
      Radius.circular(5 * sx),
    );
    canvas.drawRRect(rrect2, stick2Paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Replicates the decorative colour splash circles from Holi.dc.html.
class HoliFestiveArtworkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 390.0;
    final sy = size.height / 168.0;

    // 1. Magenta circle: cx="340" cy="30" r="46" fill="#E4357A"
    canvas.drawCircle(
      Offset(340 * sx, 30 * sy),
      46 * sx,
      Paint()
        ..color = const Color(0xFFE4357A)
        ..style = PaintingStyle.fill,
    );

    // 2. Yellow circle: cx="290" cy="110" r="38" fill="#F2A900"
    canvas.drawCircle(
      Offset(290 * sx, 110 * sy),
      38 * sx,
      Paint()
        ..color = const Color(0xFFF2A900)
        ..style = PaintingStyle.fill,
    );

    // 3. Teal circle: cx="360" cy="130" r="30" fill="#2DB5A0"
    canvas.drawCircle(
      Offset(360 * sx, 130 * sy),
      30 * sx,
      Paint()
        ..color = const Color(0xFF2DB5A0)
        ..style = PaintingStyle.fill,
    );

    // 4. Green circle: cx="240" cy="40" r="20" fill="#7AC74F"
    canvas.drawCircle(
      Offset(240 * sx, 40 * sy),
      20 * sx,
      Paint()
        ..color = const Color(0xFF7AC74F)
        ..style = PaintingStyle.fill,
    );

    // 5. Small yellow circle: cx="200" cy="130" r="12" fill="#F2A900"
    canvas.drawCircle(
      Offset(200 * sx, 130 * sy),
      12 * sx,
      Paint()
        ..color = const Color(0xFFF2A900)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LiveCountdownCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String? targetDate;
  final List<dynamic>? fallbackBadges;
  final Color badgeColor;

  const LiveCountdownCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.targetDate,
    this.fallbackBadges,
    required this.badgeColor,
  });

  @override
  State<LiveCountdownCard> createState() => _LiveCountdownCardState();
}

class _LiveCountdownCardState extends State<LiveCountdownCard> {
  Timer? _timer;
  late DateTime _target;

  @override
  void initState() {
    super.initState();
    _initTarget();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _initTarget() {
    if (widget.targetDate != null && widget.targetDate!.isNotEmpty) {
      try {
        _target = DateTime.parse(widget.targetDate!);
        return;
      } catch (_) {}
    }
    // Default to next Uttarayan (Jan 14, 06:00 AM)
    final now = DateTime.now();
    int targetYear = now.year;
    final thisYearTarget = DateTime(targetYear, 1, 14, 6, 0, 0);
    if (now.isAfter(thisYearTarget)) {
      targetYear += 1;
    }
    _target = DateTime(targetYear, 1, 14, 6, 0, 0);
  }

  @override
  void didUpdateWidget(covariant LiveCountdownCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetDate != widget.targetDate) {
      _initTarget();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<String> _calculateBadges() {
    final now = DateTime.now();
    final diff = _target.difference(now);
    if (diff.isNegative || diff.inSeconds <= 0) {
      return ['00 d', '00 h', '00 m', '00 s'];
    }

    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;
    final seconds = diff.inSeconds % 60;

    return [
      '${days.toString().padLeft(2, '0')} d',
      '${hours.toString().padLeft(2, '0')} h',
      '${minutes.toString().padLeft(2, '0')} m',
      '${seconds.toString().padLeft(2, '0')} s',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final badges = _calculateBadges();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFEBE6DC),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF14120F),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFF5A554C),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final b in badges) ...[
                Container(
                  margin: const EdgeInsets.only(left: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: widget.badgeColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    b,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

