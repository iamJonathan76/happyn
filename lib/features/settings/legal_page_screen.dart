import 'package:flutter/material.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:happyn/core/legal/legal_content.dart';
import 'package:happyn/core/providers/legal_provider.dart';

/// Affiche un document légal (Terms, Privacy, …) à partir de son `docId` (slug).
/// Contenu lu depuis la table `legal_documents` (éditable sans update app).
/// Si le réseau échoue, on retombe sur le contenu embarqué (kLegalDocs) pour
/// que le légal reste toujours accessible.
class LegalPageScreen extends ConsumerWidget {
  final String docId;
  const LegalPageScreen({super.key, required this.docId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(legalDocsProvider);

    String title = 'Legal';
    String versionLabel = kLegalVersion;
    List<LegalSection>? sections;

    // 1) Depuis la DB si dispo
    final dbDoc = docsAsync.asData?.value
        .cast<Map<String, dynamic>?>()
        .firstWhere((d) => d?['slug'] == docId, orElse: () => null);
    if (dbDoc != null) {
      title = (dbDoc['title'] ?? 'Legal') as String;
      versionLabel = (dbDoc['version'] ?? kLegalVersion) as String;
      sections = parseLegalMarkdown((dbDoc['content'] ?? '') as String);
    } else {
      // 2) Fallback embarqué (hors-ligne / DB indisponible)
      final fallback = kLegalDocs[docId];
      if (fallback != null) {
        title = fallback.title;
        sections = fallback.sections;
      }
    }

    final loading = docsAsync.isLoading && sections == null;

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
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : sections == null
              ? Center(
                  child: Text('Document not found',
                      style: GoogleFonts.inter(color: Colors.white54)),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  children: [
                    Text(
                      versionLabel,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textLow,
                      ),
                    ),
                    const SizedBox(height: 20),
                    for (final section in sections) ...[
                      if (section.heading != null) ...[
                        Text(
                          section.heading!,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      for (final p in section.paragraphs) ...[
                        Text(
                          p,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            height: 1.6,
                            color: AppColors.textMed,
                          ),
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
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    height: 1.5,
                                    color: AppColors.textMed,
                                  ),
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
