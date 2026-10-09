import 'package:flutter/material.dart';
import 'balance_themes.dart';

/// Balance It UI toolkit — the Workshop Balance art direction.
///
/// Physical materials: wood grain, brass trim, felt backing, soft shadows.
/// No neon, no cyberpunk, no generic Material dashboard looks.

class Balance {
  static const displayFont = 'serif';

  static TextStyle display(double size,
      {required BalanceThemeDef theme, Color? color}) {
    return TextStyle(
      fontFamily: displayFont,
      fontSize: size,
      fontWeight: FontWeight.bold,
      color: color ?? theme.accentLight,
      letterSpacing: 1.1,
      shadows: [
        Shadow(
          color: Colors.black.withValues(alpha: 0.6),
          offset: const Offset(0, 2),
          blurRadius: 4,
        ),
      ],
    );
  }

  static TextStyle body(double size,
      {BalanceThemeDef? theme, Color? color}) {
    return TextStyle(
      fontSize: size,
      color: color ?? theme?.ivory ?? Colors.white,
      height: 1.35,
    );
  }

  static TextStyle label(double size,
      {required BalanceThemeDef theme, Color? color}) {
    return TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
      color: color ?? theme.ivory,
    );
  }

  static ThemeData theme([BalanceThemeDef? t]) {
    final theme = t ?? BalanceThemes.all.first;
    final scheme = ColorScheme.dark(
      primary: theme.accent,
      secondary: theme.accentLight,
      surface: theme.woodDeep,
      onSurface: theme.ivory,
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: theme.felt,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: theme.accentLight,
        selectionColor: theme.accent.withValues(alpha: 0.4),
        selectionHandleColor: theme.accent,
      ),
      dialogTheme: const DialogThemeData(backgroundColor: Colors.transparent),
    );
  }
}

// ---------------------------------------------------------------------------
/// Full-screen workshop backdrop: deep felt base with subtle vertical wood
/// grain and a soft vignette. Painted, not a stock image.
class WorkshopBackdrop extends StatelessWidget {
  final Widget child;
  final BalanceThemeDef? theme;
  const WorkshopBackdrop({super.key, required this.child, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme ?? BalanceThemes.all.first;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.felt, t.woodDeep.withValues(alpha: 0.85)],
        ),
      ),
      child: CustomPaint(
        painter: _WoodGrainPainter(t),
        child: child,
      ),
    );
  }
}

class _WoodGrainPainter extends CustomPainter {
  final BalanceThemeDef theme;
  _WoodGrainPainter(this.theme);

  @override
  void paint(Canvas canvas, Size size) {
    // Sparse vertical grain lines, very low alpha — texture, not noise.
    final paint = Paint()
      ..color = theme.woodMid.withValues(alpha: 0.10)
      ..strokeWidth = 2.5;
    const step = 46.0;
    for (double x = 8; x < size.width; x += step) {
      final wobble = 6 * (x / step % 3 - 1);
      canvas.drawLine(
        Offset(x + wobble, 0),
        Offset(x - wobble, size.height),
        paint,
      );
    }
    // Soft top light.
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          theme.accentLight.withValues(alpha: 0.07),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.5));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), glow);
  }

  @override
  bool shouldRepaint(covariant _WoodGrainPainter old) =>
      old.theme.id != theme.id;
}

// ---------------------------------------------------------------------------
/// Chunky wooden button with brass border and a press-down animation.
class TimberButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final BalanceThemeDef theme;
  final double width;
  final double fontSize;
  const TimberButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.theme,
    this.width = 260,
    this.fontSize = 19,
  });

  @override
  State<TimberButton> createState() => _TimberButtonState();
}

class _TimberButtonState extends State<TimberButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: widget.width,
        padding: const EdgeInsets.symmetric(vertical: 14),
        transform: Matrix4.translationValues(0, _down ? 3 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _down
                ? [t.woodDeep, t.woodMid]
                : [t.woodMid, t.woodDark],
          ),
          border: Border.all(color: t.accent, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _down ? 0.35 : 0.55),
              offset: Offset(0, _down ? 2 : 5),
              blurRadius: _down ? 4 : 10,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          widget.label,
          style: Balance.label(widget.fontSize,
              theme: t, color: t.accentLight),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Rounded brass plaque for headlines / narration.
