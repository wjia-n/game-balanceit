import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const BalanceItApp());

class BalanceItApp extends StatelessWidget {
  const BalanceItApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      variant: ShellVariant.retroCabinet,
      title: 'Balance It',
      tagline: 'One beam. One ball. Zero chill.',
      emoji: '⚖️',
      slug: 'balanceit',
      howToPlay:
          '• Drag anywhere to tilt the beam under the ball.\n• Keep the ball from rolling off either end.\n• Watch out for surprise gusts of wind! 💨\n• Survive 60 seconds to win.',
      playerOptions: const [1],
      supportsBots: false,
      gameBuilder: (ctx, players, cb) => BalanceItScreen(players: players, callbacks: cb),
    );
  }
}
