import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/balance_engine.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/balance_art.dart';
import '../theme/balance_themes.dart';

/// Balance It game screen — Workshop Balance exemplar edition.
///
/// - The engine owns phases + physics; the UI only renders and feeds tilt.
/// - Juicy feedback for everything: countdown, gust warnings, danger flash,
///   close-call narration, milestones, win/lose overlays.
/// - Lifecycle pauses freeze the engine; the watchdog re-arms lost timers.
class GameScreen extends StatefulWidget {
  final BalanceEngine engine;
  final BalanceAudio audio;
  final BalanceSettings settings;

  const GameScreen({
    super.key,
    required this.engine,
    required this.audio,
    required this.settings,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with WidgetsBindingObserver {
  bool _paused = false;
  bool _overHandled = false;
  bool _reviewAsked = false;

  BalanceEngine get _e => widget.engine;
  BalanceThemeDef get _t => BalanceThemes.byId(widget.settings.themeId,
      custom: widget.settings.customTheme);

  static const _shareText =
      'I scored big in Balance It! ⚖️ Think you can keep your balance? '
      'https://play.google.com/store/apps/details?id=com.gameswajiha.balanceit';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _e.onEvent = _onEngineEvent;
    _e.addListener(_onEngineChanged);
    widget.audio.startGameMusic();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _e.removeListener(_onEngineChanged);
    _e.onEvent = null;
    _e.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      widget.audio.onAppPaused();
      if (!_e.isOver && mounted) {
        setState(() {
          _paused = true;
          _e.setPaused(true);
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      widget.audio.onAppResumed();
    }
  }

  void _onEngineChanged() {
    if (!mounted) return;
    setState(() {});
    if (_e.isOver && !_overHandled) {
      _overHandled = true;
      _onGameOver();
    }
  }

  Future<void> _onEngineEvent(BalanceEvent event) async {
    final a = widget.audio;
    switch (event) {
      case BalanceEvent.click:
        await a.click();
      case BalanceEvent.countdownTick:
        await a.countdownTick();
      case BalanceEvent.go:
        await a.go();
      case BalanceEvent.gustWarn:
        await a.gustWarn();
      case BalanceEvent.gust:
        await a.gust();
      case BalanceEvent.danger:
        await a.danger();
      case BalanceEvent.recover:
        await a.recover();
      case BalanceEvent.milestone:
        await a.milestone();
      case BalanceEvent.scoreTick:
        await a.scoreTick();
      case BalanceEvent.win:
        await a.win();
      case BalanceEvent.lose:
        await a.lose();
    }
  }

  Future<void> _onGameOver() async {
    final won = _e.result == BalanceResult.won;
    final value = _e.mode == BalanceMode.score ? _e.score : _e.elapsed;
    final newBest = await widget.settings.noteResult(
      mode: _e.mode,
      won: won,
      value: value,
    );
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    // Sensible review moment: 3rd win, or a fresh personal best.
    if (!_reviewAsked &&
        (widget.settings.wins == 3 || (won && newBest))) {
      _reviewAsked = true;
      _requestReview();
    }
    final again = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _GameOverDialog(
        engine: _e,
        settings: widget.settings,
        audio: widget.audio,
        theme: _t,
        newBest: newBest,
        onShare: _share,
      ),
    );
    if (!mounted) return;
    if (again == true) {
      _overHandled = false;
      _e.restart();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _requestReview() async {
    final review = InAppReview.instance;
    try {
      if (await review.isAvailable()) {
        await review.requestReview();
      }
      // Not from Play / unavailable: stay silent, no fake UI.
    } catch (_) {}
  }

  Future<void> _share() async {
    widget.audio.click();
    await SharePlus.instance.share(ShareParams(text: _shareText));
  }

  void _drag(Offset at, Size size) {
    final nx = ((at.dx / size.width) - 0.5) * 2; // -1..1
    _e.setTiltFraction(nx.clamp(-1.0, 1.0));
  }

  void _togglePause() {
    widget.audio.click();
    if (_e.isOver) return;
    setState(() {
      _paused = !_paused;
      _e.setPaused(_paused);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final e = _e;
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
          title: Text('${e.modeName}  •  ${widget.settings.playerName}',
              style: Balance.display(18, theme: t)),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(_paused ? Icons.play_arrow : Icons.pause,
                  color: t.accentLight),
              onPressed: _togglePause,
            ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _Hud(theme: t, engine: e, settings: widget.settings),
                  const SizedBox(height: 4),
                  // Narration banner.
                  SizedBox(
                    height: 46,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: e.banner.isEmpty
                            ? const SizedBox.shrink()
                            : BrassPlaque(
                                key: ValueKey(e.banner),
                                text: e.banner,
                                theme: t,
                                fontSize: 14,
                              ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (ctx, c) {
                        final s = Size(c.maxWidth, c.maxHeight);
                        return GestureDetector(
                          onPanDown: (d) =>
                              _drag(d.localPosition, s),
                          onPanUpdate: (d) =>
                              _drag(d.localPosition, s),
                          child: CustomPaint(
                            size: s,
                            painter: _BeamPainter(
                              tilt: e.tilt,
                              ballX: e.ballX,
                              gust: e.gust,
                              gustDir: e.gustDir,
                              started: e.phase != BalancePhase.ready,
                              scoreMode: e.mode == BalanceMode.score,
                              theme: t,
                              ballStyle: _ballColors(),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      e.phase == BalancePhase.ready
                          ? 'Drag anywhere to tilt the beam 👆'
                          : 'Tilt with your finger — keep it centered! 🎯',
                      style: Balance.body(13,
                          theme: t,
                          color: t.ivory.withValues(alpha: 0.65)),
                    ),
                  ),
                ],
              ),
              // Countdown overlay.
              if (e.phase == BalancePhase.countdown)
                Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      '${e.countdown}',
                      key: ValueKey(e.countdown),
                      style: Balance.display(110, theme: t),
                    ),
                  ),
                ),
              // Pause overlay.
              if (_paused && !e.isOver)
                _PauseOverlay(
                  theme: t,
                  onResume: _togglePause,
                  onRestart: () {
                    widget.audio.click();
                    setState(() {
                      _paused = false;
                      _overHandled = false;
                      _e.restart();
                    });
                  },
                  onQuit: () {
                    widget.audio.click();
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Ball colors for the current style (custom theme overrides).
  (Color, Color) _ballColors() {
    if (widget.settings.themeId == 'custom') {
      return (widget.settings.customBallBase, widget.settings.customBallHi);
    }
    final st = BallStyles.styles[
        widget.settings.ballStyle.clamp(0, BallStyles.styles.length - 1)];
    return (st.base, st.hi);
  }
}

// ---------------------------------------------------------------------------
/// HUD: timer + goal progress, score (score mode), best line.
class _Hud extends StatelessWidget {
  final BalanceThemeDef theme;
  final BalanceEngine engine;
  final BalanceSettings settings;
  const _Hud(
      {required this.theme,
      required this.engine,
      required this.settings});

  @override
  Widget build(BuildContext context) {
    final e = engine;
    final isScore = e.mode == BalanceMode.score;
    final goal = e.spec.goalSeconds > 0
        ? e.spec.goalSeconds
        : e.spec.scoreWindow;
    final timeText = isScore
        ? '⏱ ${e.timeLeft.toStringAsFixed(0)}s left'
        : goal > 0
            ? '⏱ ${e.elapsed.toStringAsFixed(1)}s / ${goal.toInt()}s'
            : '⏱ ${e.elapsed.toStringAsFixed(1)}s';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(timeText,
                  style: Balance.body(16,
                      theme: theme,
                      color: theme.accentLight)),
              if (isScore)
                Text('⭐ ${e.score.round()}',
                    style: Balance.display(20, theme: theme)),
              if (settings.bestLine().isNotEmpty)
                Text(settings.bestLine(),
                    style: Balance.body(13,
                        theme: theme,
                        color: theme.ivory.withValues(alpha: 0.7))),
            ],
          ),
          const SizedBox(height: 6),
          if (goal > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: e.progress,
                minHeight: 10,
                backgroundColor:
                    theme.woodDeep.withValues(alpha: 0.6),
                valueColor:
                    AlwaysStoppedAnimation<Color>(theme.accent),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// The beam: brass pivot stand, pseudo-3D wooden beam with danger caps,
/// physical ball, gust chevrons, score-mode golden zone.
class _BeamPainter extends CustomPainter {
  final double tilt, ballX, gust, gustDir;
  final bool started;
  final bool scoreMode;
  final BalanceThemeDef theme;
  final (Color, Color) ballStyle;

  _BeamPainter({
    required this.tilt,
    required this.ballX,
    required this.gust,
    required this.gustDir,
    required this.started,
    required this.scoreMode,
    required this.theme,
    required this.ballStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.52;
    final half = size.width * 0.42;

    // --- brass pivot stand ---
    final standPaint = Paint()
      ..shader = LinearGradient(
        colors: [theme.accentLight, theme.accent, theme.accentDark],
      ).createShader(Rect.fromLTWH(cx - 30, cy, 60, size.height - cy));
    final stand = Path()
      ..moveTo(cx - 26, size.height - 30)
      ..lineTo(cx + 26, size.height - 30)
      ..lineTo(cx + 8, cy + 16)
      ..lineTo(cx - 8, cy + 16)
      ..close();
    canvas.drawPath(stand, standPaint);
    canvas.drawCircle(Offset(cx, cy + 10), 12,
        Paint()..color = theme.accentDark);
    canvas.drawCircle(Offset(cx, cy + 10), 6,
        Paint()..color = theme.accentLight);

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(tilt);

    // --- beam: pseudo-3D (top face + front face) ---
    const beamH = 26.0;
    // front face (darker, offset down)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: const Offset(0, 7), width: half * 2, height: beamH),
        const Radius.circular(11),
      ),
      Paint()..color = theme.woodDeep,
    );
    // top face
    final beamRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset.zero, width: half * 2, height: beamH),
      const Radius.circular(11),
    );
    canvas.drawRRect(
      beamRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [theme.woodMid, theme.woodDark],
        ).createShader(
            Rect.fromCenter(center: Offset.zero, width: half * 2, height: beamH)),
    );
    // wood grain streaks on the beam
    final grain = Paint()
      ..color = theme.woodDeep.withValues(alpha: 0.35)
      ..strokeWidth = 2;
    for (final gy in [-7.0, 0.0, 7.0]) {
      canvas.drawLine(Offset(-half + 12, gy), Offset(half - 12, gy), grain);
    }
    // brass edge trim
    canvas.drawRRect(
      beamRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = theme.accent.withValues(alpha: 0.8),
    );

    // --- danger caps at both ends ---
    for (final s in [-1, 1]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(s * (half - 16), 0), width: 34, height: beamH),
          const Radius.circular(10),
        ),
        Paint()..color = theme.danger.withValues(alpha: 0.85),
      );
    }

    // --- score-mode golden zone (|x| < 0.35) ---
    if (scoreMode) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset.zero, width: half * 0.7, height: beamH),
          const Radius.circular(9),
        ),
        Paint()..color = theme.accentLight.withValues(alpha: 0.35),
      );
    }

