import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../engine/balance_engine.dart';
import '../theme/balance_themes.dart';

/// Persisted settings + stats for Balance It. Survives app restarts.
///
/// Stores: audio toggles, the renameable player profile, game-mode choice,
/// theme/appearance (incl. custom theme colors), Pro unlock state, and
/// lifetime stats (best times per survive tier, best endless time, best
/// score-attack score).
class BalanceSettings extends ChangeNotifier {
  static const _kMusic = 'balance_music_on';
  static const _kSfx = 'balance_sfx_on';
  static const _kVolume = 'balance_volume';
  static const _kMode = 'balance_mode_id';
  static const _kTheme = 'balance_theme_id';
  static const _kBall = 'balance_ball_style';
  static const _kIsPro = 'balance_is_pro';
  static const _kGames = 'balance_games_played';
  static const _kWins = 'balance_wins';
  static const _kBestCalm = 'balance_best_calm';
  static const _kBestBreezy = 'balance_best_breezy';
  static const _kBestStormy = 'balance_best_stormy';
  static const _kBestEndless = 'balance_best_endless';
  static const _kBestScore = 'balance_best_score';
  static const _kCustomPrefix = 'balance_custom_';

  /// Order-safe player profile storage: ONE order-preserving JSON string
  /// via setString. NEVER use setStringList for ordered data on Android —
  /// SharedPreferences stores lists as an unordered StringSet and scrambles
  /// order. Saved on every keystroke; committed on focus loss.
  static const _kProfileJson = 'balanceit_player_names_json';

  /// Legacy v1 keys, migrated once then removed.
  static const _kLegacyProfileMap = 'balance_profile_json';
  static const _kLegacyBest = 'balance_best';

  static const defaultPlayerName = 'Player';

  /// Encode as a single-element JSON array (order-preserving by construction).
  static String encodeProfile(String name) => jsonEncode(
      [name.trim().isEmpty ? defaultPlayerName : name.trim()]);

  static String decodeProfile(String? raw) {
    if (raw == null) return defaultPlayerName;
    try {
      final d = jsonDecode(raw);
      if (d is List && d.isNotEmpty && d.first is String) {
        final n = (d.first as String).trim();
        if (n.isNotEmpty) return n;
      }
      // Legacy v1 map form: {"name": "..."}.
      if (d is Map && d['name'] is String) {
        final n = (d['name'] as String).trim();
        if (n.isNotEmpty) return n;
      }
    } catch (_) {}
    return defaultPlayerName;
  }

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;
  String playerName = defaultPlayerName;
  String modeId = 'breezy';
  String themeId = 'classic';
  int ballStyle = 0;
  bool isPro = true; // everything unlocked — no Pro version
  int gamesPlayed = 0;
  int wins = 0;
  double bestCalm = 0;
  double bestBreezy = 0;
  double bestStormy = 0;
  double bestEndless = 0;
  double bestScore = 0;

  /// Custom theme colors (ARGB ints). Defaults mirror Classic Oak.
  Map<String, int> customColors = Map.of(_defaultCustomColors);

  static const Map<String, int> _defaultCustomColors = {
    'woodDark': 0xFF7A4E2A,
    'woodMid': 0xFFA9743F,
    'woodDeep': 0xFF4E2F17,
    'accent': 0xFFC9A227,
    'accentLight': 0xFFE8CE7A,
    'accentDark': 0xFF8A6D1A,
    'ivory': 0xFFF5EFE0,
    'felt': 0xFF2E2318,
    'danger': 0xFFE4572E,
    'ball': 0xFFB07B45,
    'ballHi': 0xFFE8C48A,
  };

  static const List<String> customColorLabels = [
    'woodDark',
    'woodMid',
    'woodDeep',
    'accent',
    'accentLight',
    'accentDark',
    'ivory',
    'felt',
    'danger',
    'ball',
    'ballHi',
  ];

  static const Map<String, String> customColorNames = {
    'woodDark': 'Beam dark',
    'woodMid': 'Beam mid',
    'woodDeep': 'Backdrop',
    'accent': 'Trim',
    'accentLight': 'Trim light',
    'accentDark': 'Trim dark',
    'ivory': 'Text',
    'felt': 'Felt',
    'danger': 'Danger zones',
    'ball': 'Ball',
    'ballHi': 'Ball shine',
  };

