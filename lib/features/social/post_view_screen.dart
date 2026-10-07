import 'package:flutter/material.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/features/social/widgets/post_card.dart';
import 'package:happyn/l10n/app_localizations.dart';

/// Une publication seule, ouverte depuis une carte partagée en message.
///
/// Les publications ne vivaient que dans des fils ; un partage a besoin d'une
/// destination qui montre CELLE-LÀ, pas un fil où la chercher.
class PostViewScreen extends StatelessWidget {
  final Map<String, dynamic> post;
  const PostViewScreen({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(AppLocalizations.of(context).post, style: AppText.h3),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [PostCard(post: post)],
      ),
    );
  }
}
