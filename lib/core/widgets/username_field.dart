import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:happyn/core/providers/people_provider.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/widgets/app_form.dart';
import 'package:happyn/l10n/app_localizations.dart';

/// Champ d'identifiant, avec verification de disponibilite pendant la saisie.
///
/// Partage par l'onboarding et l'edition du profil : la regle et le ton du
/// message doivent etre les memes aux deux endroits.
///
/// Pre-rempli avec l'identifiant actuel, il s'affiche « disponible » : la base
/// considere qu'un nom appartient deja a son proprietaire.
class UsernameField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<UsernameStatus> onStatus;

  /// Statut impose de l'exterieur, typiquement apres un refus a
  /// l'enregistrement (quelqu'un a pris le nom entre-temps).
  final UsernameStatus? forcedStatus;

  const UsernameField({
    super.key,
    required this.controller,
    required this.onStatus,
    this.forcedStatus,
  });

  @override
  State<UsernameField> createState() => _UsernameFieldState();
}

class _UsernameFieldState extends State<UsernameField> {
  Timer? _debounce;
  UsernameStatus? _status;
  bool _checking = false;

  /// Numero de la derniere verification lancee. Une reponse lente pour
  /// « jona » ne doit pas ecraser celle de « jonathan » arrivee avant elle —
  /// meme piege que la recherche d'adresse.
  int _seq = 0;

  /// Le controleur previent aussi quand seul le curseur bouge. Sans ce
  /// souvenir, chaque deplacement du curseur relancerait une requete.
  String _lastText = '';

  @override
  void initState() {
    super.initState();
    _lastText = widget.controller.text;
    widget.controller.addListener(_onChanged);
    // Apres la premiere image, pas maintenant : la verification appelle
    // setState ici et chez le parent, ce que Flutter interdit pendant la
    // construction d'un widget.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _lastText.isNotEmpty) _check(_lastText);
    });
  }

  @override
  void didUpdateWidget(covariant UsernameField old) {
    super.didUpdateWidget(old);
    if (widget.forcedStatus != null &&
        widget.forcedStatus != old.forcedStatus) {
      setState(() => _status = widget.forcedStatus);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final text = widget.controller.text;
    if (text == _lastText) return;
    _lastText = text;
    _debounce?.cancel();
    final u = normalizeUsername(text);

    // Format manifestement faux : on le dit sans attendre ni appeler la base.
    if (u.isNotEmpty && !usernameLooksValid(u) && u.length >= 3) {
      _seq++;
      _set(UsernameStatus.invalid, checking: false);
      return;
    }
    if (u.length < 3) {
      _seq++;
      _set(null, checking: false);
      widget.onStatus(UsernameStatus.invalid);
      return;
    }
    setState(() => _checking = true);
    widget.onStatus(UsernameStatus.checking);
    _debounce = Timer(const Duration(milliseconds: 400), () => _check(text));
  }

  Future<void> _check(String text) async {
    final mine = ++_seq;
    setState(() => _checking = true);
    widget.onStatus(UsernameStatus.checking);
    final status = await checkUsername(text);
    if (!mounted || mine != _seq) return;
    _set(status, checking: false);
  }

  void _set(UsernameStatus? s, {required bool checking}) {
    setState(() {
      _status = s;
      _checking = checking;
    });
    if (s != null) widget.onStatus(s);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    final (String message, Color color) = switch (_status) {
      UsernameStatus.ok => (l.usernameAvailable, AppColors.success),
      UsernameStatus.taken => (l.usernameTaken, AppColors.error),
      UsernameStatus.reserved => (l.usernameReserved, AppColors.error),
      UsernameStatus.invalid => (l.usernameRules, AppColors.error),
      UsernameStatus.unknown => (l.usernameUnchecked, AppColors.textLow),
      UsernameStatus.checking || null => (l.usernameRules, AppColors.textLow),
    };

    final Widget? suffix = _checking
        ? const Padding(
            padding: EdgeInsets.all(14),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary),
            ),
          )
        : switch (_status) {
            UsernameStatus.ok =>
              const Icon(Icons.check_circle, color: AppColors.success, size: 18),
            UsernameStatus.taken ||
            UsernameStatus.reserved ||
            UsernameStatus.invalid =>
              const Icon(Icons.error_outline, color: AppColors.error, size: 18),
            _ => null,
          };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.none,
          maxLength: 21, // 20 + un eventuel « @ » tape par reflexe
          inputFormatters: [
            // On bloque a la frappe ce qui ne sera jamais accepte, plutot que
            // de laisser taper puis refuser.
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9._@]')),
          ],
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: appInputDecoration(l.usernameHint,
                  icon: Icons.alternate_email)
              .copyWith(suffixIcon: suffix, counterText: ''),
        ),
        const SizedBox(height: 6),
        Text(message, style: AppText.micro.copyWith(color: color)),
      ],
    );
  }
}
