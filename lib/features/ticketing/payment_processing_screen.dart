import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'qr_ticket_screen.dart';

/// Après un paiement réussi, l'émission du ticket se fait côté serveur (webhook
/// Stripe), donc de façon asynchrone. Cet écran poll la table `tickets` jusqu'à
/// ce que le ticket lié au PaymentIntent apparaisse, puis ouvre le QR.
class PaymentProcessingScreen extends StatefulWidget {
  final String paymentIntentId;
  final Map<String, dynamic> event;
  final Map<String, dynamic> ticketType;

  const PaymentProcessingScreen({
    super.key,
    required this.paymentIntentId,
    required this.event,
    required this.ticketType,
  });

  @override
  State<PaymentProcessingScreen> createState() =>
      _PaymentProcessingScreenState();
}

class _PaymentProcessingScreenState extends State<PaymentProcessingScreen> {
  static const _maxAttempts = 20; // ~20s à 1s d'intervalle
  int _attempts = 0;
  bool _timedOut = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_timedOut) return;
    _attempts++;

    try {
      final rows = await Supabase.instance.client
          .from('tickets')
          .select()
          .eq('payment_intent_id', widget.paymentIntentId);

      final list = List<Map<String, dynamic>>.from(rows);
      if (list.isNotEmpty) {
        _timer?.cancel();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => QrTicketScreen(
              ticket: list.first,
              event: widget.event,
              ticketType: widget.ticketType,
              totalTickets: list.length,
            ),
          ),
        );
        return;
      }
    } catch (_) {
      // on réessaiera au prochain tick
    }

    if (_attempts >= _maxAttempts) {
      _timer?.cancel();
      if (mounted) setState(() => _timedOut = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08080F),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: _timedOut ? _timeoutView() : _loadingView(),
        ),
      ),
    );
  }

  Widget _loadingView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 56,
          height: 56,
          child: CircularProgressIndicator(color: Color(0xFF7C3AED)),
        ),
        const SizedBox(height: 28),
        Text(
          'Payment received ✓',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Issuing your ticket…',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Widget _timeoutView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.hourglass_bottom,
            color: Color(0xFFF97316), size: 64),
        const SizedBox(height: 20),
        Text(
          'Almost there',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your payment went through. Your ticket is taking a little longer '
          'than usual — it will appear in “My Tickets” shortly.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 28),
        GestureDetector(
          onTap: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Back to Home',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
