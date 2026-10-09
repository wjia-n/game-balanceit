import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// Balance It — engine. Deterministic rules, state, physics. UI-agnostic.
//
// A single-player workshop-balance arcade game: keep the ball on the beam.
// The engine owns ALL phases and the physics clock; a watchdog recovers any
// phase found without a live timer, so stuck states are impossible by
// construction. The UI only renders and feeds tilt input.
// ---------------------------------------------------------------------------

/// Game modes. Survive tiers scale speed/complexity; endless and
/// score-attack are score-chasing modes.
enum BalanceMode { calm, breezy, stormy, endless, score }

/// Engine-owned phases. The UI only renders.
enum BalancePhase { ready, countdown, playing, paused, over }

/// Result of a finished run.
enum BalanceResult { none, won, lost }

/// UI hook for sounds / narration cues.
enum BalanceEvent {
  click,
  countdownTick,
  go,
  gustWarn,
  gust,
  danger,
  recover,
  milestone,
  scoreTick,
  win,
  lose,
}

/// Per-mode physics + rules spec (RULES.md §5, §8).
class DifficultySpec {
  /// Seconds to survive to win. 0 = no time win (endless).
  final double goalSeconds;

  /// Score-attack window seconds. 0 = not a score mode.
  final double scoreWindow;

  /// Gravity gain along the beam tilt.
  final double tiltGain;

  /// Max beam tilt (radians).
  final double tiltMax;

  /// Base gust strength.
  final double gustBase;

  /// Gust scheduling bounds (seconds).
  final double gustMin;
  final double gustMax;

  /// Ball velocity damping (1/s).
  final double damp;

  const DifficultySpec({
    required this.goalSeconds,
    required this.scoreWindow,
    required this.tiltGain,
    required this.tiltMax,
    required this.gustBase,
    required this.gustMin,
    required this.gustMax,
    required this.damp,
  });
}

const _specs = <BalanceMode, DifficultySpec>{
  BalanceMode.calm: DifficultySpec(
    goalSeconds: 45,
    scoreWindow: 0,
    tiltGain: 2.9,
    tiltMax: 0.5,
    gustBase: 1.6,
    gustMin: 6.0,
    gustMax: 9.5,
    damp: 0.42,
  ),
  BalanceMode.breezy: DifficultySpec(
    goalSeconds: 60,
    scoreWindow: 0,
    tiltGain: 3.4,
    tiltMax: 0.55,
    gustBase: 2.6,
    gustMin: 3.8,
    gustMax: 7.2,
    damp: 0.35,
  ),
  BalanceMode.stormy: DifficultySpec(
    goalSeconds: 90,
    scoreWindow: 0,
    tiltGain: 4.1,
    tiltMax: 0.6,
    gustBase: 3.6,
    gustMin: 2.6,
    gustMax: 5.0,
    damp: 0.28,
  ),
  BalanceMode.endless: DifficultySpec(
    goalSeconds: 0,
    scoreWindow: 0,
    tiltGain: 3.4,
    tiltMax: 0.55,
    gustBase: 2.6,
    gustMin: 3.8,
    gustMax: 7.2,
    damp: 0.35,
  ),
  BalanceMode.score: DifficultySpec(
    goalSeconds: 0,
    scoreWindow: 90,
    tiltGain: 3.4,
    tiltMax: 0.55,
    gustBase: 2.6,
    gustMin: 3.8,
    gustMax: 7.2,
    damp: 0.35,
  ),
};

class BalanceEngine extends ChangeNotifier {
  final BalanceMode mode;
  DifficultySpec get spec => _specs[mode]!;

  BalancePhase phase = BalancePhase.ready;
  BalanceResult result = BalanceResult.none;

  // Physics state.
  double tilt = 0; // radians, + = right side down
  double targetTilt = 0;
  double ballX = 0; // -1..1 along the beam
  double ballV = 0;
  double elapsed = 0;
  double score = 0;

