import 'package:flutter/material.dart';
import 'package:happyn/core/theme/app_colors.dart';

/// Icône Material + couleur d'accent par catégorie (fallback si nom inconnu).
/// Source partagée par Home, Discover, etc.

const Map<String, IconData> kCategoryIcons = {
  'Music': Icons.music_note,
  'Concerts': Icons.music_note,
  'Concert': Icons.music_note,
  'Party': Icons.local_bar,
  'Parties': Icons.local_bar,
  'Festival': Icons.festival,
  'Festivals': Icons.festival,
  'Networking': Icons.groups,
  'Art': Icons.palette,
  'Sports': Icons.sports_basketball,
  'Food & Drink': Icons.restaurant,
  'Food': Icons.restaurant,
  'Faith': Icons.church,
  'Church': Icons.church,
  'Birthdays': Icons.cake,
  'Birthday': Icons.cake,
  'Student Life': Icons.school,
  'Tech': Icons.memory,
  'Technology': Icons.memory,
  'Gaming': Icons.sports_esports,
  'Comedy': Icons.theater_comedy,
  'Business': Icons.business_center,
  'Community': Icons.diversity_3,
  'Arts': Icons.palette,
  'Other': Icons.more_horiz,
};

const Map<String, Color> kCategoryColors = {
  'Music': AppColors.pink,
  'Concerts': AppColors.pink,
  'Concert': AppColors.pink,
  'Party': AppColors.pinkLight,
  'Parties': AppColors.pinkLight,
  'Festival': AppColors.warning,
  'Festivals': AppColors.warning,
  'Networking': Color(0xFF10B981),
  'Art': AppColors.lavender,
  'Sports': AppColors.warning,
  'Food & Drink': AppColors.amber,
  'Food': AppColors.amber,
  'Faith': AppColors.green,
  'Church': AppColors.green,
  'Birthdays': AppColors.pinkLight,
  'Birthday': AppColors.pinkLight,
  'Student Life': AppColors.blue,
  'Tech': AppColors.blue,
  'Technology': AppColors.blue,
  'Gaming': Color(0xFF818CF8),
  'Comedy': Color(0xFFFB923C),
  'Business': Color(0xFF818CF8),
  'Community': AppColors.green,
  'Arts': AppColors.lavender,
  'Other': Color(0xFF9CA3AF),
};

IconData categoryIcon(String name) =>
    kCategoryIcons[name] ?? Icons.local_activity_outlined;

Color categoryColor(String name) =>
    kCategoryColors[name] ?? AppColors.lavender;
