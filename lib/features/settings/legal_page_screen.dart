import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:happyn/core/legal/legal_content.dart';

/// Affiche un document légal (Terms, Privacy, etc.) à partir de son `docId`.
class LegalPageScreen extends StatelessWidget {
  final String docId;
  const LegalPageScreen({super.key, required this.docId});

  @override
  Widget build(BuildContext context) {
    final doc = kLegalDocs[docId];

    return Scaffold(
      backgroundColor: const Color(0xFF08080F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF08080F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          doc?.title ?? 'Legal',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
      body: doc == null
          ? Center(
              child: Text('Document not found',
                  style: GoogleFonts.inter(color: Colors.white54)),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                Text(
                  kLegalVersion,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.35),
                  ),
                ),
                const SizedBox(height: 20),
                for (final section in doc.sections) ...[
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
                        color: Colors.white.withOpacity(0.7),
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
                            padding: const EdgeInsets.only(top: 7, right: 10),
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: Color(0xFFA78BFA),
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
                                color: Colors.white.withOpacity(0.7),
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