  // Gust state.
  double gust = 0;
  double gustDir = 0;
  double _gustT = 4;
  double _nextGustStrength = 0;
  double _nextGustDir = 0;
  bool _warned = false;

  // Countdown + narration.
  int countdown = 0;
  String banner = '';
  bool newBest = false;

  /// UI hook for sounds. Set by the screen.
  void Function(BalanceEvent event)? onEvent;

  final Random _rand;
  Timer? _tick; // physics clock (playing)
  Timer? _countdownTimer; // countdown clock
  Timer? _watchdog; // stuck-state recovery
  bool _disposed = false;
  bool _wasDanger = false;
  double _lastMilestone = 0;
  double _scoreTickAcc = 0;
  DateTime? _countdownStuckAt;

  BalanceEngine({required this.mode, Random? rand})
      : _rand = rand ?? Random() {
    _resetGustSchedule();
    banner = _readyBanner();
    _watchdog = Timer.periodic(const Duration(seconds: 3), (_) => _recover());
  }

  static const double _dt = 1 / 60;

  String _readyBanner() => switch (mode) {
        BalanceMode.calm => 'A gentle warm-up. Drag to begin!',
        BalanceMode.breezy => 'Drag anywhere to tilt the beam!',
        BalanceMode.stormy => 'Stormy seas ahead. Steady now…',
        BalanceMode.endless => 'How long can you last? Drag to begin!',
        BalanceMode.score => '90 seconds. Stay centered. Drag to begin!',
      };

  String get modeName => switch (mode) {
        BalanceMode.calm => 'Calm',
        BalanceMode.breezy => 'Breezy',
        BalanceMode.stormy => 'Stormy',
        BalanceMode.endless => 'Endless',
        BalanceMode.score => 'Score Attack',
      };

  bool get isPlaying => phase == BalancePhase.playing;
  bool get isOver => phase == BalancePhase.over;

  /// Progress 0..1 toward the goal (survive + score modes). Endless: 0.
  double get progress {
    final goal = spec.goalSeconds > 0 ? spec.goalSeconds : spec.scoreWindow;
    if (goal <= 0) return 0;
    return (elapsed / goal).clamp(0.0, 1.0);
  }

  /// Seconds left in score mode.
  double get timeLeft =>
      (spec.scoreWindow - elapsed).clamp(0.0, spec.scoreWindow);

