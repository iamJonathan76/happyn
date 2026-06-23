import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
    if (_processing) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;
    await _validate(code);
  }

  Future<void> _validate(String payload) async {
    setState(() {
      _processing = true;
      _result = _ResultKind.none;
    });

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
          detail = (data['event_title'] as String?) ?? 'Welcome in!';
          break;
        case 'already_used':
          kind = _ResultKind.alreadyUsed;
          detail = 'This ticket has already been scanned.';
          break;
        case 'expired':
          kind = _ResultKind.expired;
          detail = 'The QR code expired. Ask the guest to refresh it.';
          break;
        case 'not_authorized':
          kind = _ResultKind.notAuthorized;
          detail = 'You are not the organizer of this event.';
          break;
        default:
          kind = _ResultKind.invalid;
          detail = 'This QR code is not a valid HAPPYN ticket.';
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
        _resultDetail = 'Network error. Try again.';
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

  Future<void> _pasteDebugPayload() async {
    final controller = TextEditingController();
    final payload = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF13111C),
        title: Text('Paste QR payload (debug)',
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 15)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
          decoration: const InputDecoration(
            hintText: 'ticket_id.exp.signature',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Validate'),
          ),
        ],
      ),
    );
    if (payload != null && payload.isNotEmpty) {
      await _validate(payload);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08080F),
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
                border: Border.all(color: const Color(0xFF7C3AED), width: 3),
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
                      'Scan tickets · ${widget.event['title'] ?? ''}',
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

          // Bouton debug « coller le payload »
          if (kDebugMode && _result == _ResultKind.none && !_processing)
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: GestureDetector(
                onTap: _pasteDebugPayload,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Center(
                    child: Text(
                      '🐛 Paste payload (debug)',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Spinner pendant validation
          if (_processing)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
              ),
            ),

          // Carte de résultat
          if (_result != _ResultKind.none) _resultOverlay(),
        ],
      ),
    );
  }

  Widget _resultOverlay() {
    final (color, icon, title) = switch (_result) {
      _ResultKind.admitted => (const Color(0xFF1DB954), Icons.check_circle, 'Admitted'),
      _ResultKind.alreadyUsed => (const Color(0xFFF97316), Icons.error, 'Already used'),
      _ResultKind.expired => (const Color(0xFFF97316), Icons.timer_off, 'Expired'),
      _ResultKind.notAuthorized => (const Color(0xFFFF4B4B), Icons.block, 'Not authorized'),
      _ => (const Color(0xFFFF4B4B), Icons.cancel, 'Invalid'),
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
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: _reset,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Scan next',
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
