import 'package:flutter/material.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happyn/core/legal/legal_content.dart';
import 'package:happyn/core/providers/legal_provider.dart';
import 'package:happyn/l10n/app_localizations.dart';

/// Affiche un document légal (Terms, Privacy, …) à partir de son `docId` (slug).
/// Contenu lu depuis la table `legal_documents` (éditable sans update app).
/// Si le réseau échoue, on retombe sur la copie embarquée, générée depuis la
/// même table, pour que le légal reste toujours accessible.
class LegalPageScreen extends ConsumerWidget {
  final String docId;
  const LegalPageScreen({super.key, required this.docId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(legalDocsProvider);

    Map<String, dynamic>? find(List<Map<String, dynamic>>? docs) => docs
        ?.cast<Map<String, dynamic>?>()
        .firstWhere((d) => d?['slug'] == docId, orElse: () => null);

    // 1) La base si elle répond ; 2) sinon la copie embarquée. On ne lit la
    // copie que si la base a échoué : elle peut dater d'avant une mise à jour.
    final dbDoc = find(docsAsync.asData?.value);
    final doc = dbDoc ??
        (docsAsync.hasError
            ? find(ref.watch(legalFallbackProvider).asData?.value)
            : null);

    final lang = Localizations.localeOf(context).languageCode;
    final shown = doc == null ? null : localizedLegalDoc(doc, lang);

    final title = (shown?['title'] ?? 'Legal') as String;
    final versionLabel = (shown?['version'] ?? '') as String;
    final List<LegalSection>? sections = shown == null
        ? null
        : parseLegalMarkdown((shown['content'] ?? '') as String);

    final loading = sections == null &&
        (docsAsync.isLoading ||
            (docsAsync.hasError && ref.watch(legalFallbackProvider).isLoading));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          title,
          style: AppText.h2.copyWith(color: Colors.white),
        ),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : sections == null
              ? Center(
                  child: Text(AppLocalizations.of(context).documentNotFound,
                      style: AppText.body.copyWith(color: Colors.white54)),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  children: [
                    Text(
                      versionLabel,
                      style: AppText.small,
                    ),
                    const SizedBox(height: 20),
                    for (final section in sections) ...[
                      if (section.heading != null) ...[
                        Text(
                          section.heading!,
                          style: AppText.h3.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                      ],
                      for (final p in section.paragraphs) ...[
                        Text(
                          p,
                          style: AppText.body.copyWith(height: 1.6),
                        ),
                        const SizedBox(height: 10),
                      ],
                      for (final b in section.bullets) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 7, right: 10),
                                child: Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: AppColors.lavender,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  b,
                                  style: AppText.body.copyWith(height: 1.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
    );
  }
}