  @override
  void dispose() {
    _disposed = true;
    _tick?.cancel();
    _countdownTimer?.cancel();
    _watchdog?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------ input
  /// Tilt input from the UI: finger x as -1..1 across the play area.
  /// Also auto-starts a run from the ready phase (first touch).
  void setTiltFraction(double nx) {
    if (_disposed || phase == BalancePhase.over) return;
    if (phase == BalancePhase.paused) return;
    if (phase == BalancePhase.ready) {
      startRun();
    }
    if (phase != BalancePhase.playing && phase != BalancePhase.countdown) {
      return;
    }
    targetTilt = (nx * spec.tiltMax).clamp(-spec.tiltMax, spec.tiltMax);
    // Tiny immediate response so the beam feels alive even in countdown.
    if (phase == BalancePhase.countdown) notifyListeners();
  }

  /// Begin a run: 3-2-1-GO countdown, then the physics clock starts.
  void startRun() {
    if (_disposed || phase == BalancePhase.playing) return;
    if (phase == BalancePhase.countdown || phase == BalancePhase.paused) {
      return;
    }
    _resetRunState();
    phase = BalancePhase.countdown;
    countdown = 3;
    _countdownStuckAt = DateTime.now();
    banner = 'Get ready…';
    onEvent?.call(BalanceEvent.countdownTick);
    notifyListeners();
    _countdownTimer?.cancel();
    _countdownTimer =
        Timer.periodic(const Duration(milliseconds: 650), (_) => _countdownStep());
  }

  void _countdownStep() {
    if (_disposed || phase != BalancePhase.countdown) return;
    countdown--;
    if (countdown <= 0) {
      _countdownTimer?.cancel();
      _countdownTimer = null;
      phase = BalancePhase.playing;
      banner = _goBanner();
      onEvent?.call(BalanceEvent.go);
      _armTick();
      notifyListeners();
    } else {
      onEvent?.call(BalanceEvent.countdownTick);
      notifyListeners();
    }
  }

  String _goBanner() => switch (mode) {
        BalanceMode.score => 'Stay in the golden zone!',
        BalanceMode.endless => 'Stay alive!',
        _ => 'Keep it centered!',
      };

  // ------------------------------------------------------------ pause
  /// Freeze the physics clock. Resume re-arms the current phase.
  void setPaused(bool v) {
    if (_disposed) return;
    if (v) {
      if (phase != BalancePhase.playing && phase != BalancePhase.countdown) {
        return;
      }
      _tick?.cancel();
      _tick = null;
      _countdownTimer?.cancel();
      _countdownTimer = null;
      phase = BalancePhase.paused;
      notifyListeners();
    } else {
      if (phase != BalancePhase.paused) return;
      // Resume where we were: countdown restarts fresh, playing re-arms.
      if (countdown > 0 && elapsed == 0) {
        phase = BalancePhase.countdown;
        _countdownTimer = Timer.periodic(
            const Duration(milliseconds: 650), (_) => _countdownStep());
      } else {
        phase = BalancePhase.playing;
        _armTick();
      }
      notifyListeners();
    }
  }

  // ------------------------------------------------------------ watchdog
  /// Watchdog: if a phase ever loses its live timer, recover. This makes
  /// stuck states impossible by construction. Respects pause/dispose.
  void _recover() {
    if (_disposed || phase == BalancePhase.paused) return;
    if (phase == BalancePhase.playing && _tick == null && !isOver) {
      _armTick(); // physics clock died: restart it
    } else if (phase == BalancePhase.countdown && _countdownTimer == null) {
      // Countdown lost its timer (e.g. backgrounding): restart it.
      final stuck = _countdownStuckAt;
      if (stuck == null ||
          DateTime.now().difference(stuck).inSeconds > 5) {
        countdown = 3;
        _countdownStuckAt = DateTime.now();
        _countdownTimer = Timer.periodic(
            const Duration(milliseconds: 650), (_) => _countdownStep());
        notifyListeners();
      }
    }
  }

  void _armTick() {
    if (_disposed || phase != BalancePhase.playing) return;
    _tick?.cancel();
    _tick = Timer.periodic(
        Duration(microseconds: (_dt * 1e6).round()), (_) => _step());
  }

  // ------------------------------------------------------------ physics
  void _step() {
    if (_disposed || phase != BalancePhase.playing) return;

    elapsed += _dt;
    // Difficulty ramp: gusts grow stronger + more frequent over time
    // (RULES.md §5 — speed/complexity scaling).
    final ramp = 1 + (elapsed / 75).clamp(0.0, 0.8);
    final tiltGain = spec.tiltGain * (mode == BalanceMode.endless
        ? 1 + (elapsed / 120).clamp(0.0, 0.35)
        : 1.0);

    // Smooth tilt toward the finger target.
    tilt += (targetTilt - tilt) * min(1.0, 8 * _dt);

    // --- gusts ---
    _gustT -= _dt;
    if (_gustT <= 0.8 && !_warned && _nextGustStrength > spec.gustBase * 1.15) {
      _warned = true;
      banner = _nextGustDir > 0 ? 'Gust from the left! 💨' : 'Gust from the right! 💨';
      onEvent?.call(BalanceEvent.gustWarn);
    }
    if (_gustT <= 0) {
      gust = _nextGustStrength * ramp;
      gustDir = _nextGustDir;
      banner = gustDir > 0 ? '💨 Whoosh →' : '💨 ← Whoosh';
      onEvent?.call(BalanceEvent.gust);
      _scheduleNextGust(ramp);
      _warned = false;
    }
    gust *= exp(-1.6 * _dt);

    // --- ball physics ---
    final acc = tiltGain * sin(tilt) + gust * gustDir * 0.9;
    ballV += acc * _dt;
    ballV *= exp(-spec.damp * _dt);
    ballX += ballV * _dt;

    // --- danger / close-call narration ---
    final dangerNow = ballX.abs() > 0.8;
    if (dangerNow && !_wasDanger) {
      banner = 'Careful!! ⚠️';
      onEvent?.call(BalanceEvent.danger);
    }
    if (_wasDanger && ballX.abs() < 0.5) {
      if (mode == BalanceMode.score) {
        score += 5;
        banner = 'Close call! +5 ⭐';
      } else {
        banner = 'Phew! Saved it! 😅';
      }
      onEvent?.call(BalanceEvent.recover);
    }
    _wasDanger = dangerNow;

    // --- score attack scoring ---
    if (mode == BalanceMode.score) {
      final sweet = ballX.abs() < 0.35;
      score += (sweet ? 10.0 : 4.0) * _dt;
      _scoreTickAcc += _dt;
      if (_scoreTickAcc >= 1.0) {
        _scoreTickAcc = 0;
        onEvent?.call(BalanceEvent.scoreTick);
      }
    }

    // --- milestones (survive modes) ---
    if (spec.goalSeconds > 0) {
      final m = (elapsed / 15).floor() * 15.0;
      if (m > _lastMilestone && elapsed < spec.goalSeconds) {
        _lastMilestone = m;
        banner = '${m.toInt()}s — holding strong! 💪';
        onEvent?.call(BalanceEvent.milestone);
      }
    }

    // --- terminal conditions ---
    if (ballX.abs() > 1.02) {
      _finish(BalanceResult.lost);
      return;
    }
    if (spec.goalSeconds > 0 && elapsed >= spec.goalSeconds) {
      _finish(BalanceResult.won);
      return;
    }
    if (spec.scoreWindow > 0 && elapsed >= spec.scoreWindow) {
      _finish(BalanceResult.won); // window survived: score is final
      return;
    }

    notifyListeners();
  }

  void _resetGustSchedule() {
    _gustT = 4 + _rand.nextDouble() * 2;
    _nextGustStrength = 0;
    _nextGustDir = 0;
    _warned = false;
  }

  void _scheduleNextGust(double ramp) {
    final interval = (_gustMin() + _rand.nextDouble() * (_gustMax() - _gustMin())) / ramp;
    _gustT = interval.clamp(1.2, 12.0);
    _nextGustDir = _rand.nextBool() ? 1 : -1;
    _nextGustStrength =
        spec.gustBase * (0.75 + _rand.nextDouble() * 0.9);
  }

  double _gustMin() => spec.gustMin;
  double _gustMax() => spec.gustMax;

  void _finish(BalanceResult r) {
    _tick?.cancel();
    _tick = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    result = r;
    phase = BalancePhase.over;
    if (r == BalanceResult.won) {
      banner = switch (mode) {
        BalanceMode.score => 'Time! Final score: ${score.round()} ⭐',
        _ => 'You did it! 🏆',
      };
      onEvent?.call(BalanceEvent.win);
    } else {
      banner = 'The ball escaped!';
      onEvent?.call(BalanceEvent.lose);
    }
    notifyListeners();
  }

  void _resetRunState() {
    _tick?.cancel();
    _tick = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    result = BalanceResult.none;
    tilt = 0;
    targetTilt = 0;
    ballX = 0;
    ballV = 0;
    elapsed = 0;
    score = 0;
    gust = 0;
    gustDir = 0;
    _wasDanger = false;
    _lastMilestone = 0;
    _scoreTickAcc = 0;
    newBest = false;
    _resetGustSchedule();
  }

  /// Full reset back to the ready screen.
  void restart() {
    if (_disposed) return;
    _resetRunState();
    phase = BalancePhase.ready;
    banner = _readyBanner();
    notifyListeners();
  }
}
