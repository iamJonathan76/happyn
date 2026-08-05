import 'package:flutter/material.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/widgets/app_form.dart';
import 'package:happyn/l10n/app_localizations.dart';
import 'ticket_tier.dart';

/// Carte d'édition d'un tarif de billet (nom, prix, quantité, max/personne).
/// Utilisée par le formulaire de création/édition d'événement.
class TicketTierCard extends StatelessWidget {
  final TicketTier tier;

  /// Un tarif déjà enregistré en base n'est pas supprimable (des billets ont
  /// pu être vendus) — et on garde toujours au moins un tarif.
  final bool canRemove;
  final VoidCallback onRemove;

  const TicketTierCard({
    super.key,
    required this.tier,
    required this.canRemove,
    required this.onRemove,
  });

  static const _pad =
      EdgeInsets.symmetric(horizontal: 16, vertical: 16);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.09)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: tier.nameController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: appInputDecoration(l.tierNameHint,
                      icon: Icons.local_activity_outlined,
                      contentPadding: _pad),
                ),
              ),
              if (canRemove) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.close,
                        color: AppColors.error, size: 18),
                  ),
                ),
              ],
            ],
          ),
          if (tier.quantitySold > 0) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l.tierSoldInfo(tier.quantitySold),
                style: AppText.micro.copyWith(color: AppColors.lavender),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: tier.priceController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: appInputDecoration(l.priceFreeHint,
                      icon: Icons.attach_money, contentPadding: _pad),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: tier.quantityController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: appInputDecoration(l.qtyHint,
                      icon: Icons.confirmation_number_outlined,
                      contentPadding: _pad),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: tier.maxPerOrderController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: appInputDecoration(l.maxPerPersonHint,
                      icon: Icons.person_outline, contentPadding: _pad),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
