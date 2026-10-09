import 'package:flutter/material.dart';

/// Theme + ball-style catalogs for Balance It.
///
/// Every theme stays inside the workshop material world (real wood, brass,
/// copper, leather, stone, felt) — the variety comes from different woods,
/// metal trims, felt backings and danger-zone finishes. No neon, no
/// cyberpunk, no AI-dashboard aesthetics.
class BalanceThemeDef {
  final String id;
  final String name;
  final Color woodDark;
  final Color woodMid;
  final Color woodDeep;
  final Color accent; // brass / copper / leather trim
  final Color accentLight;
  final Color accentDark;
  final Color ivory; // text
  final Color felt; // backdrop base
  final Color danger; // beam end zones

  const BalanceThemeDef({
    required this.id,
    required this.name,
    required this.woodDark,
    required this.woodMid,
    required this.woodDeep,
    required this.accent,
    required this.accentLight,
    required this.accentDark,
    required this.ivory,
    required this.felt,
    required this.danger,
  });
}

class BalanceThemes {
  /// First 4 are the FREE starter themes. The rest are PRO.
  static const List<String> freeThemeIds = [
    'classic',
    'walnut',
    'seaglass',
    'dunes',
  ];

  static const List<BalanceThemeDef> all = [
    BalanceThemeDef(
      id: 'classic',
      name: 'Classic Oak',
      woodDark: Color(0xFF7A4E2A),
      woodMid: Color(0xFFA9743F),
      woodDeep: Color(0xFF4E2F17),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFE8CE7A),
      accentDark: Color(0xFF8A6D1A),
      ivory: Color(0xFFF5EFE0),
      felt: Color(0xFF2E2318),
      danger: Color(0xFFE4572E),
    ),
    BalanceThemeDef(
      id: 'walnut',
      name: 'Walnut Study',
      woodDark: Color(0xFF4A2E18),
      woodMid: Color(0xFF6B4426),
      woodDeep: Color(0xFF2B1A0D),
      accent: Color(0xFFB87333),
      accentLight: Color(0xFFE0A266),
      accentDark: Color(0xFF7E4E20),
      ivory: Color(0xFFF3EAD8),
      felt: Color(0xFF241A12),
      danger: Color(0xFFD64545),
    ),
    BalanceThemeDef(
      id: 'seaglass',
      name: 'Sea Glass',
      woodDark: Color(0xFF6B5B43),
      woodMid: Color(0xFF9A8A6C),
      woodDeep: Color(0xFF463B2B),
      accent: Color(0xFF4E9B8F),
      accentLight: Color(0xFF8FD0C4),
      accentDark: Color(0xFF2F6B64),
      ivory: Color(0xFFF4F1E6),
      felt: Color(0xFF1E3230),
      danger: Color(0xFFE0703C),
    ),
    BalanceThemeDef(
      id: 'dunes',
      name: 'Sunrise Dunes',
      woodDark: Color(0xFF8A5A33),
      woodMid: Color(0xFFC08A4E),
      woodDeep: Color(0xFF5C3A1D),
      accent: Color(0xFFD97B29),
      accentLight: Color(0xFFF2B06E),
      accentDark: Color(0xFF96521A),
      ivory: Color(0xFFFFF4E4),
      felt: Color(0xFF3A2A1C),
      danger: Color(0xFFC0392B),
    ),
    BalanceThemeDef(
      id: 'cherry',
      name: 'Cherry Workshop',
      woodDark: Color(0xFF5E2318),
      woodMid: Color(0xFF8A3A24),
      woodDeep: Color(0xFF3A140D),
      accent: Color(0xFFD4AF37),
      accentLight: Color(0xFFF3DC8E),
      accentDark: Color(0xFF96702A),
      ivory: Color(0xFFF8F1E2),
      felt: Color(0xFF2E1B14),
      danger: Color(0xFFE4572E),
    ),
    BalanceThemeDef(
      id: 'slate',
      name: 'Midnight Slate',
      woodDark: Color(0xFF2E3340),
      woodMid: Color(0xFF4A5162),
      woodDeep: Color(0xFF1A1D26),
      accent: Color(0xFFC0C6D4),
      accentLight: Color(0xFFE8ECF5),
      accentDark: Color(0xFF7E8698),
      ivory: Color(0xFFF2EEE4),
      felt: Color(0xFF14161D),
      danger: Color(0xFFD64545),
    ),
    BalanceThemeDef(
      id: 'moss',
      name: 'Moss Garden',
      woodDark: Color(0xFF4E3B28),
      woodMid: Color(0xFF75603E),
      woodDeep: Color(0xFF2F2417),
      accent: Color(0xFF7BA05B),
      accentLight: Color(0xFFB5D39A),
      accentDark: Color(0xFF4E6E38),
      ivory: Color(0xFFF5F2E4),
      felt: Color(0xFF22301C),
      danger: Color(0xFFE0703C),
    ),
    BalanceThemeDef(
      id: 'river',
      name: 'River Stone',
      woodDark: Color(0xFF5C5A52),
      woodMid: Color(0xFF8A877C),
      woodDeep: Color(0xFF383730),
      accent: Color(0xFF7FA8A0),
      accentLight: Color(0xFFBBD8D2),
      accentDark: Color(0xFF4E736C),
      ivory: Color(0xFFF4F2EA),
      felt: Color(0xFF23282A),
      danger: Color(0xFFE4572E),
    ),
    BalanceThemeDef(
      id: 'ivoryebony',
      name: 'Ivory & Ebony',
      woodDark: Color(0xFF2A2118),
      woodMid: Color(0xFF4E4438),
      woodDeep: Color(0xFF120E09),
      accent: Color(0xFFE8DCC0),
      accentLight: Color(0xFFFFF6DE),
      accentDark: Color(0xFFA89A76),
      ivory: Color(0xFFF8F3E6),
      felt: Color(0xFF1C1712),
      danger: Color(0xFFD64545),
    ),
    BalanceThemeDef(
      id: 'barn',
      name: 'Rustic Barn',
      woodDark: Color(0xFF6E3B22),
      woodMid: Color(0xFF9A5A36),
      woodDeep: Color(0xFF452412),
      accent: Color(0xFF8C8C8C),
      accentLight: Color(0xFFC4C4C4),
      accentDark: Color(0xFF5C5C5C),
      ivory: Color(0xFFF5EFE0),
      felt: Color(0xFF2E1E14),
      danger: Color(0xFFE4572E),
    ),
    BalanceThemeDef(
      id: 'copper',
      name: 'Copper Foundry',
      woodDark: Color(0xFF3E2A1E),
      woodMid: Color(0xFF63422C),
      woodDeep: Color(0xFF241710),
      accent: Color(0xFFB87333),
      accentLight: Color(0xFFF0B27A),
      accentDark: Color(0xFF7E4E20),
      ivory: Color(0xFFF5EFE0),
      felt: Color(0xFF1F150E),
      danger: Color(0xFFE0703C),
    ),
    BalanceThemeDef(
      id: 'arctic',
      name: 'Arctic Pine',
      woodDark: Color(0xFF6B5B43),
      woodMid: Color(0xFFA08B62),
      woodDeep: Color(0xFF453B2B),
      accent: Color(0xFF9FB8C8),
      accentLight: Color(0xFFD6E6F0),
      accentDark: Color(0xFF647E90),
      ivory: Color(0xFFF6F4EC),
      felt: Color(0xFF1E2A32),
      danger: Color(0xFFD64545),
    ),
  ];

  static BalanceThemeDef byId(String id, {BalanceThemeDef? custom}) {
    if (id == 'custom' && custom != null) return custom;
    for (final t in all) {
      if (t.id == id) return t;
    }
    return all.first;
  }

  static bool isProTheme(String id) => !freeThemeIds.contains(id);
}

