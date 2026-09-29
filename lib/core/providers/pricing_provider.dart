import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happyn/core/payments/pricing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// La commission HAPPYN, lue EN BASE plutôt que recopiée dans l'app.
///
/// C'est `public.platform_fee_bps()` qui décide, et c'est elle qui sera
/// appliquée au versement. Recopier le taux ici en ferait une seconde
/// définition : le jour où il change, l'app annoncerait un montant que le
/// virement ne tiendrait pas.
///
/// En cas d'échec réseau on retombe sur la valeur connue. Un écart d'affichage
/// vaut mieux qu'un écran de création de tarif qui refuse de s'ouvrir — et le
/// montant réel, lui, reste celui de la base.
final platformFeeBpsProvider = FutureProvider<int>((ref) async {
  try {
    final value = await Supabase.instance.client.rpc('platform_fee_bps');
    if (value is int) return value;
    if (value is num) return value.toInt();
  } catch (_) {
    // Hors ligne, ou migration Connect pas encore appliquée.
  }
  return Pricing.defaultPlatformFeeBps;
});
