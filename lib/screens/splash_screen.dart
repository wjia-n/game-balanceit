import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/balance_art.dart';
import '../theme/balance_themes.dart';
import 'menu_screen.dart';

/// Launch splash (single flow): WAJIHA company moment first, then the game
/// splash — game logo + name, animated loading line, and credits.
class SplashScreen extends StatefulWidget {
  final BalanceAudio audio;
  final BalanceSettings settings;
  const SplashScreen({super.key, required this.audio, required this.settings});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loader;
  bool _companyDone = false;

  @override
  void initState() {
    super.initState();
    _loader = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _run();
  }

  Future<void> _run() async {
    // Pre-warm audio while the splash shows, then start menu music.
    widget.audio.prewarm();
    widget.audio.startMenuMusic();
    // Company moment: the official WAJIHA logo, copied unchanged.
    await Future.delayed(const Duration(milliseconds: 1300));
    if (!mounted) return;
    setState(() => _companyDone = true);
    // Game splash: logo + name + animated loading line.
    _loader.forward();
    await Future.delayed(const Duration(milliseconds: 1900));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MenuScreen(
          audio: widget.audio,
          settings: widget.settings,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = BalanceThemes.byId(
      widget.settings.themeId,
      custom: widget.settings.customTheme,
    );
    return Scaffold(
      backgroundColor: theme.felt,
      body: WorkshopBackdrop(
        theme: theme,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _companyDone
              ? _GameSplash(
                  key: const ValueKey('gamesplash'),
                  theme: theme,
                  loader: _loader)
              : _CompanyMoment(
                  key: const ValueKey('company'), theme: theme),
        ),
      ),
    );
  }
}

/// Company moment: the official WAJIHA winged-W logo, shown untouched.
class _CompanyMoment extends StatelessWidget {
  final BalanceThemeDef theme;
  const _CompanyMoment({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/wajiha_logo.png',
            width: 130,
            height: 130,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 18),
          Text('WAJIHA', style: Balance.display(30, theme: theme)),
        ],
      ),
    );
  }
}

/// Game splash: logo + name + animated loading line + credits.
class _GameSplash extends StatelessWidget {
  final BalanceThemeDef theme;
  final AnimationController loader;
  const _GameSplash({super.key, required this.theme, required this.loader});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
            Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: theme.accent, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    offset: const Offset(0, 10),
                    blurRadius: 24,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child:
                  Image.asset('assets/balanceit_logo.png', fit: BoxFit.cover),
            ),
            const SizedBox(height: 22),
            Text('Balance It', style: Balance.display(48, theme: theme)),
            const SizedBox(height: 6),
            Text(
              'THE WORKSHOP BALANCE EDITION',
              style: Balance.label(13, theme: theme),
            ),
            const SizedBox(height: 30),
            // Animated loading line.
            SizedBox(
              width: 220,
              child: AnimatedBuilder(
                animation: loader,
                builder: (_, _) => Column(
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: Colors.black.withValues(alpha: 0.45),
                        border: Border.all(
                            color: theme.accent.withValues(alpha: 0.5)),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: loader.value.clamp(0.02, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            gradient: LinearGradient(
                              colors: [
                                theme.accentLight,
                                theme.accent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      loader.value < 1
                          ? 'Waxing the beam…'
                          : 'Ready!',
                      style: Balance.body(13,
                          theme: theme,
                          color: theme.ivory.withValues(alpha: 0.75)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 44),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/wajiha_logo.png',
                  width: 30,
                  height: 30,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 10),
                Text(
                  'Credits: WAJIHA',
                  style: Balance.label(14, theme: theme),
                ),
              ],
            ),
          ],
        ),
      );
  }
}