// ---------------------------------------------------------------------------
/// Ball styles: physical ball materials. First 3 free, rest PRO.
class BallStyle {
  final String name;
  final Color base;
  final Color hi;
  const BallStyle(this.name, this.base, this.hi);
}

class BallStyles {
  static const freeCount = 3;
  static const List<BallStyle> styles = [
    BallStyle('Wooden', Color(0xFFB07B45), Color(0xFFE8C48A)),
    BallStyle('Marble', Color(0xFFE8E4D8), Color(0xFFFFFFFF)),
    BallStyle('Brass', Color(0xFFC9A227), Color(0xFFF3DC8E)),
    BallStyle('Ivory', Color(0xFFF2E8D0), Color(0xFFFFFBEE)),
    BallStyle('Obsidian', Color(0xFF2E2A26), Color(0xFF7A6E60)),
    BallStyle('Copper', Color(0xFFB87333), Color(0xFFF0B27A)),
    BallStyle('Emerald', Color(0xFF2E7D5B), Color(0xFF7FD0A8)),
    BallStyle('Slate', Color(0xFF4A5162), Color(0xFF9AA2B5)),
    BallStyle('Cherry', Color(0xFF8A2E1E), Color(0xFFD06A4E)),
  ];

  static List<String> get names => [for (final s in styles) s.name];
  static bool isPro(int index) => index >= freeCount;
}
