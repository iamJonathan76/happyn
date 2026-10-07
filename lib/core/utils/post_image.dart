/// Forme d'affichage d'une image de publication.
///
/// La forme réelle (largeur / hauteur), bornée comme sur Instagram : pas plus
/// haute que 4:5, pas plus large que 1.91:1. Au-delà, une photo très haute
/// mangerait tout l'écran et une très large deviendrait une bande illisible ;
/// l'image est alors rognée au minimum pour tenir dans la borne.
///
/// Sans forme connue (publications d'avant la colonne `image_aspect`), 4:5 :
/// c'est ainsi qu'elles s'affichaient, elles ne changent pas d'aspect.
double displayAspect(double? aspect) {
  if (aspect == null || aspect <= 0) return 4 / 5;
  return aspect.clamp(4 / 5, 1.91);
}