  /// Builds the user-designed custom theme from stored colors.
  BalanceThemeDef get customTheme {
    Color c(String k) => Color(customColors[k] ?? 0xFF000000);
    return BalanceThemeDef(
      id: 'custom',
      name: 'My Creation',
      woodDark: c('woodDark'),
      woodMid: c('woodMid'),
      woodDeep: c('woodDeep'),
      accent: c('accent'),
      accentLight: c('accentLight'),
      accentDark: c('accentDark'),
      ivory: c('ivory'),
      felt: c('felt'),
      danger: c('danger'),
    );
  }

  Color get customBallBase => Color(customColors['ball'] ?? 0xFFB07B45);
  Color get customBallHi => Color(customColors['ballHi'] ?? 0xFFE8C48A);

  BalanceMode get mode => switch (modeId) {
        'calm' => BalanceMode.calm,
        'stormy' => BalanceMode.stormy,
        'endless' => BalanceMode.endless,
        'score' => BalanceMode.score,
        _ => BalanceMode.breezy,
      };

  static const modeNames = {
    'calm': 'Calm',
    'breezy': 'Breezy',
    'stormy': 'Stormy',
    'endless': 'Endless',
    'score': 'Score Attack',
  };

  static const modeBlurb = {
    'calm': '45s · gentle gusts · easy',
    'breezy': '60s · classic balance',
    'stormy': '90s · fierce gusts · PRO',
    'endless': 'No timer · survive as long as you can',
    'score': '90s · stay in the golden zone',
  };

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    musicOn = p.getBool(_kMusic) ?? true;
    sfxOn = p.getBool(_kSfx) ?? true;
    volume = p.getDouble(_kVolume) ?? 0.8;
    playerName = decodeProfile(p.getString(_kProfileJson));
    modeId = p.getString(_kMode) ?? 'breezy';
    themeId = p.getString(_kTheme) ?? 'classic';
    ballStyle = (p.getInt(_kBall) ?? 0).clamp(0, BallStyles.styles.length - 1);
    isPro = true; // everything unlocked
    gamesPlayed = p.getInt(_kGames) ?? 0;
    wins = p.getInt(_kWins) ?? 0;
    bestCalm = p.getDouble(_kBestCalm) ?? 0;
    bestBreezy = p.getDouble(_kBestBreezy) ?? 0;
    bestStormy = p.getDouble(_kBestStormy) ?? 0;
    bestEndless = p.getDouble(_kBestEndless) ?? 0;
    bestScore = p.getDouble(_kBestScore) ?? 0;
    for (final k in _defaultCustomColors.keys) {
      customColors[k] =
          p.getInt('$_kCustomPrefix$k') ?? _defaultCustomColors[k]!;
    }
    // Legacy profile-key migration (v1): the profile lived under a different
    // key. Migrate it into the order-preserving JSON string, then drop it.
    if (p.containsKey(_kLegacyProfileMap)) {
      playerName = decodeProfile(p.getString(_kLegacyProfileMap));
      await p.remove(_kLegacyProfileMap);
      await p.setString(_kProfileJson, encodeProfile(playerName));
    }
    // Legacy migration (v1): the old single best-time key seeds Breezy's
    // best, then is dropped for good.
    if (p.containsKey(_kLegacyBest)) {
      final legacy = p.getDouble(_kLegacyBest) ?? 0;
      if (legacy > bestBreezy) bestBreezy = legacy;
      await p.remove(_kLegacyBest);
    }
    _enforceFreeLimits(silent: true);
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setBool(_kMusic, musicOn);
    await p.setBool(_kSfx, sfxOn);
    await p.setDouble(_kVolume, volume);
    await p.setString(_kProfileJson, encodeProfile(playerName));
    await p.setString(_kMode, modeId);
    await p.setString(_kTheme, themeId);
    await p.setInt(_kBall, ballStyle);
    await p.setBool(_kIsPro, isPro);
    await p.setInt(_kGames, gamesPlayed);
    await p.setInt(_kWins, wins);
    await p.setDouble(_kBestCalm, bestCalm);
    await p.setDouble(_kBestBreezy, bestBreezy);
    await p.setDouble(_kBestStormy, bestStormy);
    await p.setDouble(_kBestEndless, bestEndless);
    await p.setDouble(_kBestScore, bestScore);
    for (final e in customColors.entries) {
      await p.setInt('$_kCustomPrefix${e.key}', e.value);
    }
  }

  /// Free-tier limits: clamp pro-only choices back when not Pro.
  void _enforceFreeLimits({bool silent = false}) {
    if (isPro) return;
    var changed = false;
    if (themeId == 'custom' || BalanceThemes.isProTheme(themeId)) {
      themeId = 'classic';
      changed = true;
    }
    if (BallStyles.isPro(ballStyle)) {
      ballStyle = 0;
      changed = true;
    }
    if (modeId == 'stormy') {
      modeId = 'breezy';
      changed = true;
    }
    if (changed && !silent) {
      notifyListeners();
      _save();
    }
  }

  Future<void> setPro(bool v) async {
    isPro = v;
    if (!v) _enforceFreeLimits();
    notifyListeners();
    await _save();
  }

  Future<void> setCustomColor(String key, int argb) async {
    if (!isPro) return;
    if (!_defaultCustomColors.containsKey(key)) return;
    customColors[key] = argb;
    notifyListeners();
    await _save();
  }

  Future<void> resetCustomColors() async {
    customColors = Map.of(_defaultCustomColors);
    notifyListeners();
    await _save();
  }

  Future<void> setMusic(bool v) async {
    musicOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    notifyListeners();
    await _save();
  }

  Future<void> setPlayerName(String name) async {
    final clean = name.trim();
    playerName = clean.isEmpty ? defaultPlayerName : clean;
    notifyListeners();
    await _save();
  }

  Future<void> setMode(String id) async {
    if (!modeNames.containsKey(id)) return;
    // Stormy is a Pro difficulty tier.
    if (id == 'stormy' && !isPro) return;
    modeId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setTheme(String id) async {
    if (!isPro && (id == 'custom' || BalanceThemes.isProTheme(id))) return;
    themeId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setBallStyle(int v) async {
    v = v.clamp(0, BallStyles.styles.length - 1);
    if (!isPro && BallStyles.isPro(v)) return;
    ballStyle = v;
    notifyListeners();
    await _save();
  }

  /// Record a finished run. [value] is seconds survived for survive/endless
  /// modes, or the final score for score attack. Returns true when a new
  /// personal best was set.
  Future<bool> noteResult({
    required BalanceMode mode,
    required bool won,
    required double value,
  }) async {
    gamesPlayed++;
    var newBest = false;
    switch (mode) {
      case BalanceMode.calm:
        if (won) {
          wins++;
          if (bestCalm == 0 || value > bestCalm) {
            bestCalm = value;
            newBest = true;
          }
        }
      case BalanceMode.breezy:
        if (won) {
          wins++;
          if (bestBreezy == 0 || value > bestBreezy) {
            bestBreezy = value;
            newBest = true;
          }
        }
      case BalanceMode.stormy:
        if (won) {
          wins++;
          if (bestStormy == 0 || value > bestStormy) {
            bestStormy = value;
            newBest = true;
          }
        }
      case BalanceMode.endless:
        if (value > bestEndless) {
          bestEndless = value;
          newBest = true;
        }
      case BalanceMode.score:
        if (value > bestScore) {
          bestScore = value;
          newBest = true;
        }
    }
    notifyListeners();
    await _save();
    return newBest;
  }

  /// Best display line for the current mode.
  String bestLine() => switch (mode) {
        BalanceMode.calm =>
          bestCalm > 0 ? 'Best: ${bestCalm.toStringAsFixed(1)}s' : '',
        BalanceMode.breezy =>
          bestBreezy > 0 ? 'Best: ${bestBreezy.toStringAsFixed(1)}s' : '',
        BalanceMode.stormy =>
          bestStormy > 0 ? 'Best: ${bestStormy.toStringAsFixed(1)}s' : '',
        BalanceMode.endless =>
          bestEndless > 0 ? 'Best: ${bestEndless.toStringAsFixed(1)}s' : '',
        BalanceMode.score =>
          bestScore > 0 ? 'Best: ${bestScore.round()}' : '',
      };
}