class BrassPlaque extends StatelessWidget {
  final String text;
  final BalanceThemeDef theme;
  final double fontSize;
  const BrassPlaque({
    super.key,
    required this.text,
    required this.theme,
    this.fontSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            theme.accentDark.withValues(alpha: 0.9),
            theme.accent.withValues(alpha: 0.9),
          ],
        ),
        border: Border.all(color: theme.accentLight, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            offset: const Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Text(
        text,
        style: Balance.label(fontSize, theme: theme, color: theme.woodDeep),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Wooden toggle switch.
class BalanceToggle extends StatelessWidget {
  final BalanceThemeDef theme;
  final bool value;
  final ValueChanged<bool> onChanged;
  const BalanceToggle({
    super.key,
    required this.theme,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 58,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(colors: [
            value ? theme.accent : theme.woodDeep,
            value ? theme.accentDark : Colors.black.withValues(alpha: 0.4),
          ]),
          border: Border.all(color: theme.accentLight, width: 1.5),
        ),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        padding: const EdgeInsets.all(3),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [theme.accentLight, theme.accentDark],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                offset: const Offset(0, 2),
                blurRadius: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Wooden slider with a brass knob.
class KnobSlider extends StatelessWidget {
  final BalanceThemeDef theme;
  final double value;
  final ValueChanged<double> onChanged;
  const KnobSlider({
    super.key,
    required this.theme,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 10,
        activeTrackColor: theme.accent,
        inactiveTrackColor: Colors.black.withValues(alpha: 0.45),
        thumbShape: _KnobThumb(theme),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
        overlayColor: theme.accent.withValues(alpha: 0.25),
      ),
      child: Slider(value: value, onChanged: onChanged),
    );
  }
}

class _KnobThumb extends SliderComponentShape {
  final BalanceThemeDef theme;
  _KnobThumb(this.theme);

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size(26, 26);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(
      center,
      13,
      Paint()
        ..shader = RadialGradient(
          colors: [theme.accentLight, theme.accentDark],
        ).createShader(Rect.fromCircle(center: center, radius: 13)),
    );
    canvas.drawCircle(
      center,
      13,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = theme.woodDeep,
    );
  }
}

// ---------------------------------------------------------------------------
class SettingRow extends StatelessWidget {
  final BalanceThemeDef theme;
  final String label;
  final Widget control;
  const SettingRow({
    super.key,
    required this.theme,
    required this.label,
    required this.control,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Balance.body(16, theme: theme)),
          ),
          control,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Card container with the workshop look.
class WoodCard extends StatelessWidget {
  final BalanceThemeDef theme;
  final String title;
  final Widget child;
  const WoodCard({
    super.key,
    required this.theme,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.woodMid.withValues(alpha: 0.85),
            theme.woodDeep.withValues(alpha: 0.92),
          ],
        ),
        border: Border.all(color: theme.accent, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            offset: const Offset(0, 5),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(title, style: Balance.display(20, theme: theme)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Paints a physical ball: shaded sphere with rim, highlight and sheen.
/// Works for every BallStyle — the material comes from [base]/[hi].
void paintBall(Canvas canvas, Offset center, double r, Color base, Color hi) {
  // Drop shadow on the beam.
  canvas.drawOval(
    Rect.fromCenter(
        center: center + Offset(0, r * 0.92), width: r * 1.5, height: r * 0.42),
    Paint()..color = Colors.black.withValues(alpha: 0.35),
  );
  // Body.
  canvas.drawCircle(
    center,
    r,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.4),
        radius: 1.1,
        colors: [hi, base, base.withValues(red: (base.r * 0.55), green: (base.g * 0.55), blue: (base.b * 0.55))],
      ).createShader(Rect.fromCircle(center: center, radius: r)),
  );
  // Rim.
  canvas.drawCircle(
    center,
    r,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.08
      ..color = Colors.black.withValues(alpha: 0.3),
  );
  // Specular dot.
  canvas.drawCircle(
    center + Offset(-r * 0.35, -r * 0.42),
    r * 0.22,
    Paint()..color = Colors.white.withValues(alpha: 0.55),
  );
}
