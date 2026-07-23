import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:happyn/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'event_detail_screen.dart';

/// Écran « J'ai un code d'invitation » : on tape/colle le code d'un event privé
/// pour l'ouvrir (il n'apparaît nulle part dans la découverte).
class JoinPrivateEventScreen extends StatefulWidget {
  const JoinPrivateEventScreen({super.key});

  @override
  State<JoinPrivateEventScreen> createState() => _JoinPrivateEventScreenState();
}

class _JoinPrivateEventScreenState extends State<JoinPrivateEventScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  static const _page = Color(0xFF08080F);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() => _error = AppLocalizations.of(context).errEnterInviteCode);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await Supabase.instance.client
          .rpc('unlock_private_event', params: {'p_code': code});
      final list = List<Map<String, dynamic>>.from(data as List);
      if (list.isEmpty) {
        setState(() {
          _loading = false;
          _error = AppLocalizations.of(context).errNoPrivateEvent;
        });
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => EventDetailScreen(event: list.first),
        ),
      );
    } catch (e) {
      setState(() {
        _loading = false;
        _error = AppLocalizations.of(context).errSomethingWrongRetry;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _page,
      appBar: AppBar(
        backgroundColor: _page,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          AppLocalizations.of(context).joinPrivateEvent,
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 34),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.lock_open,
                    color: Color(0xFFC4B5FD), size: 26),
              ),
              const SizedBox(height: 18),
              Text(
                AppLocalizations.of(context).gotInviteCode,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                AppLocalizations.of(context).joinPrivateBody,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.55),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 26),
              TextField(
                controller: _controller,
                enabled: !_loading,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                inputFormatters: [UpperCaseFormatter()],
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                ),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context).inviteCodePlaceholder,
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.22),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  errorText: _error,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF7C3AED)),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    disabledBackgroundColor:
                        const Color(0xFF7C3AED).withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Colors.white),
                        )
                      : Text(
                          AppLocalizations.of(context).openEvent,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Force la saisie en majuscules (les codes sont insensibles à la casse côté
/// serveur, mais l'affichage majuscule est plus lisible).
class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
