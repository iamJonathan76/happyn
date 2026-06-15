import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF0A0817);
  static const Color backgroundSecondary = Color(0xFF120F24);
  static const Color card = Color(0xFF1A1535);
  static const Color primary = Color(0xFF7B6EF6);
  static const Color pink = Color(0xFFE94FAD);
  static const Color orange = Color(0xFFFF8C42);
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF7B6EF6), Color(0xFFE94FAD)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0A8D4);
  static const Color textMuted = Color(0xFF6B6280);
  static const Color border = Color(0xFF2A2448);
  static const Color success = Color(0xFF1DB954);
  static const Color error = Color(0xFFFF4B4B);
}