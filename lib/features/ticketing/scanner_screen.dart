import 'package:flutter/material.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Écran scanner réservé à l'organisateur d'un événement.
/// Scanne un QR (payload signé par `mint-qr`), appelle l'Edge Function
/// `validate-ticket`, et affiche le résultat. En mode debug, un bouton permet
/// de coller un payload à la main (test sans caméra / un seul appareil).
class ScannerScreen extends StatefulWidget {
  final Map<String, dynamic> event;
  const ScannerScreen({super.key, required this.event});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

enum _ResultKind { none, admitted, alreadyUsed, expired, invalid, notAuthorized }

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _processing = false;
  _ResultKind _result = _ResultKind.none;
  String _resultDetail = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    // On ignore toute détection tant qu'on traite un scan OU qu'un résultat est
    // affiché → le résultat reste à l'écran jusqu'à « Scan next » (pas de
    // rescan en boucle du même billet).
    if (_processing || _result != _ResultKind.none) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;
    await _validate(code);
  }

  Future<void> _validate(String payload) async {
    setState(() {
      _processing = true;
      _result = _ResultKind.none;
    });

    final l = AppLocalizations.of(context);
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'validate-ticket',
        body: {'qr_payload': payload},
      );
      final data = (res.data as Map?)?.cast<String, dynamic>() ?? {};
      final status = data['status'] as String? ?? 'invalid';

      _ResultKind kind;
      String detail;
      switch (status) {
        case 'admitted':
          kind = _ResultKind.admitted;
          detail = (data['event_title'] as String?) ?? l.welcomeIn;
          break;
        case 'already_used':
          kind = _ResultKind.alreadyUsed;
          detail = l.scanAlreadyScanned;
          break;
        case 'expired':
          kind = _ResultKind.expired;
          detail = l.scanExpired;
          break;
        case 'not_authorized':
          kind = _ResultKind.notAuthorized;
          detail = l.scanNotOrganizer;
          break;
        default:
          kind = _ResultKind.invalid;
          detail = l.scanInvalid;
      }

      if (!mounted) return;
      setState(() {
        _result = kind;
        _resultDetail = detail;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _result = _ResultKind.invalid;
        _resultDetail = l.scanNetworkError;
      });
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _reset() {
    setState(() {
      _result = _ResultKind.none;
      _resultDetail = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Caméra
          MobileScanner(controller: _controller, onDetect: _onDetect),

          // Overlay sombre + cadre de visée
          Container(color: Colors.black.withOpacity(0.35)),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.primary, width: 3),
              ),
            ),
          ),

          // Header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 16),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      '${l.scanTicketsTitle} · ${widget.event['title'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Spinner pendant validation
          if (_processing)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),

          // Carte de résultat
          if (_result != _ResultKind.none) _resultOverlay(),
        ],
      ),
    );
  }

  Widget _resultOverlay() {
    final l = AppLocalizations.of(context);
    final (color, icon, title) = switch (_result) {
      _ResultKind.admitted => (AppColors.success, Icons.check_circle, l.scanResultAdmitted),
      _ResultKind.alreadyUsed => (AppColors.warning, Icons.error, l.scanResultAlreadyUsed),
      _ResultKind.expired => (AppColors.warning, Icons.timer_off, l.scanResultExpired),
      _ResultKind.notAuthorized => (AppColors.error, Icons.block, l.scanResultNotAuthorized),
      _ => (AppColors.error, Icons.cancel, l.scanResultInvalid),
    };

    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 96),
              const SizedBox(height: 20),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _resultDetail,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textMed,
                ),
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: _reset,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.pink],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    l.scanNext,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
