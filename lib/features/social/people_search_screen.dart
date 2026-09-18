import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happyn/core/providers/people_provider.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/widgets/person_row.dart';
import 'package:happyn/l10n/app_localizations.dart';

/// Trouver quelqu'un, par son nom ou son @identifiant.
///
/// Sans cet ecran, le social n'avait pas d'entree : on ne pouvait suivre que
/// les gens croises sous une publication, et le filtre « mes connexions » de
/// Decouvrir restait vide pour tout nouvel utilisateur.
class PeopleSearchScreen extends ConsumerStatefulWidget {
  const PeopleSearchScreen({super.key});

  @override
  ConsumerState<PeopleSearchScreen> createState() => _PeopleSearchScreenState();
}

class _PeopleSearchScreenState extends ConsumerState<PeopleSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// 300 ms : assez pour ne pas interroger la base a chaque lettre, assez
  /// court pour que les resultats suivent la frappe.
  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextField(
            controller: _controller,
            autofocus: true,
            autocorrect: false,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: l.peopleSearchHint,
              hintStyle: AppText.body.copyWith(color: AppColors.textFaint),
              prefixIcon:
                  Icon(Icons.search, color: AppColors.textLow, size: 20),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(Icons.close,
                          color: AppColors.textLow, size: 18),
                      onPressed: () {
                        _controller.clear();
                        _debounce?.cancel();
                        setState(() => _query = '');
                      },
                    ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ),
      body: _body(l),
    );
  }

  Widget _body(AppLocalizations l) {
    if (normalizeUsername(_query).length < 2) {
      return _message(Icons.person_search_outlined, l.peopleSearchIntro);
    }
    return ref.watch(searchPeopleProvider(_query)).when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (_, _) =>
              _message(Icons.cloud_off_outlined, l.peopleSearchFailed),
          data: (people) => people.isEmpty
              ? _message(Icons.sentiment_neutral_outlined, l.peopleNoMatch)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: people.length,
                  itemBuilder: (_, i) => PersonRow(person: people[i]),
                ),
        );
  }

  Widget _message(IconData icon, String text) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44, color: AppColors.textFaint),
              const SizedBox(height: 12),
              Text(text,
                  textAlign: TextAlign.center,
                  style: AppText.bodySm.copyWith(color: AppColors.textLow)),
            ],
          ),
        ),
      );
}
