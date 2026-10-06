import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/utils/support.dart';
import 'package:happyn/core/widgets/app_form.dart';
import 'package:happyn/l10n/app_localizations.dart';

/// Écran de suppression de compte (droit à l'effacement).
///
/// Montre d'abord ce qui va concrètement se passer — billets annulés,
/// événements annulés ou supprimés — avant de demander une confirmation forte
/// (retaper son adresse e-mail). L'action est irréversible.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _supabase = Supabase.instance.client;
  final _emailController = TextEditingController();

  Map<String, dynamic>? _preview;
  bool _loading = true;
  bool _deleting = false;
  String? _error;

  String get _email => _supabase.auth.currentUser?.email ?? '';

  int _n(String key) => (_preview?[key] as num?)?.toInt() ?? 0;

  /// Le premier refus qui s'applique, dans l'ordre du serveur — ou null.
  ///
  /// Les clés sont les mêmes que les codes d'erreur renvoyés par
  /// `delete-account` : l'aperçu et la suppression appellent les mêmes gardes
  /// en base, donc ce qu'annonce l'écran est ce que le serveur appliquera.
  String? get _blockingCode {
    if (_n('blocked_paid_sales') > 0) return 'has_paid_sales';
    if (_n('blocked_pending_earnings') > 0) return 'has_pending_earnings';
    if (_n('blocked_paid_tickets') > 0) return 'has_paid_tickets';
    return null;
  }

  bool get _blocked => _blockingCode != null;

  /// Le message d'un refus, ou null si le code n'en est pas un.
  String? _blockedMessage(AppLocalizations l, String? code) => switch (code) {
        'has_paid_sales' => l.deleteAccountBlocked(kSupportEmail),
        'has_pending_earnings' => l.deleteAccountBlockedEarnings(kSupportEmail),
        'has_paid_tickets' => l.deleteAccountBlockedTickets(kSupportEmail),
        _ => null,
      };

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadPreview() async {
    try {
      final data = await _supabase.rpc('account_deletion_preview');
      if (!mounted) return;
      setState(() {
        _preview = Map<String, dynamic>.from(data as Map);
        _loading = false;
      });
    } catch (e) {
      // Ne pas masquer : si la RPC manque (migration non appliquée), l'écran
      // afficherait « rien en cours » alors qu'il n'a rien pu lire.
      debugPrint('DELETE_ACCOUNT preview failed: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error =
              '${AppLocalizations.of(context).deletionFailed(kSupportEmail)}\n$e';
        });
      }
    }
  }

  Future<void> _confirmAndDelete() async {
    final l = AppLocalizations.of(context);
    if (_emailController.text.trim().toLowerCase() != _email.toLowerCase()) {
      setState(() => _error = l.deleteAccountEmailMismatch);
      return;
    }
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      final res = await _supabase.functions.invoke('delete-account');
      final body = (res.data as Map?)?.cast<String, dynamic>() ?? {};

      if (body['status'] != 'deleted') {
        // On remonte le code d'erreur renvoyé par la fonction plutôt que de
        // le perdre dans une exception générique.
        final code = body['error'] as String?;
        final detail = body['detail'] as String?;
        debugPrint('DELETE_ACCOUNT failed: $code / $detail');
        if (!mounted) return;
        setState(() {
          _deleting = false;
          _error = _blockedMessage(l, code) ??
              '${l.deletionFailed(kSupportEmail)}\n[$code] ${detail ?? ''}';
        });
        return;
      }

      await _supabase.auth.signOut();
      if (!mounted) return;
      showAppSnack(context, l.accountDeleted);
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    } on FunctionException catch (e) {
      // Un refus (409) n'arrive pas dans `res.data` : le client lève une
      // exception pour tout statut d'erreur. Sans ce cas, l'écran n'affichait
      // jamais le motif du refus, seulement « la suppression a échoué ».
      final details = e.details;
      final code = details is Map ? details['error'] as String? : null;
      debugPrint('DELETE_ACCOUNT refused: ${e.status} $details');
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = _blockedMessage(l, code) ??
            '${l.deletionFailed(kSupportEmail)}\n[${code ?? e.status}]';
      });
    } catch (e) {
      debugPrint('DELETE_ACCOUNT exception: $e');
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = '${l.deletionFailed(kSupportEmail)}\n$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

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
        title: Text(l.deleteAccount, style: AppText.h2),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                // Avertissement principal
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: AppColors.error.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppColors.error, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(l.deleteAccountWarning,
                            style: AppText.bodySm),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                Text(l.deleteAccountWhatHappens, style: AppText.h4),
                const SizedBox(height: 10),

                if (_blocked)
                  _bullet(_blockedMessage(l, _blockingCode)!,
                      color: AppColors.error)
                else ...[
                  if (_n('upcoming_tickets') > 0)
                    _bullet(l.deleteAccountTicketsCancelled(
                        _n('upcoming_tickets'))),
                  if (_n('events_to_cancel') > 0)
                    _bullet(l.deleteAccountEventsCancelled(
                        _n('events_to_cancel'))),
                  if (_n('events_to_delete') > 0)
                    _bullet(l.deleteAccountEventsDeleted(
                        _n('events_to_delete'))),
                  if (_n('upcoming_tickets') == 0 &&
                      _n('events_to_cancel') == 0 &&
                      _n('events_to_delete') == 0)
                    _bullet(l.deleteAccountNothingPending),
                ],

                const SizedBox(height: 14),
                Text(l.deleteAccountRetention,
                    style: AppText.small.copyWith(height: 1.5)),

                if (!_blocked) ...[
                  const SizedBox(height: 26),
                  AppLabel(l.deleteAccountConfirmEmail),
                  TextField(
                    controller: _emailController,
                    enabled: !_deleting,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: appInputDecoration(_email,
                            icon: Icons.alternate_email)
                        .copyWith(errorText: _error),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _deleting ? null : _confirmAndDelete,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        disabledBackgroundColor:
                            AppColors.error.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _deleting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.4, color: Colors.white),
                            )
                          : Text(l.deleteMyAccount,
                              style:
                                  AppText.h4.copyWith(color: Colors.white)),
                    ),
                  ),
                ] else if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!,
                      style: AppText.bodySm.copyWith(color: AppColors.error)),
                ],
              ],
            ),
    );
  }

  Widget _bullet(String text, {Color? color}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 7, right: 10),
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: color ?? AppColors.lavender,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Expanded(
              child: Text(text,
                  style: AppText.bodySm.copyWith(color: color, height: 1.5)),
            ),
          ],
        ),
      );
}
