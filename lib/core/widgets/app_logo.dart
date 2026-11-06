import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppLogo extends StatelessWidget {
  final double fontSize;
  final double iconSize;
  final bool showText;
  final MainAxisSize mainAxisSize;

  const AppLogo({
    super.key,
    this.fontSize = 22,
    this.iconSize = 34,
    this.showText = true,
    this.mainAxisSize = MainAxisSize.min,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: mainAxisSize,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 1. Logo Icon with Squircle gradient + Yellow top-right dot
        SizedBox(
          width: iconSize + 4,
          height: iconSize + 4,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Gradient Squircle Box
              Align(
                alignment: Alignment.bottomLeft,
                child: Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(iconSize * 0.32),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFE11D48),
                        Color(0xFFF43F5E),
                        Color(0xFFFB923C),
                      ],
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE11D48).withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: CustomPaint(
                      size: Size(iconSize * 0.58, iconSize * 0.58),
                      painter: _HeartHandshakePainter(),
                    ),
                  ),
                ),
              ),

              // Small Top-Right Yellow Accent Dot
              Positioned(
                top: 0,
                right: 2,
                child: Container(
                  width: iconSize * 0.22,
                  height: iconSize * 0.22,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFBBF24),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),

        if (showText) ...[
          const SizedBox(width: 10),

          // 2. Text: "Prem " (White) + "Jodo" (Gradient)
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Prem ',
                  style: GoogleFonts.outfit(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.6,
                    height: 1.1,
                  ),
                ),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        Color(0xFFE11D48),
                        Color(0xFFF43F5E),
                        Color(0xFFFB923C),
                        Color(0xFFF59E0B),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ).createShader(bounds),
                    child: Text(
                      'Jodo',
                      style: GoogleFonts.outfit(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.6,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Custom Painter to draw the clean Heart-Handshake vector icon
class _HeartHandshakePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Heart Outline Path
    final heartPath = Path();
    heartPath.moveTo(w * 0.5, h * 0.88);
    // Left lobe
    heartPath.cubicTo(
      w * 0.1,
      h * 0.65,
      w * 0.0,
      h * 0.35,
      w * 0.25,
      h * 0.16,
    );
    heartPath.cubicTo(
      w * 0.40,
      h * 0.06,
      w * 0.50,
      h * 0.22,
      w * 0.50,
      h * 0.28,
    );
    // Right lobe
    heartPath.cubicTo(
      w * 0.50,
      h * 0.22,
      w * 0.60,
      h * 0.06,
      w * 0.75,
      h * 0.16,
    );
    heartPath.cubicTo(
      w * 1.0,
      h * 0.35,
      w * 0.9,
      h * 0.65,
      w * 0.5,
      h * 0.88,
    );

    canvas.drawPath(heartPath, paint);

    // Handshake clasp inner line
    final claspPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.11
      ..strokeCap = StrokeCap.round;

    final claspPath = Path();
    claspPath.moveTo(w * 0.34, h * 0.46);
    claspPath.lineTo(w * 0.48, h * 0.58);
    claspPath.lineTo(w * 0.64, h * 0.42);

    canvas.drawPath(claspPath, claspPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
