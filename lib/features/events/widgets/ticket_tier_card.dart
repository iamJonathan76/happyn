import 'package:flutter/material.dart';
import 'package:happyn/core/payments/pricing.dart';
import 'package:happyn/core/theme/app_colors.dart';
import 'package:happyn/core/theme/app_text.dart';
import 'package:happyn/core/widgets/app_form.dart';
import 'package:happyn/l10n/app_localizations.dart';
import 'ticket_tier.dart';

/// Carte d'édition d'un tarif de billet.
///
/// Deux champs de prix, et c'est volontaire : « ce que je touche » et « ce que
/// l'acheteur paie ». L'écart entre les deux fait environ 10 % — frais Stripe
/// et commission — et le découvrir APRÈS la vente est la seule mauvaise
/// surprise qui compte vraiment.
///
/// Ils se suivent l'un l'autre : saisir l'un recalcule l'autre. L'organisateur
/// peut donc partir de ce qu'il veut gagner, puis arrondir le prix affiché
/// pour éviter un « 22,05 $ » disgracieux — et il voit aussitôt ce que
/// l'arrondi lui rapporte.
///
/// Seul le prix AFFICHÉ part en base. Le net est une estimation d'interface :
/// les frais réels dépendent de la carte utilisée.
class TicketTierCard extends StatefulWidget {
  final TicketTier tier;

  /// La commission, telle que la base la déclare (`platform_fee_bps()`).
  final int platformFeeBps;

  /// Un tarif déjà enregistré en base n'est pas supprimable (des billets ont
  /// pu être vendus) — et on garde toujours au moins un tarif.
  final bool canRemove;
  final VoidCallback onRemove;

  const TicketTierCard({
    super.key,
    required this.tier,
    required this.platformFeeBps,
    required this.canRemove,
    required this.onRemove,
  });

  @override
  State<TicketTierCard> createState() => _TicketTierCardState();
}

class _TicketTierCardState extends State<TicketTierCard> {
  /// Empêche la boucle : chaque champ écrit dans l'autre, qui préviendrait à
  /// son tour. On ne recalcule que la saisie humaine.
  bool _syncing = false;

  static const _pad = EdgeInsets.symmetric(horizontal: 16, vertical: 16);

  TicketTier get _tier => widget.tier;

  @override
  void initState() {
    super.initState();
    // Un tarif existant arrive avec son prix affiché : on en déduit le net
    // pour que les deux champs soient cohérents dès l'ouverture.
    _writeNetFromDisplay();
    _tier.priceController.addListener(_onDisplayChanged);
    _tier.netController.addListener(_onNetChanged);
  }

  @override
  void dispose() {
    _tier.priceController.removeListener(_onDisplayChanged);
    _tier.netController.removeListener(_onNetChanged);
    super.dispose();
  }

