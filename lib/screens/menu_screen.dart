import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/balance_engine.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/balance_art.dart';
import '../theme/balance_themes.dart';
import 'custom_theme_screen.dart';
import 'game_screen.dart';
import 'pro_screen.dart';
import 'settings_screen.dart';

/// Main menu — Workshop Balance edition.
/// Logo, PLAY, mode setup (survive tiers / endless / score attack),
/// theme + ball style pickers, player naming, tip jar, settings.
class MenuScreen extends StatefulWidget {
  final BalanceAudio audio;
  final BalanceSettings settings;

  const MenuScreen({super.key, required this.audio, required this.settings});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final StoreService _store = StoreService();

  BalanceSettings get _s => widget.settings;
  BalanceThemeDef get _t =>
      BalanceThemes.byId(_s.themeId, custom: _s.customTheme);

  static const _shareText =
      'Can you keep your balance? ⚖️ Play Balance It with me! '
      'https://play.google.com/store/apps/details?id=com.gameswajiha.balanceit';

  @override
  void initState() {
    super.initState();
    widget.audio.startMenuMusic();
    _store.init().then((_) {
      if (mounted) setState(() {});
    });
    _store.lastThanks.addListener(_onThanks);
  }

  void _onThanks() {
    final msg = _store.lastThanks.value;
    if (msg == null || !mounted) return;
    widget.audio.win();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: Balance.body(15, theme: _t)),
        backgroundColor: _t.woodDeep,
        behavior: SnackBarBehavior.floating,
      ),
    );
    _store.lastThanks.value = null;
  }

  
  @override
  void dispose() {
    _store.lastThanks.removeListener(_onThanks);
    _store.dispose();
    super.dispose();
  }

  /// Real in-app review flow: the Play in-app review sheet when available,
  /// otherwise fall back to opening the store listing. No fake dialogs.
  Future<void> _requestReview() async {
    final review = InAppReview.instance;
    try {
      if (await review.isAvailable()) {
        await review.requestReview();
      } else {
        await review.openStoreListing(appStoreId: null);
      }
    } catch (_) {
      // Review UI unavailable on this device/build: stay silent, no fake UI.
    }
  }

  void _play() {
    widget.audio.gameStart();
    final engine = BalanceEngine(mode: _s.mode);
    Navigator.of(context)
        .push(MaterialPageRoute(
      builder: (_) => GameScreen(
        engine: engine,
        audio: widget.audio,
        settings: _s,
      ),
    ))
        .then((_) {
      if (mounted) widget.audio.startMenuMusic();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return WorkshopBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _s,
            builder: (_, _) => SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  // Logo plaque.
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: t.accent, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          offset: const Offset(0, 8),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset('assets/balanceit_logo.png',
                        fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 14),
                  Text('Balance It', style: Balance.display(44, theme: t)),
                  Text(
                    'THE WORKSHOP BALANCE EDITION',
                    style: Balance.label(12, theme: t),
                  ),
                  const SizedBox(height: 22),
                  TimberButton(
                      label: '▶  Play', onTap: _play, theme: t, width: 260),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      widget.audio.click();
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ProScreen(
                          audio: widget.audio,
                          settings: _s,
                          store: _store,
                        ),
                      ));
                    },
                    child: Container(
                      width: 260,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(colors: [
                          t.accent.withValues(alpha: 0.9),
                          t.accentDark,
                        ]),
                        border:
                            Border.all(color: t.accentLight, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            offset: const Offset(0, 4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '☕  Tip Jar',
                        style: Balance.label(17,
                            theme: t, color: t.woodDeep),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _ModeCard(theme: t),
                  const SizedBox(height: 14),
                  _StyleCard(theme: t),
                  const SizedBox(height: 14),
                  _NameCard(theme: t),
                  const SizedBox(height: 14),
                  _SupportCard(theme: t, store: _store),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _MenuIcon(
                        theme: t,
                        icon: Icons.share,
                        label: 'Share',
                        onTap: () async {
                          widget.audio.click();
                          await SharePlus.instance
                              .share(ShareParams(text: _shareText));
                        },
                      ),
                      const SizedBox(width: 22),
                      _MenuIcon(
                        theme: t,
                        icon: Icons.star_rate,
                        label: 'Rate',
                        onTap: () async {
                          widget.audio.click();
                          await _requestReview();
                        },
                      ),
                      const SizedBox(width: 22),
                      _MenuIcon(
                        theme: t,
                        icon: Icons.settings,
                        label: 'Settings',
                        onTap: () async {
                          widget.audio.click();
                          await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => SettingsScreen(
                              audio: widget.audio,
                              settings: _s,
                            ),
                          ));
                          if (mounted) setState(() {});
                        },
                      ),
                      const SizedBox(width: 26),
                      _MenuIcon(
                        theme: t,
                        icon: Icons.help_outline,
                        label: 'How to Play',
                        onTap: () {
                          widget.audio.click();
                          _showHowTo(context, t);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (_s.gamesPlayed > 0)
                    Text(
                      'Wins: ${_s.wins}   •   Runs: ${_s.gamesPlayed}',
                      style: Balance.label(12, theme: t),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/wajiha_logo.png',
                          width: 22, height: 22, fit: BoxFit.contain),
                      const SizedBox(width: 8),
                      Text('Credits: WAJIHA',
                          style: Balance.label(12, theme: t)),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showHowTo(BuildContext context, BalanceThemeDef t) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
                colors: [t.woodMid, t.woodDeep],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
            border: Border.all(color: t.accent, width: 3),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('How to Play', style: Balance.display(24, theme: t)),
                const SizedBox(height: 12),
                for (final line in [
                  '• Drag anywhere to tilt the beam under the ball.',
                  '• Keep the ball from rolling off either end.',
                  '• Watch for gusts of wind — they shove the ball! 💨',
                  '• Survive the full timer to win your mode.',
                  '• Score Attack: keep the ball in the golden zone.',
                  '• The longer you last, the fiercer it gets.',
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(line, style: Balance.body(14, theme: t)),
                  ),
                const SizedBox(height: 16),
                Center(
                  child: TimberButton(
                    label: 'Got it!',
                    width: 180,
                    fontSize: 16,
                    theme: t,
                    onTap: () {
                      widget.audio.click();
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _MenuIcon extends StatelessWidget {
  final BalanceThemeDef theme;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuIcon(
      {required this.theme,
      required this.icon,
      required this.label,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [theme.woodMid, theme.woodDeep],
              ),
              border: Border.all(color: theme.accent, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  offset: const Offset(0, 4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(icon, color: theme.accentLight, size: 28),
          ),
          const SizedBox(height: 6),
          Text(label, style: Balance.label(12, theme: theme)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Mode setup: survive tiers, endless, score attack.
class _ModeCard extends StatelessWidget {
  final BalanceThemeDef theme;
  const _ModeCard({required this.theme});

  static const _modes = ['calm', 'breezy', 'stormy', 'endless', 'score'];

  Future<void> _goPro(BuildContext context, _MenuScreenState screen) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProScreen(
        audio: screen.widget.audio,
        settings: screen._s,
        store: screen._store,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_MenuScreenState>()!;
    final s = screen._s;
    final audio = screen.widget.audio;
    return WoodCard(
      theme: theme,
      title: 'Game Mode',
      child: Column(
        children: [
          for (final id in _modes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _ModeRow(
                theme: theme,
                id: id,
                selected: s.modeId == id,
                locked: id == 'stormy' && !s.isPro,
                onTap: () {
                  audio.click();
                  if (id == 'stormy' && !s.isPro) {
                    _goPro(context, screen);
                    return;
                  }
                  s.setMode(id);
                },
              ),
            ),
          if (s.bestLine().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(s.bestLine(),
                  style: Balance.label(13, theme: theme)),
            ),
        ],
      ),
    );
  }
}

class _ModeRow extends StatelessWidget {
  final BalanceThemeDef theme;
  final String id;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;
  const _ModeRow({
    required this.theme,
    required this.id,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = BalanceSettings.modeNames[id] ?? id;
    final blurb = BalanceSettings.modeBlurb[id] ?? '';
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? theme.accent.withValues(alpha: 0.9)
              : Colors.black.withValues(alpha: 0.3),
          border: Border.all(
            color: selected
                ? theme.accentLight
                : theme.accent.withValues(alpha: 0.5),
            width: selected ? 2.5 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${locked ? '🔒 ' : ''}$name',
                    style: Balance.label(15,
                        theme: theme,
                        color: selected ? theme.woodDeep : theme.ivory),
                  ),
                  Text(
                    blurb,
                    style: Balance.body(12,
                        theme: theme,
                        color: selected
                            ? theme.woodDeep.withValues(alpha: 0.8)
                            : theme.ivory.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle,
                  color: selected ? theme.woodDeep : theme.accentLight),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Style picker: 12 workshop themes + custom creator, 9 ball materials.
class _StyleCard extends StatelessWidget {
  final BalanceThemeDef theme;
  const _StyleCard({required this.theme});

  Future<void> _goPro(BuildContext context, _MenuScreenState screen) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProScreen(
        audio: screen.widget.audio,
        settings: screen._s,
        store: screen._store,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_MenuScreenState>()!;
    final s = screen._s;
    final audio = screen.widget.audio;
    final isPro = s.isPro;
    return WoodCard(
      theme: theme,
      title: 'Workshop Style',
      child: Column(
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              for (final th in BalanceThemes.all)
                _ThemeTile(
                  theme: theme,
                  th: th,
                  selected: s.themeId == th.id,
                  locked:
                      BalanceThemes.isProTheme(th.id) && !isPro,
                  onTap: () {
                    audio.click();
                    if (BalanceThemes.isProTheme(th.id) && !isPro) {
                      _goPro(context, screen);
                      return;
                    }
                    s.setTheme(th.id);
                  },
                ),
              _ThemeTile(
                theme: theme,
                th: s.customTheme,
                selected: s.themeId == 'custom',
                locked: !isPro,
                custom: true,
                onTap: () {
                  audio.click();
                  if (!isPro) {
                    _goPro(context, screen);
                    return;
                  }
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CustomThemeScreen(
                      audio: audio,
                      settings: s,
                    ),
                  ));
                },
              ),
            ],
          ),
          if (!isPro)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '🔒 ${BalanceThemes.all.length - BalanceThemes.freeThemeIds.length} more themes in PRO',
                style: Balance.label(12, theme: theme),
              ),
            ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child:
                Text('Ball material:', style: Balance.body(15, theme: theme)),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 0; i < BallStyles.styles.length; i++)
                _BallChip(
                  theme: theme,
                  style: BallStyles.styles[i],
                  selected: s.ballStyle == i,
                  locked: BallStyles.isPro(i) && !isPro,
                  onTap: () {
                    audio.click();
                    if (BallStyles.isPro(i) && !isPro) {
                      _goPro(context, screen);
                      return;
                    }
                    s.setBallStyle(i);
                  },
                ),
            ],
          ),
          if (!isPro)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '🔒 ${BallStyles.styles.length - BallStyles.freeCount} more ball materials in PRO',
                style: Balance.label(12, theme: theme),
              ),
            ),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final BalanceThemeDef theme;
  final BalanceThemeDef th;
  final bool selected;
  final bool locked;
  final bool custom;
  final VoidCallback onTap;
  const _ThemeTile({
    required this.theme,
    required this.th,
    required this.selected,
    required this.locked,
    required this.onTap,
    this.custom = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 96,
            padding:
                const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: th.woodDeep.withValues(alpha: 0.7),
              border: Border.all(
                color: selected
                    ? th.accentLight
                    : th.accent.withValues(alpha: 0.35),
                width: selected ? 3 : 1.5,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 26,
                      height: 14,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                            colors: [th.woodMid, th.accent]),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: th.accent,
                        border: Border.all(
                            color: th.accentLight, width: 1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  custom ? '🎨 My Creation' : th.name,
                  style: Balance.label(10, theme: th),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (locked)
            Container(
              width: 96,
              height: 62,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.black.withValues(alpha: 0.55),
              ),
              child: Icon(Icons.lock,
                  color: theme.accentLight, size: 22),
            ),
        ],
      ),
    );
  }
}

class _BallChip extends StatelessWidget {
  final BalanceThemeDef theme;
  final BallStyle style;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;
  const _BallChip({
    required this.theme,
    required this.style,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            margin:
                const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: selected
                  ? theme.accent.withValues(alpha: 0.85)
                  : Colors.black.withValues(alpha: 0.3),
              border: Border.all(
                color: selected
                    ? theme.accentLight
                    : theme.accent.withValues(alpha: 0.5),
                width: selected ? 2.5 : 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [style.hi, style.base],
                    ),
                    border: Border.all(
                        color: Colors.black.withValues(alpha: 0.3)),
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  '${locked ? '🔒 ' : ''}${style.name}',
                  style: Balance.label(13,
                      theme: theme,
                      color: selected
                          ? theme.woodDeep
                          : theme.ivory),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Rename the player profile.
class _NameCard extends StatelessWidget {
  final BalanceThemeDef theme;
  const _NameCard({required this.theme});

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_MenuScreenState>()!;
    final s = screen._s;
    return WoodCard(
      theme: theme,
      title: 'Player Name',
      child: Column(
        children: [
          _NameField(
            theme: theme,
            initial: s.playerName,
            // Save on EVERY keystroke (not just keyboard-done); the focus
            // listener commits once more on focus loss.
            onChanged: (v) => s.setPlayerName(v),
            onCommit: (v) => s.setPlayerName(v),
          ),
          const SizedBox(height: 8),
          Text(
            'Your name shows on the victory board and best-time plaques.',
            style: Balance.body(12,
                theme: theme,
                color: theme.ivory.withValues(alpha: 0.6)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NameField extends StatefulWidget {
  final BalanceThemeDef theme;
  final String initial;
  final ValueChanged<String> onChanged; // every keystroke
  final ValueChanged<String> onCommit; // focus loss / keyboard done
  const _NameField({
    required this.theme,
    required this.initial,
    required this.onChanged,
    required this.onCommit,
  });

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final TextEditingController _c;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.initial);
    _focus = FocusNode();
    // Commit the current text when the field loses focus.
    _focus.addListener(() {
      if (!_focus.hasFocus) widget.onCommit(_c.text);
    });
  }

  @override
  void didUpdateWidget(covariant _NameField old) {
    super.didUpdateWidget(old);
    if (old.initial != widget.initial && _c.text != widget.initial) {
      _c.text = widget.initial;
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.black.withValues(alpha: 0.3),
        border:
            Border.all(color: widget.theme.accent.withValues(alpha: 0.5)),
      ),
      child: TextField(
        controller: _c,
        focusNode: _focus,
        style: Balance.body(16, theme: widget.theme),
        maxLength: 14,
        decoration: InputDecoration(
          counterText: '',
          border: InputBorder.none,
          hintText: 'Your name',
          hintStyle: Balance.body(14,
              theme: widget.theme,
              color: widget.theme.ivory.withValues(alpha: 0.4)),
        ),
        onChanged: widget.onChanged,
        onSubmitted: widget.onCommit,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Tip jar (IAP).
class _SupportCard extends StatelessWidget {
  final BalanceThemeDef theme;
  final StoreService store;
  const _SupportCard({required this.theme, required this.store});

  @override
  Widget build(BuildContext context) {
    final screen = context.findAncestorStateOfType<_MenuScreenState>()!;
    final audio = screen.widget.audio;
    return WoodCard(
      theme: theme,
      title: 'Support Wajiha',
      child: Column(
        children: [
          Text(
            'Balance It is 100% free. If it made you smile, a small tip keeps the workshop open!',
            style: Balance.body(14, theme: theme),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Builder(builder: (_) {
            final tips = [
              store.coffeeProduct,
              store.chocolateProduct,
            ].whereType<ProductDetails>().toList();
            if (!store.storeReady) {
              return Text(
                store.error ?? 'Loading…',
                style: Balance.body(13,
                    theme: theme,
                    color: theme.ivory.withValues(alpha: 0.6)),
                textAlign: TextAlign.center,
              );
            }
            if (tips.isEmpty) {
              return Text('Tips coming soon.',
                  style: Balance.body(13,
                      theme: theme,
                      color: theme.ivory.withValues(alpha: 0.6)));
            }
            return Wrap(
              spacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final p in tips)
                  _TipChip(
                    theme: theme,
                    label: p.id == StoreService.chocolateId
                        ? '🍫 ${p.price}'
                        : '☕ ${p.price}',
                    onTap: () {
                      audio.click();
                      store.buyTip(p);
                    },
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _TipChip extends StatelessWidget {
  final BalanceThemeDef theme;
  final String label;
  final VoidCallback onTap;
  const _TipChip(
      {required this.theme, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.black.withValues(alpha: 0.3),
          border: Border.all(
              color: theme.accent.withValues(alpha: 0.6), width: 1.5),
        ),
        child: Text(label, style: Balance.label(14, theme: theme)),
      ),
    );
  }
}
