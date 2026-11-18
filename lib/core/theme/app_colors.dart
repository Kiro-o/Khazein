import 'package:flutter/material.dart';

/// Design tokens and brand color palette for Khazeen (خزين).
/// Primary Brand Color: Emerald Wholesale Green (#128A56)
class AppColors {
  AppColors._();

  // Primary Brand - Emerald Wholesale Green
  static const Color primary = Color(0xFF128A56);
  static const Color primaryDark = Color(0xFF0C5C3A);
  static const Color primaryLight = Color(0xFF28A76B);
  static const Color primarySurface = Color(0xFFEAF8F1);
  static const Color primaryBorder = Color(0xFFC3EADB);
  static const Color primaryDisabled = Color(0xFFA5D6A7);

  /// Background of the logo artwork (assets/images/logo.png), so the logo
  /// blends into screens drawn in this color.
  static const Color logoGreen = Color(0xFF167F54);

  // Synonyms for explicit semantic naming
  static const Color emerald = Color(0xFF128A56);
  static const Color emeraldDark = Color(0xFF0C5C3A);
  static const Color emeraldLight = Color(0xFF1EA86B); // Light Mint
  static const Color lightMint = Color(0xFF1EA86B); // Light Mint
  static const Color emeraldSurface = Color(0xFFE8F6EF); // Soft Mint Fill
  static const Color softMint = Color(0xFFE8F6EF); // Soft Mint Fill
  static const Color emeraldBorder = Color(0xFFC3EADB);

  // Secondary / Accents - Warm Wholesale Amber / Gold
  static const Color accent = Color(0xFFFFA726);
  static const Color accentDark = Color(0xFFF57C00);
  static const Color accentLight = Color(0xFFFFF3E0);
  static const Color amber = Color(0xFFFFA726);

  // Neutral Background & Surfaces - Ultra-soft Ice Grey Canvas & Crisp White
  static const Color scaffoldBackground = Color(0xFFF6F8F9);
  static const Color ultraSoftCanvas = Color(0xFFF6F8F9);
  static const Color slateGray = Color(0xFFF5F7FA);
  static const Color surface = Colors.white;
  static const Color white = Colors.white;
  static const Color cardShadow = Color(0x08000000);

  // Floating iOS / Glassmorphism Style Tokens
  static const List<BoxShadow> floatingCardShadow = [
    BoxShadow(
      color: Color(0x08000000),
      blurRadius: 24,
      spreadRadius: 0,
      offset: Offset(0, 8),
    ),
  ];
  static final BorderRadius floatingCardRadius = BorderRadius.circular(22);
  static const Color cardSeparator = Color(0xFFF1F5F9);

  // Typography & Text
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textWhite = Colors.white;

  // Status & Feedback (Replaced all blue with emerald / green)
  static const Color success = Color(0xFF128A56);
  static const Color error = Color(0xFFDC2626);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF128A56); // All blue replaced with emerald green

  // Borders & Dividers
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderFocused = Color(0xFF128A56);
  static const Color divider = Color(0xFFECEFF1);
}
