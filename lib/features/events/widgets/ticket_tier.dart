import 'package:flutter/material.dart';

/// Un tarif de billet en cours d'édition dans le formulaire d'événement
/// (nom, prix, quantité, maximum par personne).
///
/// Porte ses propres `TextEditingController` : l'écran appelant est
/// responsable d'appeler [dispose].
class TicketTier {
  /// id du `ticket_type` existant (null = nouveau tarif à créer).
  final String? id;

  /// Nombre déjà vendu (garde-fou : on ne descend pas la quantité en dessous).
  final int quantitySold;

  final TextEditingController nameController;
  /// Le prix que l'ACHETEUR paie. C'est lui qui part en base.
  final TextEditingController priceController;

  /// Ce que l'organisateur veut TOUCHER. N'existe que dans l'interface : la
  /// base ne connaît que le prix affiché, et recalcule le net au versement.
  /// Les deux champs se suivent l'un l'autre (voir TicketTierCard).
  final TextEditingController netController;
  final TextEditingController quantityController;
  final TextEditingController maxPerOrderController;

  TicketTier({
    String name = '',
    this.id,
    this.quantitySold = 0,
    String price = '',
    String quantity = '100',
    String maxPerOrder = '10',
  })  : nameController = TextEditingController(text: name),
        priceController = TextEditingController(text: price),
        netController = TextEditingController(),
        quantityController = TextEditingController(text: quantity),
        maxPerOrderController = TextEditingController(text: maxPerOrder);

  void dispose() {
    nameController.dispose();
    priceController.dispose();
    netController.dispose();
    quantityController.dispose();
    maxPerOrderController.dispose();
  }
}
