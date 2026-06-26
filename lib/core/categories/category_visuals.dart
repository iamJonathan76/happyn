import 'package:flutter/material.dart';

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
  'Music': Color(0xFFEC4899),
  'Concerts': Color(0xFFEC4899),
  'Concert': Color(0xFFEC4899),
  'Party': Color(0xFFF472B6),
  'Parties': Color(0xFFF472B6),
  'Festival': Color(0xFFF97316),
  'Festivals': Color(0xFFF97316),
  'Networking': Color(0xFF10B981),
  'Art': Color(0xFFA78BFA),
  'Sports': Color(0xFFF97316),
  'Food & Drink': Color(0xFFFBBF24),
  'Food': Color(0xFFFBBF24),
  'Faith': Color(0xFF34D399),
  'Church': Color(0xFF34D399),
  'Birthdays': Color(0xFFF472B6),
  'Birthday': Color(0xFFF472B6),
  'Student Life': Color(0xFF60A5FA),
  'Tech': Color(0xFF60A5FA),
  'Technology': Color(0xFF60A5FA),
  'Gaming': Color(0xFF818CF8),
  'Comedy': Color(0xFFFB923C),
  'Business': Color(0xFF818CF8),
  'Community': Color(0xFF34D399),
  'Arts': Color(0xFFA78BFA),
  'Other': Color(0xFF9CA3AF),
};

IconData categoryIcon(String name) =>
    kCategoryIcons[name] ?? Icons.local_activity_outlined;

Color categoryColor(String name) =>
    kCategoryColors[name] ?? const Color(0xFFA78BFA);
