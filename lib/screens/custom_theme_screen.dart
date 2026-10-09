import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/balance_art.dart';
import '../theme/balance_themes.dart';

/// Custom theme creator (PRO): pick workshop-material colors for every
/// surface. All choices persist.
class CustomThemeScreen extends StatefulWidget {
  final BalanceAudio audio;
  final BalanceSettings settings;
  const CustomThemeScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<CustomThemeScreen> createState() => _CustomThemeScreenState();
}

class _CustomThemeScreenState extends State<CustomThemeScreen> {
  /// Curated workshop-material swatches — no neon, no AI-dashboard hues.
  static const List<Color> _swatches = [
    Color(0xFF7A4E2A),
    Color(0xFFA9743F),
    Color(0xFF4E2F17),
    Color(0xFF5E2318),
    Color(0xFF2E2318),
    Color(0xFF1C1712),
    Color(0xFFC9A227),
    Color(0xFFE8CE7A),
    Color(0xFFB87333),
    Color(0xFF7BA05B),
    Color(0xFF4E9B8F),
    Color(0xFF4A5162),
    Color(0xFFC0C6D4),
    Color(0xFFF5EFE0),
    Color(0xFFFFFFFF),
    Color(0xFF2E2A26),
    Color(0xFFD64545),
    Color(0xFFE4572E),
    Color(0xFF2E7D5B),
    Color(0xFF8A2E1E),
    Color(0xFFB07B45),
    Color(0xFFE8C48A),
    Color(0xFF9FB8C8),
    Color(0xFF22301C),
  ];

  BalanceThemeDef get _t => BalanceThemes.byId('custom',
      custom: widget.settings.customTheme);

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
    return WorkshopBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: t.accentLight),
            onPressed: () {
              widget.audio.click();
              Navigator.of(context).pop();
            },
          ),
          title: Text('My Creation', style: Balance.display(22, theme: t)),
          centerTitle: true,
          actions: [
            TextButton(
              onPressed: () async {
                widget.audio.click();
                await s.resetCustomColors();
                if (mounted) setState(() {});
              },
              child: Text('Reset',
                  style: Balance.label(14, theme: t)),
            ),
          ],
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: s,
            builder: (_, _) => SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  // Live preview: mini beam + ball.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: t.felt.withValues(alpha: 0.7),
                      border: Border.all(color: t.accent, width: 2),
                    ),
                    child: Column(
                      children: [
                        Text('Preview', style: Balance.label(14, theme: t)),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 120,
                          child: CustomPaint(
                            painter: _PreviewPainter(t, s),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (final key in BalanceSettings.customColorLabels)
                    _ColorRow(
                      theme: t,
                      label: BalanceSettings.customColorNames[key] ?? key,
                      current: Color(s.customColors[key] ?? 0xFF000000),
                      swatches: _swatches,
                      onPick: (c) async {
                        widget.audio.click();
                        await s.setCustomColor(key, c.toARGB32());
                        if (mounted) setState(() {});
                      },
                    ),
                  const SizedBox(height: 12),
                  TimberButton(
                    label: 'Use My Creation',
                    width: 260,
                    theme: t,
                    onTap: () async {
                      widget.audio.click();
                      await s.setTheme('custom');
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorRow extends StatelessWidget {
  final BalanceThemeDef theme;
  final String label;
  final Color current;
  final List<Color> swatches;
  final ValueChanged<Color> onPick;
  const _ColorRow({
    required this.theme,
    required this.label,
    required this.current,
    required this.swatches,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: current,
                  border: Border.all(
                      color: theme.accentLight, width: 2),
                ),
              ),
              const SizedBox(width: 10),
              Text(label, style: Balance.body(15, theme: theme)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in swatches)
                GestureDetector(
                  onTap: () => onPick(c),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c,
                      border: Border.all(
                        color: c.toARGB32() == current.toARGB32()
                            ? theme.accentLight
                            : Colors.black.withValues(alpha: 0.4),
                        width: c.toARGB32() == current.toARGB32()
                            ? 3
                            : 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Mini preview: beam + stand + ball in the custom colors.
class _PreviewPainter extends CustomPainter {
  final BalanceThemeDef t;
  final BalanceSettings s;
  _PreviewPainter(this.t, this.s);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.55;
    final half = size.width * 0.38;
    final stand = Path()
      ..moveTo(cx - 20, size.height - 8)
      ..lineTo(cx + 20, size.height - 8)
      ..lineTo(cx, cy + 12)
      ..close();
    canvas.drawPath(stand, Paint()..color = t.accent);
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(-0.12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: half * 2, height: 22),
        const Radius.circular(11),
      ),
      Paint()
        ..shader = LinearGradient(
          colors: [t.woodMid, t.woodDark],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(
            Rect.fromCenter(center: Offset.zero, width: half * 2, height: 22)),
    );
    for (final sd in [-1, 1]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(sd * (half - 13), 0), width: 28, height: 22),
          const Radius.circular(10),
        ),
        Paint()..color = t.danger.withValues(alpha: 0.85),
      );
    }
    paintBall(canvas, const Offset(30, -11 - 15), 15, s.customBallBase,
        s.customBallHi);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PreviewPainter old) => true;
}