    // --- ball ---
    final bx = ballX.clamp(-1.05, 1.05) * half;
    final ballC = Offset(bx, -beamH / 2 - 15);
    paintBall(canvas, ballC, 16, ballStyle.$1, ballStyle.$2);
    canvas.restore();

    // --- gust chevrons ---
    if (gust.abs() > 0.4) {
      final a = Paint()
        ..color = theme.accentLight.withValues(
            alpha: (0.5 + 0.4 * math.sin(DateTime.now().millisecond / 90))
                .clamp(0.2, 0.95))
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round;
      final y = cy - 120;
      for (var i = 0; i < 3; i++) {
        final x = gustDir > 0 ? 34.0 + i * 30 : size.width - 34 - i * 30;
        canvas.drawLine(Offset(x, y), Offset(x + gustDir * 22, y), a);
      }
    }

    if (!started) {
      final tp = TextPainter(
        text: TextSpan(
          text: 'Drag to begin 👆',
          style: TextStyle(
              color: theme.ivory.withValues(alpha: 0.8),
              fontSize: 18,
              fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - 200));
    }
  }

  @override
  bool shouldRepaint(covariant _BeamPainter old) => true;
}

// ---------------------------------------------------------------------------
class _PauseOverlay extends StatelessWidget {
  final BalanceThemeDef theme;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onQuit;
  const _PauseOverlay({
    required this.theme,
    required this.onResume,
    required this.onRestart,
    required this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
                colors: [theme.woodMid, theme.woodDeep],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
            border: Border.all(color: theme.accent, width: 3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Paused', style: Balance.display(28, theme: theme)),
              const SizedBox(height: 18),
              TimberButton(
                  label: '▶  Resume',
                  onTap: onResume,
                  theme: theme,
                  width: 220,
                  fontSize: 17),
              const SizedBox(height: 10),
              TimberButton(
                  label: '↻  Restart',
                  onTap: onRestart,
                  theme: theme,
                  width: 220,
                  fontSize: 17),
              const SizedBox(height: 10),
              TimberButton(
                  label: '🏠  Menu',
                  onTap: onQuit,
                  theme: theme,
                  width: 220,
                  fontSize: 17),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Win / lose dialog with stats, play-again, share.
class _GameOverDialog extends StatelessWidget {
  final BalanceEngine engine;
  final BalanceSettings settings;
  final BalanceAudio audio;
  final BalanceThemeDef theme;
  final bool newBest;
  final VoidCallback onShare;

  const _GameOverDialog({
    required this.engine,
    required this.settings,
    required this.audio,
    required this.theme,
    required this.newBest,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final e = engine;
    final won = e.result == BalanceResult.won;
    final isScore = e.mode == BalanceMode.score;
    final headline = won
        ? (isScore
            ? 'Time! ⭐ ${e.score.round()}'
            : '${settings.playerName} wins! 🏆')
        : 'The ball escaped! 💥';
    final subline = won
        ? (isScore
            ? (newBest
                ? 'New personal best — the workshop applauds! 👏'
                : 'Golden-zone master. Go again for a higher score!')
            : (newBest
                ? 'New best time: ${e.elapsed.toStringAsFixed(1)}s! 🎉'
                : 'Steady hands, legend. The ball never stood a chance.'))
        : (isScore
            ? 'Final score: ${e.score.round()}. So close — one more run?'
            : 'Survived ${e.elapsed.toStringAsFixed(1)}s. Give it another go!');
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
              colors: [theme.woodMid, theme.woodDeep],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter),
          border: Border.all(color: theme.accent, width: 3),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(won ? '🏆' : '💥',
                style: const TextStyle(fontSize: 44)),
            const SizedBox(height: 8),
            Text(headline,
                style: Balance.display(24, theme: theme),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subline,
                style: Balance.body(15, theme: theme),
                textAlign: TextAlign.center),
            if (settings.bestLine().isNotEmpty) ...[
              const SizedBox(height: 10),
              BrassPlaque(
                  text: settings.bestLine(), theme: theme, fontSize: 14),
            ],
            const SizedBox(height: 18),
            TimberButton(
              label: '↻  Play again',
              width: 220,
              fontSize: 17,
              theme: theme,
              onTap: () {
                audio.click();
                Navigator.of(context).pop(true);
              },
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _SmallBtn(
                  theme: theme,
                  icon: Icons.share,
                  label: 'Share',
                  onTap: () {
                    onShare();
                    Navigator.of(context).pop(true);
                  },
                ),
                const SizedBox(width: 12),
                _SmallBtn(
                  theme: theme,
                  icon: Icons.home,
                  label: 'Menu',
                  onTap: () {
                    audio.click();
                    Navigator.of(context).pop(false);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final BalanceThemeDef theme;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SmallBtn(
      {required this.theme,
      required this.icon,
      required this.label,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.black.withValues(alpha: 0.3),
          border: Border.all(color: theme.accent, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: theme.accentLight, size: 18),
            const SizedBox(width: 6),
            Text(label, style: Balance.label(14, theme: theme)),
          ],
        ),
      ),
    );
  }
}