  double? _parse(String raw) {
    final cleaned = raw.trim().replaceAll(',', '.').replaceAll(' ', '');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  /// Écrit sans virgule superflue : « 20 » plutôt que « 20.00 », mais
  /// « 22.05 » quand les cents comptent.
  String _format(double v) {
    final rounded = (v * 100).round() / 100;
    return rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toStringAsFixed(2);
  }

  void _set(TextEditingController c, String text) {
    if (c.text == text) return;
    c.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _onNetChanged() {
    if (_syncing) return;
    _syncing = true;
    final net = _parse(_tier.netController.text);
    if (net == null) {
      _set(_tier.priceController, '');
    } else {
      final display =
          Pricing.displayFromNet(net, platformFeeBps: widget.platformFeeBps);
      _set(_tier.priceController, display <= 0 ? '' : _format(display));
    }
    _syncing = false;
    setState(() {});
  }

  void _onDisplayChanged() {
    if (_syncing) return;
    _syncing = true;
    _writeNetFromDisplay();
    _syncing = false;
    setState(() {});
  }

  void _writeNetFromDisplay() {
    final display = _parse(_tier.priceController.text);
    if (display == null || display <= 0) {
      _set(_tier.netController, '');
      return;
    }
    final net =
        Pricing.netFromDisplay(display, platformFeeBps: widget.platformFeeBps);
    _set(_tier.netController, net <= 0 ? '' : _format(net));
  }

  void _roundTo(double step) {
    final display = _parse(_tier.priceController.text);
    if (display == null || display <= 0) return;
    _syncing = true;
    _set(_tier.priceController, _format(Pricing.roundUpTo(display, step)));
    _writeNetFromDisplay();
    _syncing = false;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final display = _parse(_tier.priceController.text) ?? 0;
    final paid = display > 0;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tier.nameController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: appInputDecoration(l.tierNameHint,
                      icon: Icons.local_activity_outlined,
                      contentPadding: _pad),
                ),
              ),
              if (widget.canRemove) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: widget.onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.close,
                        color: AppColors.error, size: 18),
                  ),
                ),
              ],
            ],
          ),
          if (_tier.quantitySold > 0) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l.tierSoldInfo(_tier.quantitySold),
                style: AppText.micro.copyWith(color: AppColors.lavender),
              ),
            ),
          ],

          // ── Les deux prix ────────────────────────────────────────────────
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _priceField(l.youReceiveLabel, _tier.netController,
                  l.priceFreeHint, Icons.savings_outlined)),
              const SizedBox(width: 10),
              Expanded(child: _priceField(l.buyerPaysLabel,
                  _tier.priceController, l.priceFreeHint, Icons.sell_outlined)),
            ],
          ),

          if (paid) ...[
            const SizedBox(height: 10),
            _breakdown(l, lang, display),
          ],

          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tier.quantityController,
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
                  controller: _tier.maxPerOrderController,
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

  Widget _priceField(String label, TextEditingController controller,
      String hint, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.micro.copyWith(
                letterSpacing: 0.6,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted)),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: appInputDecoration(hint,
              icon: icon, contentPadding: _pad),
        ),
      ],
    );
  }

  /// Où part l'argent, et de quoi arrondir. Un organisateur qui voit
  /// « 22,05 $ » veut presque toujours « 22,50 $ » — et il doit voir du même
  /// coup ce que l'arrondi lui rapporte.
  Widget _breakdown(AppLocalizations l, String lang, double display) {
    final stripe = Pricing.stripeFee(display);
    final platform =
        Pricing.platformFee(display, platformFeeBps: widget.platformFeeBps);
    final net =
        Pricing.netFromDisplay(display, platformFeeBps: widget.platformFeeBps);
    final tooLow = net <= 0;
    String money(double v) => Pricing.money(v, lang);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: tooLow
                ? AppColors.error.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tooLow)
            Text(
              l.priceTooLow(money(
                  Pricing.minimumViableDisplay(
                      platformFeeBps: widget.platformFeeBps))),
              style: AppText.micro.copyWith(color: AppColors.error, height: 1.4),
            )
          else ...[
            Text(
              l.feeBreakdown(money(stripe), money(platform)),
              style: AppText.micro.copyWith(height: 1.4),
            ),
            const SizedBox(height: 3),
            // « environ » n'est pas une précaution de style : une carte
            // étrangère coûte plus cher à Stripe, et le montant exact
            // n'existe qu'après la vente.
            Text(
              l.youReceiveApprox(money(net)),
              style: AppText.microBold.copyWith(color: AppColors.success),
            ),
          ],
          const SizedBox(height: 8),
          // `Wrap` et non `Row` : quatre pastilles plus leur libelle ne
          // tiennent pas sur une ligne etroite — mesure sur un Galaxy S8, ou
          // la rangee debordait de 8 pixels. Elles passent a la ligne.
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(l.roundUpTo, style: AppText.micro),
              ...Pricing.roundingSteps.map((step) => GestureDetector(
                    onTap: () => _roundTo(step),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(money(step),
                          style: AppText.microBold
                              .copyWith(color: AppColors.lavenderLight)),
                    ),
                  )),
            ],
          ),
        ],
      ),
    );
  }
}
