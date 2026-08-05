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
  final TextEditingController priceController;
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
        quantityController = TextEditingController(text: quantity),
        maxPerOrderController = TextEditingController(text: maxPerOrder);

  void dispose() {
    nameController.dispose();
    priceController.dispose();
    quantityController.dispose();
    maxPerOrderController.dispose();
  }
}
