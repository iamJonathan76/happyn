import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    // Avec les scènes, la fenêtre appartient à la scène et
    // `UIApplication.shared.delegate?.window` reste vide. Or le plugin Stripe
    // cherche par là l'écran sur lequel présenter la feuille de paiement : il
    // retombait sur un contrôleur hors de toute fenêtre, la feuille ne
    // s'affichait jamais et l'achat tournait sans fin. On lui rend la fenêtre.
    (UIApplication.shared.delegate as? FlutterAppDelegate)?.window = window
  }
}
