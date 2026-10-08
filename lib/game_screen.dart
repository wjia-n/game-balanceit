import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

const _goal = 60.0;

class BalanceItScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;
  const BalanceItScreen({super.key, required this.players, required this.callbacks});

  @override
  State<BalanceItScreen> createState() => _BalanceItScreenState();
}

class _BalanceItScreenState extends State<BalanceItScreen>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _tilt = 0; // radians, + = right side down
  double _targetTilt = 0;
  double _ballX = 0; // -1..1 along beam
  double _ballV = 0;
  double _elapsed = 0;
  bool _over = false;
  bool _started = false;
  // gusts
  double _gust = 0;
  double _gustT = 0;
  double _nextGust = 4;
  double _gustDir = 0;
  double? _best;
  final _rand = math.Random();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    _loadBest();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Future<void> _loadBest() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) setState(() => _best = p.getDouble('balance_best'));
  }

  void _tick(Duration _) {
    if (_over || !_started) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    const dt = 1 / 60;
    setState(() {
      _elapsed += dt;
      // smooth tilt toward target
      _tilt += (_targetTilt - _tilt) * math.min(1, 8 * dt);
      // gusts
      _gustT += dt;
      if (_gustT >= _nextGust) {
        _gustT = 0;
        _nextGust = 3.5 + _rand.nextDouble() * 3.5;
        _gustDir = _rand.nextBool() ? 1 : -1;
        _gust = 2.2 + _rand.nextDouble() * 2.2;
        Sfx.move();
      }
      _gust *= math.exp(-1.6 * dt);
      // ball physics: gravity along tilt + gust push
      final acc = 3.4 * math.sin(_tilt) + _gust * _gustDir * 0.9;
      _ballV += acc * dt;
      _ballV *= math.exp(-0.35 * dt);
      _ballX += _ballV * dt;
      if (_ballX.abs() > 1.02) {
        _lose();
        return;
      }
      if (_elapsed >= _goal) _win();
    });
  }

  Future<void> _win() async {
    _over = true;
    _ticker.stop();
    Sfx.win();
    final p = await SharedPreferences.getInstance();
    final prev = p.getDouble('balance_best') ?? 0;
    if (_elapsed > prev) await p.setDouble('balance_best', _elapsed);
    if (!mounted) return;
    widget.callbacks.finish(
      headline: 'You survived 60 seconds! 🏆',
      subline: 'Steady hands, legend. The ball never stood a chance.',
    );
  }

  void _lose() {
    _over = true;
    _ticker.stop();
    Sfx.lose();
    widget.callbacks.finish(
      headline: 'The ball escaped at ${_elapsed.toStringAsFixed(1)}s!',
      subline: _best != null && _best! > 0
          ? 'Best survival: ${_best!.toStringAsFixed(1)}s. Go again!'
          : 'So close! Give it another go.',
    );
  }

  void _drag(Offset at, Size size) {
    // tilt follows finger: left = tilt left, right = tilt right
    final nx = ((at.dx / size.width) - 0.5) * 2; // -1..1
    setState(() {
      _targetTilt = (nx * 0.55).clamp(-0.55, 0.55);
      _started = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.of(context).theme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('⏱ ${_elapsed.toStringAsFixed(1)}s / ${_goal.toInt()}s',
                  style: TextStyle(color: theme.text, fontWeight: FontWeight.bold)),
              if (_gust.abs() > 0.4)
                Text('💨${_gustDir > 0 ? '→' : '←'}',
                    style: const TextStyle(fontSize: 20)),
              if (_best != null && _best! > 0)
                Text('🏆 ${_best!.toStringAsFixed(1)}s',
                    style: TextStyle(color: theme.muted)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (_elapsed / _goal).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: theme.muted.withValues(alpha: 0.25),
              valueColor: AlwaysStoppedAnimation(theme.accent),
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (ctx, c) {
              final s = Size(c.maxWidth, c.maxHeight);
              return GestureDetector(
                onPanDown: (d) => _drag(d.localPosition, s),
                onPanUpdate: (d) => _drag(d.localPosition, s),
                child: CustomPaint(
                  size: s,
                  painter: _BeamPainter(
                    tilt: _tilt,
                    ballX: _ballX,
                    gust: _gust,
                    gustDir: _gustDir,
                    started: _started,
                    theme: theme,
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(_started ? 'Keep it centered! 🎯' : 'Drag anywhere to tilt the beam 👆',
              style: TextStyle(color: theme.muted)),
        ),
      ],
    );
  }
}

class _BeamPainter extends CustomPainter {
  final double tilt, ballX, gust, gustDir;
  final bool started;
  final GameTheme theme;

  _BeamPainter({
    required this.tilt,
    required this.ballX,
    required this.gust,
    required this.gustDir,
    required this.started,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.55;
    final half = size.width * 0.42;
    // pivot stand
    final stand = Path()
      ..moveTo(cx - 26, size.height - 40)
      ..lineTo(cx + 26, size.height - 40)
      ..lineTo(cx, cy + 14)
      ..close();
    canvas.drawPath(stand, Paint()..color = theme.muted.withValues(alpha: 0.5));
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(tilt);
    // beam
    final beam = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: half * 2, height: 22),
        const Radius.circular(11));
    canvas.drawRRect(beam, Paint()..color = theme.primary);
    // danger zones at ends
    for (final s in [-1, 1]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(s * (half - 14), 0), width: 30, height: 22),
            const Radius.circular(10)),
        Paint()..color = const Color(0xFFE4572E).withValues(alpha: 0.75),
      );
    }
    // ball on beam surface
    final bx = (ballX.clamp(-1.05, 1.05)) * half;
    final ballC = Offset(bx, -11 - 15);
    canvas.drawCircle(ballC, 15, Paint()..color = theme.accent);
    canvas.drawCircle(ballC + const Offset(-5, -5), 5, Paint()..color = theme.text.withValues(alpha: 0.5));
    canvas.restore();
    // gust arrows
    if (gust.abs() > 0.4) {
      final a = Paint()
        ..color = theme.secondary.withValues(alpha: 0.8)
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;
      final y = cy - 110;
      for (var i = 0; i < 3; i++) {
        final x = gustDir > 0 ? 30.0 + i * 26 : size.width - 30 - i * 26;
        canvas.drawLine(Offset(x, y), Offset(x + gustDir * 20, y), a);
      }
    }
    if (!started) {
      final tp = TextPainter(
        text: TextSpan(
            text: 'Drag to begin 👆',
            style: TextStyle(color: theme.muted, fontSize: 18, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - 180));
    }
  }

  @override
  bool shouldRepaint(covariant _BeamPainter old) => true;
}
